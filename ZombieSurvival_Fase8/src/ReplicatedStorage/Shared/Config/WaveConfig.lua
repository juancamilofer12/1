--!strict
--[[
	WaveConfig.lua

	Parámetros de dificultad progresiva del sistema de rondas
	(Fase 8): cuántos zombies spawnean por ronda, cuánto se
	multiplican su salud/velocidad ronda a ronda, cuándo se
	desbloquea cada anillo del mapa y cada tipo de zombie especial,
	y duración de las fases de Preparación/Intermisión. `WaveService`
	lee esto en vez de tener números de balanceo sueltos.

	A diferencia de ResourceConfig/ToolConfig/WeaponConfig/ZombieConfig
	(tablas de datos puras), este módulo expone además funciones
	puras (`GetDifficultyForRound`, `GetMaxRingForRound`,
	`GetAvailableZombieTypes`) porque "ronda" es un número sin techo
	-- la dificultad debe poder calcularse para CUALQUIER ronda futura,
	no solo para las que alguien pensó en precargar en una tabla fija.
	`TableUtils.DeepFreeze` congela igual los datos (tablas), las
	funciones no son tablas así que no hay nada que congelar en ellas.

	Balanceo: valores de placeholder razonables, no definitivos --
	mismo criterio que el resto de los Config del proyecto.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local ZombieType = require(ReplicatedStorage.Shared.Enums.ZombieType)

local WaveConfig = {
	-- Duración de las fases de respiro alrededor de cada oleada.
	PreparationSeconds = 15,
	IntermissionSeconds = 10,

	-- Cantidad de zombies en la ronda 1, y cuántos se suman por cada
	-- ronda adicional (crecimiento lineal simple, ver
	-- GetDifficultyForRound para el techo contra
	-- ZombieConfig.MaxConcurrentZombies).
	BaseZombieCount = 5,
	ZombieCountPerRound = 2,

	-- Multiplicadores de salud/velocidad que se acumulan por cada
	-- ronda por encima de la 1 (ronda 1 = multiplicador 1.0 exacto).
	-- Los "Max" evitan que una partida larga vuelva a los zombies
	-- imposibles de esquivar o de matar en la práctica.
	HealthMultiplierPerRound = 0.12,
	SpeedMultiplierPerRound = 0.03,
	MaxHealthMultiplier = 4.0,
	MaxSpeedMultiplier = 1.6,

	-- Segundos entre cada spawn individual dentro de una misma
	-- oleada -- spawnear los N zombies de la ronda de forma
	-- escalonada, no todos en el mismo frame. Reduce el pico de
	-- cómputo de pathfinding inicial (cada zombie recién spawneado
	-- calcula su primer path) y respeta la regla de diseño de
	-- WORLD_MAP_DESIGN.md sección 10 de que el peligro se sienta por
	-- cantidad/ambientación, no por una avalancha instantánea.
	SpawnIntervalSeconds = 0.6,

	-- A partir de qué ronda se habilita usar puntos de spawn de cada
	-- anillo (Attribute "Ring" de ZombieSpawnPoints.model.json, Fase
	-- 4). Ronda 1 solo usa Anillo 1 (WORLD_MAP_DESIGN.md sección 10:
	-- "Anillo 0: sin spawns propios"; ronda 1 tampoco escala
	-- directamente al Anillo 3). Se lee de mayor a menor umbral en
	-- GetMaxRingForRound.
	RingUnlockRound = {
		[1] = 1,
		[3] = 2,
		[6] = 3,
	},

	-- Ronda mínima en la que cada tipo especial empieza a poder
	-- aparecer, y su peso relativo (entero, tipo "puntos de rifa") en
	-- el sorteo ponderado de GetAvailableZombieTypes una vez
	-- desbloqueado. Normal/Runner están disponibles desde la ronda 1
	-- a propósito (variedad básica desde el arranque); el resto se
	-- va sumando con la progresión, terminando en Nightmare como el
	-- tipo más raro y más tardío.
	SpecialTypeUnlocks = {
		[ZombieType.Normal] = { MinRound = 1, Weight = 50 },
		[ZombieType.Runner] = { MinRound = 1, Weight = 25 },
		[ZombieType.Climber] = { MinRound = 2, Weight = 10 },
		[ZombieType.Brute] = { MinRound = 3, Weight = 8 },
		[ZombieType.Stealth] = { MinRound = 4, Weight = 5 },
		[ZombieType.Toxic] = { MinRound = 4, Weight = 6 },
		[ZombieType.Explosive] = { MinRound = 5, Weight = 5 },
		[ZombieType.Giant] = { MinRound = 7, Weight = 3 },
		[ZombieType.Nightmare] = { MinRound = 10, Weight = 1 },
	},
}

-- Cantidad de zombies + multiplicadores de dificultad para una ronda
-- puntual. `round` debe ser un entero >= 1. `zombieMaxConcurrent` es
-- el techo defensivo de ZombieConfig, pasado como parámetro (en vez
-- de que este módulo dependa de ZombieConfig) para que el cálculo de
-- dificultad sea puramente sobre datos de WaveConfig y quien llama
-- decida cómo aplicarlo.
function WaveConfig.GetDifficultyForRound(round: number, zombieMaxConcurrent: number)
	local rawCount = WaveConfig.BaseZombieCount + (round - 1) * WaveConfig.ZombieCountPerRound
	local zombieCount = math.clamp(rawCount, 1, zombieMaxConcurrent)

	local healthMultiplier = math.min(
		1 + (round - 1) * WaveConfig.HealthMultiplierPerRound,
		WaveConfig.MaxHealthMultiplier
	)
	local speedMultiplier = math.min(
		1 + (round - 1) * WaveConfig.SpeedMultiplierPerRound,
		WaveConfig.MaxSpeedMultiplier
	)

	return {
		ZombieCount = zombieCount,
		HealthMultiplier = healthMultiplier,
		SpeedMultiplier = speedMultiplier,
		MaxRing = WaveConfig.GetMaxRingForRound(round),
	}
end

-- Anillo máximo (1/2/3) habilitado para spawns en esta ronda, según
-- `RingUnlockRound`. Devuelve el umbral más alto cuyo `round` de
-- desbloqueo ya se alcanzó.
function WaveConfig.GetMaxRingForRound(round: number): number
	local maxRing = 1
	for unlockRound, ring in pairs(WaveConfig.RingUnlockRound) do
		if round >= unlockRound and ring > maxRing then
			maxRing = ring
		end
	end
	return maxRing
end

-- Lista `{ ZombieType = string, Weight = number }` de los tipos ya
-- desbloqueados en `round`, lista para un sorteo ponderado (ver
-- ZombieService.pickWeightedType). Nunca devuelve una lista vacía:
-- Normal siempre tiene MinRound = 1.
function WaveConfig.GetAvailableZombieTypes(round: number): { { ZombieType: string, Weight: number } }
	local available = {}
	for zombieType, unlock in pairs(WaveConfig.SpecialTypeUnlocks) do
		if round >= unlock.MinRound then
			table.insert(available, { ZombieType = zombieType, Weight = unlock.Weight })
		end
	end
	return available
end

return TableUtils.DeepFreeze(WaveConfig)
