--!strict
--[[
	init.server.lua

	Bootstrap del servidor. Único punto de entrada: se ejecuta
	automáticamente al arrancar el servidor (por ser un Script
	llamado `init.server.lua` dentro de ServerScriptService).

	Responsabilidad: delegar TODA la inicialización a ServiceLoader.
	Este archivo no debe crecer con lógica de gameplay; si algo nuevo
	necesita ejecutarse al arrancar, debe vivir dentro de un servicio
	y su :Init()/:Start(), no acá.
]]

local ServiceLoader = require(script.ServiceLoader)

local ok, registryOrError = pcall(ServiceLoader.LoadAll)

if not ok then
	error("[Bootstrap] Falló la inicialización del servidor: " .. tostring(registryOrError))
end

local registry = registryOrError
local debugService = registry.DebugService :: any
if debugService then
	debugService:Info("Bootstrap", "Servidor inicializado correctamente.")
end
