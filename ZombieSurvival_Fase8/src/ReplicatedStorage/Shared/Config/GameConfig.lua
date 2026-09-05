--!strict
--[[
	GameConfig.lua

	Configuración general y transversal del juego. Cualquier valor
	"mágico" (números sueltos en el código) que no pertenezca
	específicamente a Match o a PlayerData va acá.

	Este módulo se congela (DeepFreeze) para que ningún script pueda
	mutarlo accidentalmente en runtime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

local GameConfig = {
	-- Nivel mínimo de log que se imprime en la consola del servidor.
	-- Ver LogLevel en Types.lua: "DEBUG" | "INFO" | "WARN" | "ERROR"
	LogLevel = "INFO",

	-- Si es true, DebugService también imprime la fuente (servicio)
	-- de cada log.
	LogShowSource = true,
}

return TableUtils.DeepFreeze(GameConfig)
