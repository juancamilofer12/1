--!strict
--[[
	NetClient.lua

	Punto único de acceso a los remotes desde el cliente. En vez de
	que cada LocalScript navegue manualmente
	ReplicatedStorage.Net.NombreDelRemote, se usa este módulo.

	Ventajas:
	- Si cambia la ruta/carpeta de los remotes, se ajusta en un solo
	  lugar.
	- Falla rápido y con un mensaje claro si un remote no existe
	  (typo, remote no creado todavía por RemoteService, etc.)
	  en vez de un error críptico de WaitForChild.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesConfig = require(ReplicatedStorage.Shared.Config.RemotesConfig)

local NetClient = {}

local WAIT_TIMEOUT = 10 -- segundos

local folder: Instance? = nil

local function getFolder(): Instance
	if folder then
		return folder
	end
	local found = ReplicatedStorage:WaitForChild(RemotesConfig.FolderName, WAIT_TIMEOUT)
	if not found then
		error(
			string.format(
				"[NetClient] No se encontró la carpeta de remotes '%s' tras %d segundos. "
					.. "¿RemoteService se inicializó en el servidor?",
				RemotesConfig.FolderName,
				WAIT_TIMEOUT
			)
		)
	end
	folder = found
	return found
end

local function getDefinition(name: string): RemotesConfig.RemoteDefinition
	for _, def in ipairs(RemotesConfig.Definitions) do
		if def.Name == name then
			return def
		end
	end
	error(string.format("[NetClient] '%s' no está declarado en RemotesConfig.Definitions", name))
end

local function getInstance(name: string): RemoteEvent | RemoteFunction
	local def = getDefinition(name)
	local instance = getFolder():WaitForChild(name, WAIT_TIMEOUT)
	if not instance then
		error(string.format("[NetClient] El remote '%s' no apareció tras %d segundos", name, WAIT_TIMEOUT))
	end
	return instance :: any
end

function NetClient.FireServer(name: string, ...: any)
	local remote = getInstance(name)
	assert(remote:IsA("RemoteEvent"), string.format("'%s' no es un RemoteEvent", name))
	remote:FireServer(...)
end

function NetClient.InvokeServer(name: string, ...: any): ...any
	local remote = getInstance(name)
	assert(remote:IsA("RemoteFunction"), string.format("'%s' no es una RemoteFunction", name))
	return remote:InvokeServer(...)
end

function NetClient.OnClientEvent(name: string, callback: (...any) -> ()): RBXScriptConnection
	local remote = getInstance(name)
	assert(remote:IsA("RemoteEvent"), string.format("'%s' no es un RemoteEvent", name))
	return remote.OnClientEvent:Connect(callback)
end

return NetClient
