--!strict
--[[
	InventoryConfig.lua

	Parámetros del sistema de inventario/mochila (Fase 7): capacidad
	de slots y el kit inicial que recibe un jugador nuevo.

	`SlotCount`: cantidad de slots numerados de la mochila (Types.
	PlayerData.InventorySlots tiene exactamente esta longitud). Un
	objeto equipado (Types.PlayerData.Equipment) NO cuenta contra este
	número — ver EquipmentService.

	`StarterItems`: sin sistema de crafting/economía/loot todavía, un
	jugador nuevo no tendría ninguna forma de conseguir su primera
	arma o vendaje. Se le entrega este kit fijo una única vez, al
	crear su PlayerData por primera vez (ver
	PlayerDataService.buildDefaultData) — placeholder de diseño, no
	un balanceo definitivo, mismo criterio que el resto de los valores
	de esta fase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local WeaponType = require(ReplicatedStorage.Shared.Enums.WeaponType)
local ConsumableType = require(ReplicatedStorage.Shared.Enums.ConsumableType)

local InventoryConfig = {
	SlotCount = 10,

	StarterItems = {
		{ ItemId = WeaponType.Machete, Quantity = 1 },
		{ ItemId = ConsumableType.Bandage, Quantity = 2 },
	},
}

return TableUtils.DeepFreeze(InventoryConfig)
