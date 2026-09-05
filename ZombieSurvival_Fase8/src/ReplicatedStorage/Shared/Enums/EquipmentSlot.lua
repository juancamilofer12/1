--!strict
--[[
	EquipmentSlot.lua

	Enum (tabla congelada) con los 5 slots de equipamiento que pide
	la Fase 7: Arma Principal, Arma Secundaria, Herramienta, Utilidad,
	Curación. Son slots aparte de los N slots numerados de la mochila
	(InventoryConfig.SlotCount) — un objeto equipado no ocupa un slot
	de mochila mientras está equipado (ver EquipmentService).
]]

local EquipmentSlot = {
	PrimaryWeapon = "PrimaryWeapon",
	SecondaryWeapon = "SecondaryWeapon",
	Tool = "Tool",
	Utility = "Utility",
	Healing = "Healing",
}

table.freeze(EquipmentSlot)

return EquipmentSlot
