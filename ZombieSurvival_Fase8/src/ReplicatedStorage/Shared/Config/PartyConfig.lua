--!strict
--[[
	PartyConfig.lua

	Parámetros del sistema de grupos (Party) del lobby. PartyService
	lee estos valores en vez de tener números sueltos hardcodeados.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

local PartyConfig = {
	-- Cantidad máxima de miembros por party.
	MaximumMembers = 4,

	-- Tiempo mínimo, en segundos, entre dos acciones de party
	-- (crear, unirse, abandonar, expulsar, transferir) de un mismo
	-- jugador. Es la defensa principal contra spam de remotes,
	-- incluyendo el patrón "crear -> abandonar -> crear" repetido.
	ActionCooldownSeconds = 0.5,
}

return TableUtils.DeepFreeze(PartyConfig)
