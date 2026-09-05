--!strict
--[[
	GameState.lua

	Enum (tabla congelada) con las fases posibles de una partida.
	Usar SIEMPRE estas constantes en vez de strings sueltos para
	evitar errores de tipeo silenciosos.
]]

local GameState = {
	Lobby = "Lobby",
	Countdown = "Countdown",
	-- Fase 3: ventana entre el fin del Countdown y el arranque real
	-- del gameplay (todavía sin lógica de zombies/oleadas/spawns).
	Preparation = "Preparation",
	InProgress = "InProgress",
	Ending = "Ending",
	-- Fase 3: estado terminal de una Match antes de limpiarla y
	-- liberar la relación Party -> Match.
	GameOver = "GameOver",
}

table.freeze(GameState)

return GameState
