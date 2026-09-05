--!strict
--[[
	ResourceService.lua

	Responsabilidad: ser la única autoridad sobre la existencia y el
	estado de los nodos de recursos del mundo (`Workspace.WorldMap.
	ResourceNodes`). Fase 5 del proyecto.

	Qué hace esta fase:
	- Al arrancar, escanea `ResourceNodes` y registra cada Part con
	  un Attribute `ResourceType` válido como un nodo administrado.
	- Guarda cantidad actual, cantidad máxima y estado ("Available" /
	  "Depleted") en memoria del servidor — el cliente nunca escribe
	  esto directamente.
	- Expone `ExtractResource(nodeId, amount)`: resta recursos de un
	  nodo, lo agota (oculta + deja de colisionar) cuando llega a 0,
	  y programa su regeneración según `ResourceConfig`.
	- El temporizador de respawn de cada nodo se registra en
	  `CleanupService.GetGlobalTrove()` para cancelarse limpiamente
	  si el servidor cierra a mitad de la espera, en vez de quedar
	  un `task.delay` colgado.

	Qué NO hace esta fase (a propósito, ver restricciones de la Fase 5):
	- No conecta ningún golpe de herramienta ni detecta al jugador
	  golpeando un nodo. `ExtractResource` es la API que la Fase 6
	  (hacha, pico, daño a recursos) va a llamar; esta fase solo dela
	  deja lista y probada, no la conecta a ningún input real.
	- No crea remotes ni replica el detalle de los nodos al cliente
	  más allá de lo que Roblox replica solo (posición/visibilidad de
	  los Parts en Workspace, y sus Attributes). Eso es suficiente
	  para que un nodo agotado se vea agotado en todos los clientes
	  sin necesidad de RemoteService en esta fase.
	- No toca inventario de jugador, construcción ni economía.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local ResourceTypeEnum = require(ReplicatedStorage.Shared.Enums.ResourceType)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local ResourceService = {}
ResourceService.Name = "ResourceService" :: string

local VALID_RESOURCE_TYPES: { [string]: boolean } = {
	[ResourceTypeEnum.Wood] = true,
	[ResourceTypeEnum.Stone] = true,
	[ResourceTypeEnum.Metal] = true,
	[ResourceTypeEnum.Scrap] = true,
}

-- Representación interna de un nodo. NO se expone tal cual al
-- exterior: buildNodeInfo() la traduce a Types.ResourceNodeInfo.
type NodeInternal = {
	Instance: BasePart,
	NodeId: string,
	ResourceType: Types.ResourceType,
	Amount: number,
	MaxAmount: number,
	State: Types.ResourceNodeState,
	-- Transparencia/colisión originales del placeholder, capturadas
	-- al escanear, para poder restaurarlas exactamente al reponerse
	-- (distintos tipos de nodo pueden venir con distinta apariencia
	-- desde el .model.json).
	OriginalTransparency: number,
	OriginalCanCollide: boolean,
}

local nodes: { [string]: NodeInternal } = {}

local debugRef: any = nil
local cleanupRef: any = nil

-- Fase 6 (y cualquier UI futura) puede suscribirse a esto para
-- enterarse de cambios de un nodo sin tener que hacer polling de
-- GetNode. Mismo patrón que PartyService.PartyChanged.
local NodeStateChanged = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("ResourceService", message)
	end
end

local function logWarn(message: string)
	if debugRef then
		debugRef:Warn("ResourceService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("ResourceService", message)
	end
end

local function buildNodeInfo(node: NodeInternal): Types.ResourceNodeInfo
	return {
		NodeId = node.NodeId,
		ResourceType = node.ResourceType,
		Amount = node.Amount,
		MaxAmount = node.MaxAmount,
		State = node.State,
	}
end

-- Refleja el estado actual en Attributes del propio Instance. Esto
-- es solo para inspección en Studio y para que un futuro cliente
-- pueda leer el estado por replicación normal de Attributes, sin
-- necesidad de un remote dedicado — no es la fuente de verdad (la
-- tabla `nodes` en memoria del servidor lo es).
local function syncAttributes(node: NodeInternal)
	node.Instance:SetAttribute("CurrentAmount", node.Amount)
	node.Instance:SetAttribute("State", node.State)
end

local function setNodeVisible(node: NodeInternal, visible: boolean)
	if visible then
		node.Instance.Transparency = node.OriginalTransparency
		node.Instance.CanCollide = node.OriginalCanCollide
	else
		node.Instance.Transparency = 1
		node.Instance.CanCollide = false
	end
end

local function respawnNode(node: NodeInternal)
	node.Amount = node.MaxAmount
	node.State = "Available"
	setNodeVisible(node, true)
	syncAttributes(node)

	log(string.format("Nodo %s (%s) regenerado.", node.NodeId, node.ResourceType))
	NodeStateChanged:Fire(node.NodeId, buildNodeInfo(node))
end

local function depleteNode(node: NodeInternal)
	node.State = "Depleted"
	setNodeVisible(node, false)
	syncAttributes(node)

	local config = ResourceConfig.Nodes[node.ResourceType]
	local respawnSeconds = config and config.RespawnSeconds or 60

	-- task.delay devuelve el thread programado, lo que permite
	-- cancelarlo con task.cancel si el servidor cierra antes de que
	-- se cumpla la espera. Se registra como función de limpieza en
	-- el Trove global (no como el thread en sí, que Trove no sabría
	-- limpiar) para que CleanupService lo cancele en BindToClose.
	local thread = task.delay(respawnSeconds, function()
		respawnNode(node)
	end)
	cleanupRef.GetGlobalTrove():Add(function()
		task.cancel(thread)
	end)

	log(
		string.format(
			"Nodo %s (%s) agotado. Regenera en %d s.",
			node.NodeId,
			node.ResourceType,
			respawnSeconds
		)
	)
	NodeStateChanged:Fire(node.NodeId, buildNodeInfo(node))
end

-- ============================================================
-- API pública
-- ============================================================

-- Resta `amount` unidades del nodo `nodeId`. Server-authoritative:
-- nunca extrae más de lo que el nodo tiene, nunca deja Amount
-- negativo, y agota + programa respawn automáticamente al llegar a
-- 0. Pensada para que la Fase 6 (herramientas) la llame directo,
-- sin necesidad de que ResourceService sepa nada de hachas ni picos.
function ResourceService.ExtractResource(nodeId: string, amount: number): Types.ResourceExtractionResult
	if type(amount) ~= "number" or amount <= 0 or amount ~= amount then
		return { Ok = false, Error = "InvalidAmount" }
	end

	local node = nodes[nodeId]
	if not node then
		return { Ok = false, Error = "NodeNotFound" }
	end

	if node.State == "Depleted" then
		return { Ok = false, Error = "NodeDepleted" }
	end

	local extracted = math.min(amount, node.Amount)
	node.Amount -= extracted
	syncAttributes(node)

	if node.Amount <= 0 then
		depleteNode(node)
	else
		NodeStateChanged:Fire(node.NodeId, buildNodeInfo(node))
	end

	return {
		Ok = true,
		Extracted = extracted,
		Remaining = node.Amount,
		State = node.State,
	}
end

-- Snapshot de solo lectura de un nodo puntual, o nil si el id no
-- existe.
function ResourceService.GetNode(nodeId: string): Types.ResourceNodeInfo?
	local node = nodes[nodeId]
	if not node then
		return nil
	end
	return buildNodeInfo(node)
end

-- Snapshot de todos los nodos administrados. Devuelve una tabla
-- nueva cada vez (nunca la referencia interna).
function ResourceService.GetAllNodes(): { Types.ResourceNodeInfo }
	local result: { Types.ResourceNodeInfo } = {}
	for _, node in pairs(nodes) do
		table.insert(result, buildNodeInfo(node))
	end
	return result
end

-- Filtra por tipo de recurso (ej. para que un futuro sistema de
-- minimapa muestre solo nodos de madera).
function ResourceService.GetNodesByType(resourceType: string): { Types.ResourceNodeInfo }
	local result: { Types.ResourceNodeInfo } = {}
	for _, node in pairs(nodes) do
		if node.ResourceType == resourceType then
			table.insert(result, buildNodeInfo(node))
		end
	end
	return result
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

-- Registra un único Part como nodo administrado. Separado de Start()
-- para poder testear/leer con claridad qué hace el escaneo inicial.
local function registerNode(instance: Instance)
	if not instance:IsA("BasePart") then
		logWarn(string.format("%s no es un BasePart, se ignora como nodo de recurso.", instance:GetFullName()))
		return
	end

	local resourceType = instance:GetAttribute("ResourceType")
	if type(resourceType) ~= "string" or not VALID_RESOURCE_TYPES[resourceType] then
		logWarn(
			string.format(
				"%s no tiene un Attribute ResourceType válido (valor: %s), se ignora.",
				instance:GetFullName(),
				tostring(resourceType)
			)
		)
		return
	end

	local nodeId = instance.Name
	if nodes[nodeId] then
		logError(string.format("NodeId duplicado en ResourceNodes: %s. Se ignora el duplicado.", nodeId))
		return
	end

	local config = ResourceConfig.Nodes[resourceType]
	if not config then
		logError(string.format("ResourceConfig no tiene entrada para el tipo %s (nodo %s).", resourceType, nodeId))
		return
	end

	local part = instance :: BasePart
	local node: NodeInternal = {
		Instance = part,
		NodeId = nodeId,
		ResourceType = resourceType :: Types.ResourceType,
		Amount = config.Amount,
		MaxAmount = config.Amount,
		State = "Available",
		OriginalTransparency = part.Transparency,
		OriginalCanCollide = part.CanCollide,
	}

	nodes[nodeId] = node
	syncAttributes(node)
end

function ResourceService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
end

function ResourceService:Start()
	local worldMap = Workspace:FindFirstChild("WorldMap")
	local resourceNodesFolder = worldMap and worldMap:FindFirstChild("ResourceNodes")

	if not resourceNodesFolder then
		logWarn("No se encontró Workspace.WorldMap.ResourceNodes. ResourceService arranca sin nodos.")
		return
	end

	for _, child in ipairs(resourceNodesFolder:GetChildren()) do
		registerNode(child)
	end

	local count = 0
	for _ in pairs(nodes) do
		count += 1
	end
	log(string.format("%d nodos de recursos registrados.", count))
end

-- Fase 6 (y cualquier HUD futuro) se suscribe a esto para reaccionar
-- a extracciones/agotamiento/respawn sin que ResourceService necesite
-- conocer nada sobre herramientas ni UI.
ResourceService.NodeStateChanged = NodeStateChanged

return ResourceService
