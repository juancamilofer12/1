--!strict
--[[
	ZombieAIState.lua

	Enum (tabla congelada) con los 5 estados de IA que pide la
	Fase 8: Idle, Searching, Chasing, Attacking, Dead. `ZombieAIService`
	instancia una `StateMachine` (Shared/Utils/StateMachine.lua) por
	zombie con estos estados, mismo patrón que `MatchService` usa
	`GameState` para la StateMachine de cada Match.
]]

local ZombieAIState = {
	-- Sin objetivo, sin moverse activamente (recién spawneado, o
	-- perdió el rastro hace tiempo y no encontró uno nuevo todavía).
	Idle = "Idle",
	-- Perdió el objetivo de vista/rango pero sigue intentando
	-- reencontrar uno cerca de la última posición conocida, antes de
	-- volver a Idle. También es el estado de "no tengo target todavía"
	-- mientras escanea periódicamente.
	Searching = "Searching",
	-- Tiene un objetivo válido fuera de AttackRange: calcula/sigue un
	-- path hacia él con PathfindingService.
	Chasing = "Chasing",
	-- Objetivo dentro de AttackRange: deja de moverse y golpea según
	-- su propio cooldown.
	Attacking = "Attacking",
	-- Estado terminal: Humanoid.Health llegó a 0. No hay transición
	-- de salida (ver ALLOWED_AI_TRANSITIONS en ZombieAIService).
	Dead = "Dead",
}

table.freeze(ZombieAIState)

return ZombieAIState
