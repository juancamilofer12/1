--!strict
--[[
	RemoteService.lua

	Único servicio autorizado a crear instancias de RemoteEvent /
	RemoteFunction en el servidor. Lee RemotesConfig.Definitions
	(la fuente de verdad) y crea todo dentro de una carpeta en
	ReplicatedStorage.

	Otros servicios NO deben hacer Instance.new("RemoteEvent")
	directamente: deben pedirle la instancia a este servicio con
	RemoteService.Get(name) y, del lado servidor, conectar
	OnServerEvent / OnServerInvoke ellos mismos (RemoteService no
	conoce la lógica de gameplay de cada remote).

	IMPORTANTE (server-authoritative): cualquier callback que un
	servicio conecte a OnServerEvent/OnServerInvoke debe validar
	SIEMPRE los datos recibidos del cliente. Este servicio solo
	provee el transporte, no valida payloads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesConfig = require(ReplicatedStorage.Shared.Config.RemotesConfig)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local RemoteService = {}
RemoteService.Name = "RemoteService" :: string

local instances: { [string]: RemoteEvent | RemoteFunction } = {}
local folder: Folder? = nil
local debugRef: any = nil

function RemoteService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService

	local newFolder = Instance.new("Folder")
	newFolder.Name = RemotesConfig.FolderName

	for _, def in ipairs(RemotesConfig.Definitions) do
		if instances[def.Name] then
			error("[RemoteService] Remote duplicado en RemotesConfig: " .. def.Name)
		end

		local instance: Instance
		if def.Kind == "RemoteEvent" then
			instance = Instance.new("RemoteEvent")
		elseif def.Kind == "RemoteFunction" then
			instance = Instance.new("RemoteFunction")
		else
			error("[RemoteService] Kind desconocido para " .. def.Name .. ": " .. tostring(def.Kind))
		end

		instance.Name = def.Name
		instance.Parent = newFolder
		instances[def.Name] = instance :: any
	end

	-- Recién ahora se publica la carpeta, cuando ya tiene todos sus
	-- remotes creados: evita que un cliente vea la carpeta a medio
	-- poblar por una condición de carrera.
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end

function RemoteService:Start()
	if debugRef then
		debugRef:Info("RemoteService", string.format("%d remotes creados", #RemotesConfig.Definitions))
	end

	-- Handler de infraestructura para el remote "Ping": permite a
	-- cualquier LocalScript verificar que el pipeline cliente-servidor
	-- funciona de punta a punta. No es gameplay, es un health-check.
	local pingRemote = instances["Ping"] :: RemoteFunction
	pingRemote.OnServerInvoke = function(_player: Player)
		return os.time()
	end
end

-- Devuelve la instancia real de un remote ya creado.
function RemoteService.Get(name: string): RemoteEvent | RemoteFunction
	local instance = instances[name]
	if not instance then
		error("[RemoteService] Remote no encontrado (¿falta declararlo en RemotesConfig?): " .. name)
	end
	return instance
end

return RemoteService
