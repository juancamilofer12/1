--!strict
--[[
	ConsumableType.lua

	Enum (tabla congelada) con los identificadores de objeto de
	curación (categoría "Healing" en ItemConfig). Fase 7: 2 objetos
	básicos (venda rápida, botiquín) para poder probar el slot de
	Curación y InventoryService.ConsumeItem de punta a punta. Objetos
	de curación adicionales (antídoto, adrenalina, etc.) se agregan
	acá cuando les toque su propia fase.
]]

local ConsumableType = {
	Bandage = "Bandage",
	Medkit = "Medkit",
}

table.freeze(ConsumableType)

return ConsumableType
