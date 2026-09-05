--!strict
--[[
	ResourceConfig.lua

	Parámetros del sistema de recursos (Fase 5): cuánto rinde cada
	nodo antes de agotarse y cuánto tarda en regenerarse. ResourceService
	lee estos valores en vez de tener números sueltos hardcodeados.

	Balanceo: estos son valores de placeholder razonables, no
	definitivos — el balanceo real solo tiene sentido una vez que
	exista el sistema de herramientas (Fase 6) que determina cuánto
	extrae un golpe de hacha/pico, y el de construcción/economía que
	determina cuánto se necesita. No se afinan acá para no inventar
	un número sin contexto de consumo real.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)

local ResourceConfig = {
	-- Por tipo de recurso: cuántas unidades tiene un nodo lleno
	-- (`Amount`) y cuántos segundos tarda en volver a estar
	-- disponible una vez agotado (`RespawnSeconds`).
	Nodes = {
		[ResourceType.Wood] = {
			Amount = 5,
			RespawnSeconds = 90,
		},
		[ResourceType.Stone] = {
			Amount = 4,
			RespawnSeconds = 120,
		},
		-- Metal y Scrap son recursos "avanzados" (sección 5 de
		-- WORLD_MAP_DESIGN.md: componentes mecánicos concentrados en
		-- anillos exteriores) — rinden menos y tardan más en volver
		-- que madera/piedra, para empujar la progresión hacia zonas
		-- de más riesgo en vez de que todo se recolecte igual de
		-- rápido cerca del campamento central.
		[ResourceType.Metal] = {
			Amount = 3,
			RespawnSeconds = 180,
		},
		[ResourceType.Scrap] = {
			Amount = 3,
			RespawnSeconds = 150,
		},
	},
}

return TableUtils.DeepFreeze(ResourceConfig)
