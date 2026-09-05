--!strict
--[[
	StateMachine.lua

	Máquina de estados finita, genérica y reutilizable. No conoce
	nada sobre "partidas" ni "zombies": simplemente valida
	transiciones permitidas y notifica cambios de estado.

	Uso (ejemplo con los estados de partida):
		local sm = StateMachine.new("Lobby", {
			Lobby = { "Countdown" },
			Countdown = { "InProgress", "Lobby" },
			InProgress = { "Ending" },
			Ending = { "Lobby" },
		})

		sm.Changed:Connect(function(newState, oldState) ... end)
		sm:TransitionTo("Countdown")
]]

local Signal = require(script.Parent.Signal)

local StateMachine = {}
StateMachine.__index = StateMachine

export type AllowedTransitions = { [string]: { string } }

export type StateMachine = typeof(setmetatable(
	{} :: {
		_current: string,
		_allowed: AllowedTransitions,
		Changed: Signal.Signal,
	},
	StateMachine
))

function StateMachine.new(initialState: string, allowedTransitions: AllowedTransitions): StateMachine
	local self = setmetatable({
		_current = initialState,
		_allowed = allowedTransitions,
		Changed = Signal.new(),
	}, StateMachine)
	return self
end

function StateMachine:GetState(): string
	return self._current
end

function StateMachine:CanTransitionTo(newState: string): boolean
	local allowedFromCurrent = self._allowed[self._current]
	if not allowedFromCurrent then
		return false
	end
	return table.find(allowedFromCurrent, newState) ~= nil
end

-- Retorna true si la transición se realizó, false si fue rechazada
-- por no estar permitida desde el estado actual.
function StateMachine:TransitionTo(newState: string): boolean
	if not self:CanTransitionTo(newState) then
		warn(string.format("[StateMachine] Transición inválida: %s -> %s", self._current, newState))
		return false
	end

	local oldState = self._current
	self._current = newState
	self.Changed:Fire(newState, oldState)
	return true
end

function StateMachine:Destroy()
	self.Changed:Destroy()
end

return StateMachine
