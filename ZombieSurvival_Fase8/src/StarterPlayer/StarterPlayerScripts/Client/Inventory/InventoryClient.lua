--!strict
--[[
	InventoryClient.lua

	Cache de solo-lectura, del lado del cliente, del último snapshot
	de mochila + equipamiento conocido (Types.InventoryStateSnapshot).
	Fase 7. Mismo espíritu de "arnés de prueba mínimo" que ToolClient
	(Fase 6): sin UI de mochila real, sin drag-and-drop — solo lo
	necesario para que ToolClient/WeaponClient puedan encontrar en qué
	slot de la mochila está un ItemId y pedir equiparlo/consumirlo,
	imprimiendo en el output qué devolvió el servidor.

	El servidor sigue siendo la única autoridad: este módulo nunca
	decide si una acción es válida, solo recuerda el último estado que
	el servidor confirmó, para no tener que pedir "Inventory_GetSnapshot"
	de nuevo antes de cada acción.

	Uso esperado por otros módulos de cliente:
		InventoryClient.Init() -- una vez, al arrancar
		InventoryClient.FindSlotWithItem(itemId) -- number?
		InventoryClient.Equip(itemId, equipSlotName)
		InventoryClient.Unequip(equipSlotName)
		InventoryClient.ConsumeFirst(itemId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local Types = require(ReplicatedStorage.Shared.Types)

local InventoryClient = {}

local cachedInventory: Types.InventorySnapshot? = nil
local cachedEquipment: Types.EquipmentSnapshot? = nil

local function applyInventory(snapshot: Types.InventorySnapshot?)
	if snapshot then
		cachedInventory = snapshot
	end
end

local function applyEquipment(snapshot: Types.EquipmentSnapshot?)
	if snapshot then
		cachedEquipment = snapshot
	end
end

-- Pide el estado inicial al servidor. Debe llamarse una sola vez, al
-- arrancar el cliente, antes de que ToolClient/WeaponClient intenten
-- encontrar/equipar nada (ver init.client.lua, orden de Init()).
function InventoryClient.Init()
	local result = NetClient.InvokeServer("Inventory_GetSnapshot") :: Types.InventoryStateSnapshot
	applyInventory(result.Inventory)
	applyEquipment(result.Equipment)
	print("[InventoryClient] Estado inicial cargado.")
end

-- Busca el primer slot de la mochila cacheada que contenga `itemId`.
-- nil si no está (el jugador no lo tiene, o el cache está desactualizado
-- — en ese caso la acción que se intente igual la rechaza el servidor).
-- IMPORTANTE: `Slots` es sparse (un slot vacío es una clave ausente,
-- no un `nil` "puesto" ahí) — se recorre por rango explícito
-- (`Capacity`, no `ipairs`/`#`), mismo motivo que documenta
-- PlayerDataService.placeStarterItem del lado servidor.
function InventoryClient.FindSlotWithItem(itemId: string): number?
	if not cachedInventory then
		return nil
	end
	for index = 1, cachedInventory.Capacity do
		local stack = cachedInventory.Slots[index]
		if stack and stack.ItemId == itemId then
			return index
		end
	end
	return nil
end

function InventoryClient.GetEquipped(slotName: string): string?
	if not cachedEquipment then
		return nil
	end
	local stack = (cachedEquipment :: any)[slotName]
	return stack and stack.ItemId or nil
end

-- Equipa `itemId` (buscándolo en la mochila cacheada) en `equipSlotName`.
-- Devuelve el Types.EquipmentActionResult del servidor, con el cache ya
-- actualizado si Ok.
function InventoryClient.Equip(itemId: string, equipSlotName: string): Types.EquipmentActionResult
	local slotIndex = InventoryClient.FindSlotWithItem(itemId)
	if not slotIndex then
		return { Ok = false, Error = "NotInInventory" }
	end

	local result = NetClient.InvokeServer("Inventory_Equip", slotIndex, equipSlotName) :: Types.EquipmentActionResult
	if result.Ok then
		applyInventory(result.Inventory)
		applyEquipment(result.Equipment)
	end
	return result
end

function InventoryClient.Unequip(equipSlotName: string): Types.EquipmentActionResult
	local result = NetClient.InvokeServer("Inventory_Unequip", equipSlotName) :: Types.EquipmentActionResult
	if result.Ok then
		applyInventory(result.Inventory)
		applyEquipment(result.Equipment)
	end
	return result
end

-- Consume la primera unidad de `itemId` que encuentre en la mochila
-- cacheada (pensado para objetos de curación, ver ConsumableType.lua).
function InventoryClient.ConsumeFirst(itemId: string): Types.ConsumeItemResult
	local slotIndex = InventoryClient.FindSlotWithItem(itemId)
	if not slotIndex then
		return { Ok = false, Error = "NotInInventory" }
	end

	local result = NetClient.InvokeServer("Inventory_Consume", slotIndex) :: Types.ConsumeItemResult
	if result.Ok then
		applyInventory(result.Inventory)
	end
	return result
end

return InventoryClient
