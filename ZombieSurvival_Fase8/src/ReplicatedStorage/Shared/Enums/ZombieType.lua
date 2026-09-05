--!strict
--[[
	ZombieType.lua

	Enum (tabla congelada) con los 9 tipos de zombie que pide la
	Fase 8. `ZombieConfig` define las estadísticas de cada uno;
	`WaveConfig` define en qué ronda se desbloquea cada tipo y con
	qué peso aparece. Mismo patrón que `WeaponType.lua`/`ToolType.lua`.
]]

local ZombieType = {
	Normal = "Normal",
	Runner = "Runner",
	Brute = "Brute",
	Giant = "Giant",
	Explosive = "Explosive",
	Toxic = "Toxic",
	Climber = "Climber",
	Stealth = "Stealth",
	Nightmare = "Nightmare",
}

table.freeze(ZombieType)

return ZombieType
