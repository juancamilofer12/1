--!strict
--[[
	WeaponClient.lua

	Arnés de prueba mínimo para el sistema de armas/combate (Fase 7).
	Mismo espíritu que ToolClient (Fase 6): sin HUD de munición, sin
	animaciones de disparo/golpe, sin mira — solo lo necesario para
	equipar un arma, golpear/disparar contra el jugador más cercano y
	recargar desde el teclado, imprimiendo en el output qué devolvió
	el servidor.

	Controles:
		3 -> equipar Machete en PrimaryWeapon (Inventory_Equip)
		4 -> equipar Pistol en PrimaryWeapon (swap: prueba que el
		     Machete vuelva solo a la mochila)
		5 -> equipar Rifle en SecondaryWeapon
		E -> atacar cuerpo a cuerpo con lo que haya en PrimaryWeapon
		     (Combat_MeleeAttack) contra el jugador más cercano
		G -> disparar con lo que haya en PrimaryWeapon
		     (Combat_RangedAttack) contra el jugador más cercano
		R -> recargar PrimaryWeapon (Weapon_RequestReload)
		U -> desequipar PrimaryWeapon de vuelta a la mochila
		C -> consumir el primer Bandage de la mochila (cura de prueba)

	Objetivo de prueba: como esta fase NO implementa zombies/IA (ver
	restricciones), no existe ningún Instance tagueado "Combatable"
	todavía (ver CombatService.lua) — golpear/disparar a otro jugador
	sirve para probar cooldown/munición/distancia de punta a punta,
	pero SIEMPRE termina en "TargetNotCombatable" porque el objetivo
	no tiene el tag. Eso es exactamente lo esperado en esta fase: el
	pipeline de validación queda probado, aplicar daño real llega con
	la fase de hordas (que solo necesita taguear a sus zombies).

	Nota (mismo criterio que ToolClient): el kit inicial
	(InventoryConfig.StarterItems) solo incluye un Machete y 2
	Bandage — probar "4"/"5" (Pistol/Rifle) sin haber conseguido esas
	armas vía otro medio devuelve "NotInInventory", no es un bug.

	El servidor sigue siendo la autoridad: este cliente solo elige a
	quién apuntar (el jugador visible más cercano) y muestra el
	resultado.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local WeaponType = require(ReplicatedStorage.Shared.Enums.WeaponType)
local EquipmentSlot = require(ReplicatedStorage.Shared.Enums.EquipmentSlot)
local ConsumableType = require(ReplicatedStorage.Shared.Enums.ConsumableType)
local Types = require(ReplicatedStorage.Shared.Types)

local InventoryClient = require(script.Parent.Parent.Inventory.InventoryClient)

local localPlayer = Players.LocalPlayer

local WeaponClient = {}

-- Mismo criterio de debounce que ToolClient.withDebounce: solo evita
-- invokes duplicados mientras el anterior no respondió, la protección
-- real de spam es el cooldown/munición server-side.
local actionInFlight = false

local function withDebounce(callback: () -> ())
	if actionInFlight then
		return
	end
	actionInFlight = true
	local ok, err = pcall(callback)
	actionInFlight = false
	if not ok then
		warn("[WeaponClient] Error ejecutando acción:", err)
	end
end

-- Busca el personaje de otro jugador más cercano al propio, sin
-- límite de distancia (CombatService valida el rango real del arma
-- del lado servidor). nil si no hay otro jugador con personaje.
local function findNearestOtherCharacter(): Model?
	local character = localPlayer.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return nil
	end
	local rootPosition = (humanoidRootPart :: BasePart).Position

	local nearest: Model? = nil
	local nearestDistance = math.huge

	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= localPlayer and otherPlayer.Character then
			local otherRoot = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot then
				local distance = ((otherRoot :: BasePart).Position - rootPosition).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearest = otherPlayer.Character
				end
			end
		end
	end

	return nearest
end

local function equip(weaponId: string, equipSlotName: string)
	withDebounce(function()
		local result = InventoryClient.Equip(weaponId, equipSlotName)
		if result.Ok then
			print(string.format("[WeaponClient] %s equipado en %s", weaponId, equipSlotName))
		else
			warn(string.format("[WeaponClient] No se pudo equipar %s en %s -> %s", weaponId, equipSlotName, tostring(result.Error)))
		end
	end)
end

local function unequip(equipSlotName: string)
	withDebounce(function()
		local result = InventoryClient.Unequip(equipSlotName)
		if result.Ok then
			print("[WeaponClient] Desequipado:", equipSlotName)
		else
			warn("[WeaponClient] No se pudo desequipar", equipSlotName, "->", result.Error)
		end
	end)
end

local function meleeAttack()
	withDebounce(function()
		local target = findNearestOtherCharacter()
		local result = NetClient.InvokeServer("Combat_MeleeAttack", EquipmentSlot.PrimaryWeapon, target)
			:: Types.CombatActionResult
		if result.Ok then
			print(
				string.format(
					"[WeaponClient] Golpe cuerpo a cuerpo: %d de daño (vida restante del objetivo: %s)",
					result.DamageDealt or 0,
					tostring(result.TargetRemainingHealth)
				)
			)
		else
			warn("[WeaponClient] Golpe rechazado:", result.Error)
		end
	end)
end

local function rangedAttack()
	withDebounce(function()
		local target = findNearestOtherCharacter()
		local result = NetClient.InvokeServer("Combat_RangedAttack", EquipmentSlot.PrimaryWeapon, target)
			:: Types.CombatActionResult
		if result.Ok then
			local ammo = result.Ammo
			print(
				string.format(
					"[WeaponClient] Disparo: %d de daño, munición %s/%s",
					result.DamageDealt or 0,
					ammo and tostring(ammo.CurrentMagazine) or "?",
					ammo and tostring(ammo.ReserveAmmo) or "?"
				)
			)
		else
			warn("[WeaponClient] Disparo rechazado:", result.Error)
		end
	end)
end

local function reload()
	withDebounce(function()
		local result = NetClient.InvokeServer("Weapon_RequestReload", EquipmentSlot.PrimaryWeapon) :: Types.ReloadResult
		if result.Ok then
			local ammo = result.Ammo :: Types.WeaponAmmoState
			print(string.format("[WeaponClient] Recargado: %d/%d", ammo.CurrentMagazine, ammo.ReserveAmmo))
		else
			warn("[WeaponClient] No se pudo recargar:", result.Error)
		end
	end)
end

local function consumeBandage()
	withDebounce(function()
		local result = InventoryClient.ConsumeFirst(ConsumableType.Bandage)
		if result.Ok then
			print("[WeaponClient] Vendaje usado, +", result.Healed, "vida")
		else
			warn("[WeaponClient] No se pudo consumir vendaje:", result.Error)
		end
	end)
end

function WeaponClient.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.KeyCode == Enum.KeyCode.Three then
			equip(WeaponType.Machete, EquipmentSlot.PrimaryWeapon)
		elseif input.KeyCode == Enum.KeyCode.Four then
			equip(WeaponType.Pistol, EquipmentSlot.PrimaryWeapon)
		elseif input.KeyCode == Enum.KeyCode.Five then
			equip(WeaponType.Rifle, EquipmentSlot.SecondaryWeapon)
		elseif input.KeyCode == Enum.KeyCode.E then
			meleeAttack()
		elseif input.KeyCode == Enum.KeyCode.G then
			rangedAttack()
		elseif input.KeyCode == Enum.KeyCode.R then
			reload()
		elseif input.KeyCode == Enum.KeyCode.U then
			unequip(EquipmentSlot.PrimaryWeapon)
		elseif input.KeyCode == Enum.KeyCode.C then
			consumeBandage()
		end
	end)
end

return WeaponClient
