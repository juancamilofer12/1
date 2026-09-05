--!strict
--[[
	ToolType.lua

	Enum (tabla congelada) con los identificadores de herramienta que
	existen en el juego. Usar SIEMPRE estas constantes en vez de
	strings sueltos, igual que ResourceType.lua/GameState.lua.

	Fase 6: solo define las 2 herramientas básicas que pide esta fase
	(hacha y pico). Herramientas mejoradas/especiales (sierra, taladro,
	etc.) son de fases posteriores y se agregan acá cuando les toque.
]]

local ToolType = {
	WoodcutterAxe = "WoodcutterAxe",
	Pickaxe = "Pickaxe",
}

table.freeze(ToolType)

return ToolType
