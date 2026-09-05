--!strict
--[[
	CombatService.lua

	Responsabilidad: validar y resolver cada golpe cuerpo a cuerpo
	(`Combat_MeleeAttack`) y cada disparo (`Combat_RangedAttack`) de
	forma autoritativa. Fase 7 del proyecto.

	Filosofía server-authoritative del pedido de la Fase 7: "El
	cliente maneja exclusivamente inputs, efectos visuales y
	animaciones locales. El servidor valida estrictamente cada disparo
	o golpe". Este servicio es exactamente ese punto de validación —
	no existe ningún camino en el que un cliente pueda aplicar daño
	sin pasar por acá.

	Objetivos válidos — el concepto de "Combatable" (Fase 7 prepara,
	Fase de hordas conecta):
	Esta fase NO spawnea zombies ni implementa IA (restricción
	explícita). Para que el sistema de combate quede listo sin
	necesitar cambios cuando lleguen los zombies, un objetivo válido
	se define de forma genérica: un `Model` con `Humanoid` vivo que
	además tenga el tag de CollectionService "Combatable". Ningún
	Instance del proyecto tiene ese tag todavía (no hay zombies ni PvP
	habilitado), así que en la práctica todo intento de golpear/
	disparar hoy termina en "TargetNotCombatable" — igual que
	`ResourceService.ExtractResource` en la Fase 5 quedó lista pero sin
	nada que la invocara hasta la Fase 6. La fase de hordas solo
	necesita taggear sus modelos de zombie con "Combatable" (una línea,
	`CollectionService:AddTag(zombieModel, "Combatable")`) para que
	todo este pipeline empiece a aplicar daño real sin tocar este
	archivo.

	Orden de validación (Fase 7 pide "cooldown, munición disponible,
	distancia máxima, validez del objetivo" en ese orden): se sigue
	tal cual, con un chequeo estructural previo e inevitable ("¿el
	`target` es siquiera una Instance con posición?") para poder medir
	distancia — igual salvedad que ToolService documentó sobre
	`ResourceService.GetNode` no contar como paso de validación en sí.

	Cooldown: un timestamp por (UserId, EquipmentSlotName), no por
	arma ni global al jugador — dos armas en Primaria/Secundaria
	pueden dispararse en paralelo sin compartir cadencia, pero cambiar
	de arma en el MISMO slot no resetea su cooldown porque la clave es
	el slot, no el WeaponId.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponKind = require(ReplicatedStorage.Shared.Enums.WeaponKind)
local EquipmentSlot = require(ReplicatedStorage.Shared.Enums.EquipmentSlot)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local CombatService = {}
CombatService.Name = "CombatService" :: string

-- Tag de CollectionService que marca un Model como objetivo de
-- combate válido. Ver nota de cabecera: ningún Instance del proyecto
-- lo tiene todavía en esta fase.
local COMBATABLE_TAG = "Combatable"

local WEAPON_SLOTS: { [string]: boolean } = {
	[EquipmentSlot.PrimaryWeapon] = true,
	[EquipmentSlot.SecondaryWeapon] = true,
}

-- (UserId, EquipmentSlotName) -> os.clock() del último golpe/disparo
-- válido de ESE slot. Ver nota de cabecera sobre por qué es por slot
-- y no por arma ni global.
local lastAttackAt: { [number]: { [string]: number } } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local remoteRef: any = nil
local equipmentRef: any = nil
local weaponRef: any = nil

local function log(message: string)
	if debugRef then
		debugRef:Info("CombatService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("CombatService", message)
	end
end

local function checkCooldown(userId: number, slotName: string, cooldownSeconds: number): boolean
	local now = os.clock()
	local slots = lastAttackAt[userId]
	if not slots then
		slots = {}
		lastAttackAt[userId] = slots
	end

	local last = slots[slotName]
	if last ~= nil and (now - last) < cooldownSeconds then
		return false
	end
	slots[slotName] = now
	return true
end

-- Chequeo estructural: ¿`target` es una Instance válida para medir
-- distancia y buscarle un Humanoid? No es la "validez de objetivo" de
-- combate en sí (eso es `isValidCombatTarget`), es el prerequisito
-- para poder evaluarla — misma distinción que ToolService hace con
-- `ResourceService.GetNode`.
local function getTargetHumanoidAndRoot(target: any): (Humanoid?, BasePart?)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return nil, nil
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end
	local root = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart")
	if not root or not (root :: Instance):IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root :: BasePart
end

-- Validez de objetivo propiamente dicha: vivo, taggeado Combatable, y
-- distinto del propio personaje del atacante (nunca te curás pegándote
-- a vos mismo por error de cliente).
local function isValidCombatTarget(attacker: Player, targetModel: Instance, humanoid: Humanoid): boolean
	if humanoid.Health <= 0 then
		return false
	end
	if targetModel == attacker.Character then
		return false
	end
	return CollectionService:HasTag(targetModel, COMBATABLE_TAG)
end

local function getAttackerRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and (root :: Instance):IsA("BasePart") and (root :: BasePart) or nil
end

-- ============================================================
-- API pública
-- ============================================================

function CombatService.RequestMeleeAttack(player: Player, slotName: any, target: any): Types.CombatActionResult
	if type(slotName) ~= "string" or not WEAPON_SLOTS[slotName] then
		return { Ok = false, Error = "InvalidSlot" }
	end

	local weaponId = equipmentRef.GetEquippedItemId(player, slotName)
	if not weaponId then
		return { Ok = false, Error = "NoWeaponEquipped" }
	end

	local weaponConfig = WeaponConfig.Weapons[weaponId]
	if not weaponConfig or weaponConfig.Kind ~= WeaponKind.Melee then
		return { Ok = false, Error = "NotAMeleeWeapon" }
	end

	local userId = player.UserId

	-- 1) Cooldown de cadencia del arma equipada en ese slot.
	if not checkCooldown(userId, slotName, weaponConfig.CooldownSeconds) then
		return { Ok = false, Error = "OnCooldown" }
	end

	-- (Melee no usa munición: se salta el paso 2 del orden pedido por
	-- la Fase 7, que solo aplica a armas de fuego.)

	local attackerRoot = getAttackerRoot(player)
	if not attackerRoot then
		return { Ok = false, Error = "NoCharacter" }
	end

	local humanoid, targetRoot = getTargetHumanoidAndRoot(target)
	if not humanoid or not targetRoot then
		return { Ok = false, Error = "InvalidTarget" }
	end

	-- 3) Distancia máxima (Range del arma).
	local distance = (targetRoot.Position - attackerRoot.Position).Magnitude
	if distance > weaponConfig.Range then
		return { Ok = false, Error = "TooFar" }
	end

	-- 4) Validez del objetivo (vivo, tag Combatable, no uno mismo).
	if not isValidCombatTarget(player, target, humanoid) then
		return { Ok = false, Error = "TargetNotCombatable" }
	end

	humanoid:TakeDamage(weaponConfig.Damage)

	log(
		string.format(
			"%s (UserId %d) golpeó a %s con %s: %d de daño",
			player.Name,
			userId,
			target:GetFullName(),
			weaponId,
			weaponConfig.Damage
		)
	)

	return { Ok = true, DamageDealt = weaponConfig.Damage, TargetRemainingHealth = humanoid.Health }
end

function CombatService.RequestRangedAttack(player: Player, slotName: any, target: any): Types.CombatActionResult
	if type(slotName) ~= "string" or not WEAPON_SLOTS[slotName] then
		return { Ok = false, Error = "InvalidSlot" }
	end

	local weaponId = equipmentRef.GetEquippedItemId(player, slotName)
	if not weaponId then
		return { Ok = false, Error = "NoWeaponEquipped" }
	end

	local weaponConfig = WeaponConfig.Weapons[weaponId]
	if not weaponConfig or weaponConfig.Kind ~= WeaponKind.Firearm then
		return { Ok = false, Error = "NotAFirearm" }
	end

	local userId = player.UserId

	-- 1) Cooldown de cadencia (fire rate) del arma equipada.
	if not checkCooldown(userId, slotName, weaponConfig.CooldownSeconds) then
		return { Ok = false, Error = "OnCooldown" }
	end

	if weaponRef.IsReloading(player, slotName) then
		return { Ok = false, Error = "Reloading" }
	end

	-- 2) Munición disponible. Se consume ACÁ (antes de validar
	-- distancia/objetivo): un disparo gasta bala tanto si acierta como
	-- si erra, igual que cualquier arma real — la validación de
	-- objetivo/distancia solo decide si además de gastar munición
	-- también aplica daño.
	local consumed, ammoState = weaponRef.ConsumeAmmo(player, slotName)
	if not consumed then
		return { Ok = false, Error = "OutOfAmmo", Ammo = ammoState }
	end

	local attackerRoot = getAttackerRoot(player)
	if not attackerRoot then
		return { Ok = true, DamageDealt = 0, Ammo = ammoState } -- bala gastada, sin personaje para calcular impacto
	end

	local humanoid, targetRoot = getTargetHumanoidAndRoot(target)
	if not humanoid or not targetRoot then
		-- Disparo válido pero sin objetivo (tiro al aire / target nil):
		-- se gastó munición, no hay daño que aplicar.
		return { Ok = true, DamageDealt = 0, Ammo = ammoState }
	end

	-- 3) Distancia máxima (alcance efectivo del arma).
	local distance = (targetRoot.Position - attackerRoot.Position).Magnitude
	if distance > weaponConfig.Range then
		return { Ok = true, DamageDealt = 0, Ammo = ammoState } -- fuera de rango: tiro gastado, sin impacto
	end

	-- 4) Validez del objetivo.
	if not isValidCombatTarget(player, target, humanoid) then
		return { Ok = true, DamageDealt = 0, Ammo = ammoState } -- objetivo inválido: tiro gastado, sin impacto
	end

	humanoid:TakeDamage(weaponConfig.Damage)

	log(
		string.format(
			"%s (UserId %d) disparó a %s con %s: %d de daño",
			player.Name,
			userId,
			target:GetFullName(),
			weaponId,
			weaponConfig.Damage
		)
	)

	return {
		Ok = true,
		DamageDealt = weaponConfig.Damage,
		TargetRemainingHealth = humanoid.Health,
		Ammo = ammoState,
	}
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function CombatService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	remoteRef = registry.RemoteService
	equipmentRef = registry.EquipmentService
	weaponRef = registry.WeaponService
end

-- Envuelve un handler de RemoteFunction en pcall, mismo patrón que el
-- resto de los servicios de esta fase.
local function safeInvoke(
	actionName: string,
	handler: (player: Player, ...any) -> any,
	errorResult: any
): (player: Player, ...any) -> any
	return function(player: Player, ...: any): any
		local ok, result = pcall(handler, player, ...)
		if not ok then
			logError(string.format("Error interno en %s: %s", actionName, tostring(result)))
			return errorResult
		end
		return result
	end
end

function CombatService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	local meleeRemote = remoteRef.Get("Combat_MeleeAttack") :: RemoteFunction
	meleeRemote.OnServerInvoke = safeInvoke(
		"Combat_MeleeAttack",
		function(player: Player, slotName: any, target: any)
			return CombatService.RequestMeleeAttack(player, slotName, target)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.CombatActionResult
	)

	local rangedRemote = remoteRef.Get("Combat_RangedAttack") :: RemoteFunction
	rangedRemote.OnServerInvoke = safeInvoke(
		"Combat_RangedAttack",
		function(player: Player, slotName: any, target: any)
			return CombatService.RequestRangedAttack(player, slotName, target)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.CombatActionResult
	)

	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		lastAttackAt[player.UserId] = nil
	end))

	log("CombatService listo.")
end

return CombatService
