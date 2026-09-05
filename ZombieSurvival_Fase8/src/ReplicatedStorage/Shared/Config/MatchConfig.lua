--!strict
--[[
	MatchConfig.lua

	Parámetros de duración/temporización de las fases de partida.
	MatchService lee estos valores en vez de tener números sueltos
	hardcodeados en su lógica.

	Los valores son placeholders razonables para esta fase base;
	se ajustarán cuando se implemente el gameplay real de zombies.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

local MatchConfig = {
	-- Jugadores mínimos en la Party para poder solicitar el inicio
	-- de partida (Fase 3: validado en MatchService.RequestStart).
	MinPlayersToStart = 1,

	-- Duración en segundos de la cuenta regresiva antes de pasar a
	-- Preparation. Configurable acá a propósito: MatchService NO
	-- debe tener este número hardcodeado.
	CountdownDuration = 5,

	-- Cada cuántos segundos se empuja Match_CountdownUpdate a los
	-- miembros de la partida mientras dura el Countdown.
	CountdownTickInterval = 1,

	-- Duración en segundos de la fase Ending antes de pasar
	-- automáticamente a GameOver (y limpiar la Match).
	EndingDuration = 8,

	-- Tiempo mínimo, en segundos, entre dos solicitudes de inicio de
	-- partida (Match_Start) de un mismo jugador. Defensa principal
	-- contra spam de StartMatch, en el mismo espíritu que
	-- PartyConfig.ActionCooldownSeconds.
	StartMatchCooldownSeconds = 1,
}

return TableUtils.DeepFreeze(MatchConfig)
