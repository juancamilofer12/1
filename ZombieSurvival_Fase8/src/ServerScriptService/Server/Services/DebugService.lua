--!strict
--[[
	DebugService.lua

	Sistema centralizado de logging/debug del servidor. En vez de
	usar print()/warn() sueltos por todo el código, cada servicio
	debe hacer:

		local Debug = registry.DebugService
		Debug:Info("MatchService", "Partida iniciada")
		Debug:Warn("PlayerDataService", "Reintentando guardado...")
		Debug:Error("RemoteService", "Remote duplicado: " .. name)

	El nivel mínimo a imprimir se controla desde GameConfig.LogLevel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local DebugService = {}
DebugService.Name = "DebugService" :: string

local LEVEL_ORDER: { [Types.LogLevel]: number } = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

local minLevelValue = LEVEL_ORDER[GameConfig.LogLevel :: Types.LogLevel] or LEVEL_ORDER.INFO

local function shouldLog(level: Types.LogLevel): boolean
	return LEVEL_ORDER[level] >= minLevelValue
end

local function format(level: Types.LogLevel, source: string, message: string): string
	if GameConfig.LogShowSource then
		return string.format("[%s][%s] %s", level, source, message)
	end
	return string.format("[%s] %s", level, message)
end

function DebugService:Init(_registry: Types.ServiceRegistry) end

function DebugService:Start() end

function DebugService:Debug(source: string, message: string)
	if shouldLog("DEBUG") then
		print(format("DEBUG", source, message))
	end
end

function DebugService:Info(source: string, message: string)
	if shouldLog("INFO") then
		print(format("INFO", source, message))
	end
end

function DebugService:Warn(source: string, message: string)
	if shouldLog("WARN") then
		warn(format("WARN", source, message))
	end
end

function DebugService:Error(source: string, message: string)
	if shouldLog("ERROR") then
		warn(format("ERROR", source, message))
	end
end

return DebugService
