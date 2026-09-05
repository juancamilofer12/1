--!strict
--[[
	UtilityItemType.lua

	Enum (tabla congelada) con los identificadores de objeto de
	utilidad (categoría "Utility" en ItemConfig). Fase 7 agrega un
	único objeto placeholder (Flashlight) para que el slot de Utilidad
	tenga con qué probarse — sin lógica de uso propia todavía (no hay
	sistema de linterna/día-noche en esta fase, ver ItemConfig). Objetos
	de utilidad reales llegan junto al sistema que los use.
]]

local UtilityItemType = {
	Flashlight = "Flashlight",
}

table.freeze(UtilityItemType)

return UtilityItemType
