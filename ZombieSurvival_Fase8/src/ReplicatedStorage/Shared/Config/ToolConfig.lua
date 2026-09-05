--!strict
--[[
	ToolConfig.lua

	Parámetros del sistema de herramientas (Fase 6): daño por golpe,
	cooldown entre usos y contra qué `ResourceType` es efectiva cada
	herramienta. `ToolService` lee estos valores en vez de tener
	números sueltos hardcodeados, mismo patrón que `ResourceConfig`.

	Decisión de diseño (ver PROJECT_MANIFEST.md, Fase 6): esta fase NO
	introduce un concepto nuevo de "tipo de nodo" (`TreeNode`/`RockNode`/
	`MetalNode`, como los nombra el pedido de la fase) separado del
	`ResourceType` que ya existe desde la Fase 5. Un nodo ya se
	identifica por su Attribute `ResourceType` (`Wood`/`Stone`/`Metal`/
	`Scrap`), así que `EffectiveAgainst` mapea directamente contra esos
	mismos valores en vez de duplicar la clasificación:
	`WoodcutterAxe` -> `Wood`, `Pickaxe` -> `Stone`/`Metal`. Evita tener
	dos taxonomías paralelas de "tipo de recurso" que puedan desincronizarse.

	Balanceo: valores de placeholder razonables, no definitivos —
	mismo criterio que dejó `ResourceConfig` en la Fase 5.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)
local ToolType = require(ReplicatedStorage.Shared.Enums.ToolType)

local ToolConfig = {
	-- Distancia máxima (studs) entre el HumanoidRootPart del jugador
	-- y el nodo para que un golpe sea válido. Un solo valor global
	-- (no por herramienta): la Fase 6 no pide alcances distintos por
	-- herramienta, y mantenerlo único evita tener que justificar por
	-- qué el hacha llegaría más lejos que el pico sin razón de diseño.
	MaxHarvestDistance = 12,

	Tools = {
		[ToolType.WoodcutterAxe] = {
			-- Cantidad de recurso que extrae un golpe válido. Se pasa
			-- tal cual a `ResourceService.ExtractResource(nodeId, Damage)`.
			Damage = 1,
			-- Segundos mínimos entre dos golpes válidos de esta
			-- herramienta para el mismo jugador (independiente del nodo).
			CooldownSeconds = 1,
			EffectiveAgainst = { ResourceType.Wood },
		},
		[ToolType.Pickaxe] = {
			Damage = 1,
			CooldownSeconds = 1.2,
			EffectiveAgainst = { ResourceType.Stone, ResourceType.Metal },
		},
	},
}

return TableUtils.DeepFreeze(ToolConfig)
