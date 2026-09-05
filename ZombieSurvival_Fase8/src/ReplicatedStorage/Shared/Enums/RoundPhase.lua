--!strict
--[[
	RoundPhase.lua

	Enum (tabla congelada) con las 3 fases de una ronda que pide la
	Fase 8: Preparación, Oleada, Intermisión. Es un sub-ciclo que
	`WaveService` ejecuta MIENTRAS una Match está en
	`GameState.InProgress` (ver Types.MatchPhase) -- no reemplaza ni
	se mezcla con las fases de Match de la Fase 3, es un nivel de
	detalle más fino que solo existe durante el gameplay real.
]]

local RoundPhase = {
	-- Countdown corto antes de que empiece a spawnear la oleada.
	-- Da tiempo a los jugadores de reposicionarse/prepararse.
	Preparation = "Preparation",
	-- Oleada activa: `WaveService` ya spawneó (o está spawneando de
	-- forma escalonada) los zombies de la ronda. Dura hasta que todos
	-- los zombies de la ronda están muertos/despawneados.
	Wave = "Wave",
	-- Ventana de respiro entre el fin de una oleada y el inicio de
	-- la Preparación de la siguiente ronda.
	Intermission = "Intermission",
}

table.freeze(RoundPhase)

return RoundPhase
