--!strict
--[[
	WeaponService.lua

	Responsabilidad: llevar el estado de munición (cargador actual +
	reserva + si está recargando) de las armas de fuego que un jugador
	tiene equipadas, y procesar los pedidos de recarga. Fase 7 del
	proyecto.

	No decide si un disparo ACIERTA ni aplica daño — eso es
	`CombatService`, que llama a `ConsumeAmmo`/`IsReloading` acá antes
	de resolver un `Combat_RangedAttack`. Separación de
	responsabilidades: WeaponService sabe de balas, CombatService sabe
	de combate (cooldown de ataque, distancia, validez de objetivo).

	Estado en memoria (NO persistido): a diferencia de
	Inventory/Equipment, la munición actual de un arma se resetea al
	reconectar. Decisión explícita: modelar munición persistente
	requeriría que cada copia física de un arma sea una instancia
	única (con su propio ID) en vez de un stack por ItemId — el
	inventario de esta fase apila armas por ItemId sin instancias
	únicas (ver ItemConfig.lua), así que no hay dónde guardar "cuánta
	munición le queda a ESTA pistola en particular". Se prioriza
	simplicidad: al equipar una pistola (o reconectar con una ya
	equipada), `getOrInitAmmo` la re-arma con cargador lleno +
	munición de reserva inicial de WeaponConfig. Esto queda
	documentado para que una fase de armas únicas/desgaste sepa que
	tiene que rediseñar este servicio.

	Ammo state clave: (UserId, EquipmentSlotName) -> WeaponAmmoState.
	Se re-inicializa sola (sin necesidad de escuchar eventos de
	EquipmentService) cada vez que el WeaponId detectado en ese slot
	no coincide con el de la última ammo state guardada — cubre tanto
	"se equipó un arma distinta" como "el jugador nunca había
	disparado con esta todavía".
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponKind = require(ReplicatedStorage.Shared.Enums.WeaponKind)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local WeaponService = {}
WeaponService.Name = "WeaponService" :: string

type AmmoInternal = {
	WeaponId: Types.WeaponId,
	CurrentMagazine: number,
	ReserveAmmo: number,
	ReloadingUntil: number, -- os.clock() en que termina la recarga en curso; 0 = no recargando
}

-- UserId -> EquipmentSlotName -> AmmoInternal. Solo tiene entradas
-- para slots que en algún momento tuvieron un arma de fuego equipada
-- y fueron consultados (lazy init, ver getOrInitAmmo).
local ammoByPlayer: { [number]: { [string]: AmmoInternal } } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local remoteRef: any = nil
local equipmentRef: any = nil

local function log(message: string)
	if debugRef then
		debugRef:Info("WeaponService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("WeaponService", message)
	end
end

local function toPublicState(ammo: AmmoInternal): Types.WeaponAmmoState
	return {
		WeaponId = ammo.WeaponId,
		CurrentMagazine = ammo.CurrentMagazine,
		ReserveAmmo = ammo.ReserveAmmo,
		Reloading = ammo.ReloadingUntil > os.clock(),
	}
end

-- Devuelve el AmmoInternal del slot, re-armándolo con cargador lleno
-- si es la primera vez que se consulta o si el WeaponId equipado
-- cambió desde la última consulta (ver nota de estado en memoria
-- arriba). Devuelve nil si `weaponId` no es un arma de fuego válida.
local function getOrInitAmmo(userId: number, slotName: string, weaponId: string): AmmoInternal?
	local weaponConfig = WeaponConfig.Weapons[weaponId]
	if not weaponConfig or weaponConfig.Kind ~= WeaponKind.Firearm then
		return nil
	end

	local playerSlots = ammoByPlayer[userId]
	if not playerSlots then
		playerSlots = {}
		ammoByPlayer[userId] = playerSlots
	end

	local existing = playerSlots[slotName]
	if not existing or existing.WeaponId ~= weaponId then
		existing = {
			WeaponId = weaponId :: Types.WeaponId,
			CurrentMagazine = weaponConfig.MagazineSize,
			ReserveAmmo = weaponConfig.StartingReserveAmmo,
			ReloadingUntil = 0,
		}
		playerSlots[slotName] = existing
	end

	return existing
end

-- ============================================================
-- API pública (usada por CombatService y por los remotes de esta
-- fase)
-- ============================================================

-- Lectura de solo consulta: qué munición tiene el arma equipada en
-- `slotName`, o nil si no hay arma de fuego equipada ahí.
function WeaponService.GetAmmoState(player: Player, slotName: string): Types.WeaponAmmoState?
	local weaponId = equipmentRef.GetEquippedItemId(player, slotName)
	if not weaponId then
		return nil
	end
	local ammo = getOrInitAmmo(player.UserId, slotName, weaponId)
	return ammo and toPublicState(ammo)
end

-- true si el arma en `slotName` está a mitad de una recarga (
-- CombatService debe rechazar el disparo en ese caso).
function WeaponService.IsReloading(player: Player, slotName: string): boolean
	local weaponId = equipmentRef.GetEquippedItemId(player, slotName)
	if not weaponId then
		return false
	end
	local ammo = getOrInitAmmo(player.UserId, slotName, weaponId)
	return ammo ~= nil and ammo.ReloadingUntil > os.clock()
end

-- Descuenta una bala del cargador de `slotName` si hay al menos una
-- disponible. Devuelve (consumed: boolean, ammoState: WeaponAmmoState?).
-- CombatService la llama justo antes de aplicar daño de un disparo
-- válido; si devuelve false, CombatService rechaza el disparo entero
-- con "OutOfAmmo" sin gastar cooldown de más.
function WeaponService.ConsumeAmmo(player: Player, slotName: string): (boolean, Types.WeaponAmmoState?)
	local weaponId = equipmentRef.GetEquippedItemId(player, slotName)
	if not weaponId then
		return false, nil
	end

	local ammo = getOrInitAmmo(player.UserId, slotName, weaponId)
	if not ammo then
		return false, nil
	end

	if ammo.CurrentMagazine <= 0 then
		return false, toPublicState(ammo)
	end

	ammo.CurrentMagazine -= 1
	return true, toPublicState(ammo)
end

function WeaponService.RequestReload(player: Player, slotName: any): Types.ReloadResult
	if type(slotName) ~= "string" then
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

	local ammo = getOrInitAmmo(player.UserId, slotName, weaponId) :: AmmoInternal

	if ammo.ReloadingUntil > os.clock() then
		return { Ok = false, Error = "AlreadyReloading" }
	end

	if ammo.CurrentMagazine >= weaponConfig.MagazineSize then
		return { Ok = false, Error = "MagazineFull" }
	end

	if ammo.ReserveAmmo <= 0 then
		return { Ok = false, Error = "NoReserveAmmo" }
	end

	local needed = weaponConfig.MagazineSize - ammo.CurrentMagazine
	local toLoad = math.min(needed, ammo.ReserveAmmo)

	-- Server-authoritative pero simplificado: la recarga se aplica de
	-- inmediato (no hay animación/canal que el servidor deba esperar
	-- en este proyecto sin humanoides de zombies todavía), pero se
	-- marca `ReloadingUntil` para que un disparo o una segunda recarga
	-- durante los `ReloadSeconds` siguientes se rechacen — el cliente
	-- sigue mostrando su animación de recarga local por esa misma
	-- duración, el servidor solo garantiza que no se pueda "cancelar"
	-- la espera disparando de más.
	ammo.CurrentMagazine += toLoad
	ammo.ReserveAmmo -= toLoad
	ammo.ReloadingUntil = os.clock() + weaponConfig.ReloadSeconds

	log(
		string.format(
			"%s (UserId %d) recargó %s en %s: +%d (reserva restante %d)",
			player.Name,
			player.UserId,
			weaponId,
			slotName,
			toLoad,
			ammo.ReserveAmmo
		)
	)

	return { Ok = true, Ammo = toPublicState(ammo) }
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function WeaponService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	remoteRef = registry.RemoteService
	equipmentRef = registry.EquipmentService
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

function WeaponService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	local reloadRemote = remoteRef.Get("Weapon_RequestReload") :: RemoteFunction
	reloadRemote.OnServerInvoke = safeInvoke(
		"Weapon_RequestReload",
		function(player: Player, slotName: any)
			return WeaponService.RequestReload(player, slotName)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.ReloadResult
	)

	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		ammoByPlayer[player.UserId] = nil
	end))

	log("WeaponService listo.")
end

return WeaponService
