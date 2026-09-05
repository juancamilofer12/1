--!strict
--[[
	CleanupService.lua

	Responsabilidad: dar a los demás servicios un lugar centralizado
	para registrar recursos que deben limpiarse:
	  - al cerrarse el servidor (BindToClose),
	  - o cuando un jugador se va (PlayerRemoving).

	No reemplaza a Trove.lua (que es la utilidad genérica) sino que
	ORQUESTA troves: mantiene un Trove global del servidor y un Trove
	por jugador, y los limpia en el momento correcto automáticamente.

	Otros servicios NO deben escuchar PlayerRemoving por su cuenta
	para limpiar sus propios recursos de jugador: deben registrar
	esos recursos acá vía GetPlayerTrove(player):Add(...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Utils.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

-- No se castea `{} :: Types.Service` acá: eso sellaría el tipo del
-- módulo y bloquearía agregar métodos propios (Get*, Cleanup*) bajo
-- --!strict. El contrato Types.Service se verifica al consumir este
-- módulo desde ServiceLoader.
local CleanupService = {}
CleanupService.Name = "CleanupService" :: string

local globalTrove = Trove.new()
local playerTroves: { [Player]: Trove.Trove } = {}

local debugRef: any = nil

function CleanupService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
end

function CleanupService:Start()
	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		CleanupService.CleanupPlayer(player)
	end))

	game:BindToClose(function()
		if debugRef then
			debugRef:Info("CleanupService", "Servidor cerrando, limpiando recursos globales...")
		end
		globalTrove:Destroy()
	end)
end

-- Agrega un recurso que vive mientras viva el servidor.
function CleanupService.GetGlobalTrove(): Trove.Trove
	return globalTrove
end

-- Devuelve (creándolo si no existe) el Trove asociado a un jugador.
-- Cualquier servicio con recursos por-jugador (conexiones, objetos
-- en Workspace, etc.) debe agregarlos acá.
function CleanupService.GetPlayerTrove(player: Player): Trove.Trove
	local existing = playerTroves[player]
	if existing then
		return existing
	end
	local newTrove = Trove.new()
	playerTroves[player] = newTrove
	return newTrove
end

function CleanupService.CleanupPlayer(player: Player)
	local trove = playerTroves[player]
	if trove then
		trove:Destroy()
		playerTroves[player] = nil
	end
end

return CleanupService
