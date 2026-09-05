--!strict
--[[
	ResourceType.lua

	Enum (tabla congelada) con los tipos de recurso recolectable que
	existen en el mundo. Usar SIEMPRE estas constantes en vez de
	strings sueltos, igual que GameState.lua.

	Fase 5: solo define los 4 tipos que piden los nodos del mundo
	(madera, piedra, metal, chatarra). No incluye comida, combustible
	ni medicinas — esos recursos existen en el diseño del mapa
	(`WORLD_MAP_DESIGN.md` sección 5) pero no tienen nodo de
	recolección en esta fase; se agregarán cuando les toque su propio
	sistema.
]]

local ResourceType = {
	Wood = "Wood",
	Stone = "Stone",
	Metal = "Metal",
	Scrap = "Scrap",
}

table.freeze(ResourceType)

return ResourceType
