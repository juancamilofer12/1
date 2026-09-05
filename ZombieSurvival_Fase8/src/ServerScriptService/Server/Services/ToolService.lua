--!strict
--[[
	ToolService.lua

	Responsabilidad: ser la única autoridad sobre qué herramienta
	tiene equipada cada jugador y validar/ejecutar sus golpes contra
	nodos de recursos. Fase 6 del proyecto.

	Server-authoritative, mismos patrones que el resto del proyecto:
	- `RemoteService.Get(name)` para los remotes (nunca los crea).
	- `CleanupService.GetGlobalTrove()` para `Players.PlayerRemoving`.
	- `DebugService` para logging.
	- La RemoteFunction devuelve siempre `Types.HarvestResult`, nunca
	  un valor suelto, mismo criterio que `PartyActionResult`/
	  `MatchActionResult`.
	- `safeInvoke` (idéntico al de `PartyService`) evita que un error
	  interno tire abajo el remote o filtre un stack trace al cliente.

	Qué cambió en la Fase 7 (ver PROJECT_MANIFEST.md): la Fase 6 dejó
	pendiente, a propósito, decidir si equipar una herramienta debía
	empezar a gatear posesión una vez existiera inventario real. Ahora
	existe: este servicio YA NO mantiene su propia tabla
	`equippedTool` ni el remote `Tool_Equip` (retirado de
	RemotesConfig) — equipar una herramienta es ahora un caso más de
	`Inventory_Equip` (mochila -> `EquipmentSlot.Tool`), y este
	servicio simplemente le PREGUNTA a `EquipmentService` qué
	herramienta está equipada ahí. Esto automáticamente exige
	posesión real: no se puede equipar lo que no está en la mochila.

	Qué hace esta fase (Fase 6, con el ajuste de arriba):
	- Valida un pedido de golpe (`Tool_RequestHarvest`) en el orden
	  exacto que pide la Fase 6: distancia máxima jugador-nodo,
	  herramienta correcta para el `ResourceType` del nodo, cooldown
	  de la herramienta, y que el nodo esté `Available`. Si todo pasa,
	  invoca `ResourceService.ExtractResource(nodeId, toolDamage)` y
	  acredita lo extraído con `InventoryService.AddItem` (Fase 7;
	  reemplaza a `PlayerDataService.AddResource` de la Fase 6, que la
	  mochila real ya no usa).
	- La posición del nodo se lee directamente del `BasePart` en
	  `Workspace.WorldMap.ResourceNodes` (mismo Instance que
	  `ResourceService` ya expone públicamente por Nombre = NodeId):
	  este servicio no necesita que `ResourceService` exponga un
	  getter nuevo para eso.

	Qué NO hace esta fase (a propósito, ver restricciones de la Fase 7):
	- No toca zombies, IA, construcción ni economía de tiendas.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local EquipmentSlot = require(ReplicatedStorage.Shared.Enums.EquipmentSlot)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local ToolService = {}
ToolService.Name = "ToolService" :: string

-- UserId -> os.clock() del último golpe válido (de cualquier
-- herramienta). Un cooldown por jugador, no por nodo ni por
-- herramienta: es la lectura más simple de "cooldown de uso de la
-- herramienta" y evita que cambiar de herramienta sea una forma de
-- saltarse el cooldown de la anterior.
local lastHarvestAt: { [number]: number } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local remoteRef: any = nil
local resourceRef: any = nil
local inventoryRef: any = nil
local equipmentRef: any = nil

-- Fase 6 (y cualquier HUD futuro) puede suscribirse a esto para
-- reaccionar a golpes exitosos sin tener que engancharse al remote
-- directamente. Mismo patrón que ResourceService.NodeStateChanged.
local HarvestPerformed = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("ToolService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("ToolService", message)
	end
end

-- Busca el BasePart real de un nodo en Workspace.WorldMap.ResourceNodes
-- por NodeId (= Instance.Name, ver ResourceService.registerNode).
-- Devuelve nil si el mapa, la carpeta o el nodo puntual no existen.
local function findNodeInstance(nodeId: string): BasePart?
	local worldMap = Workspace:FindFirstChild("WorldMap")
	local resourceNodesFolder = worldMap and worldMap:FindFirstChild("ResourceNodes")
	if not resourceNodesFolder then
		return nil
	end

	local instance = resourceNodesFolder:FindFirstChild(nodeId)
	if instance and instance:IsA("BasePart") then
		return instance
	end
	return nil
end

-- true si `resourceType` está en la lista EffectiveAgainst de `toolConfig`.
local function isEffectiveAgainst(toolConfig: any, resourceType: string): boolean
	for _, effective in ipairs(toolConfig.EffectiveAgainst) do
		if effective == resourceType then
			return true
		end
	end
	return false
end

-- Devuelve false (y bloquea el golpe) si el jugador golpeó más
-- rápido que el cooldown de su herramienta actual. Igual criterio
-- que PartyService.checkRateLimit: solo actualiza el timestamp
-- cuando el golpe SÍ se permite.
local function checkCooldown(userId: number, cooldownSeconds: number): boolean
	local now = os.clock()
	local last = lastHarvestAt[userId]
	if last ~= nil and (now - last) < cooldownSeconds then
		return false
	end
	lastHarvestAt[userId] = now
	return true
end

-- ============================================================
-- API pública
-- ============================================================

function ToolService.RequestHarvest(player: Player, nodeId: any): Types.HarvestResult
	if type(nodeId) ~= "string" then
		return { Ok = false, Error = "InvalidNodeId" }
	end

	local userId = player.UserId

	-- Se necesita el nodo (vía ResourceService, la única autoridad
	-- sobre su estado) antes de poder validar nada más: distancia y
	-- herramienta correcta dependen de su posición/ResourceType.
	local node = resourceRef.GetNode(nodeId)
	if not node then
		return { Ok = false, Error = "NodeNotFound", NodeId = nodeId }
	end

	-- 1) Distancia máxima jugador-nodo.
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return { Ok = false, Error = "NoCharacter", NodeId = nodeId }
	end

	local nodeInstance = findNodeInstance(nodeId)
	if not nodeInstance then
		-- Defensivo: ResourceService ya confirmó que el nodo existe en
		-- su tabla interna, así que esto solo pasaría si el Part fue
		-- destruido por fuera del flujo normal.
		return { Ok = false, Error = "NodeNotFound", NodeId = nodeId }
	end

	local distance = (nodeInstance.Position - (humanoidRootPart :: BasePart).Position).Magnitude
	if distance > ToolConfig.MaxHarvestDistance then
		return { Ok = false, Error = "TooFar", NodeId = nodeId }
	end

	-- 2) Herramienta correcta equipada para el ResourceType del nodo.
	-- Fase 7: ya no se lee de una tabla propia — se consulta a
	-- EquipmentService, que exige posesión real en la mochila.
	local toolId = equipmentRef.GetEquippedItemId(player, EquipmentSlot.Tool)
	if not toolId then
		return { Ok = false, Error = "NoToolEquipped", NodeId = nodeId }
	end

	local toolConfig = ToolConfig.Tools[toolId]
	if not toolConfig or not isEffectiveAgainst(toolConfig, node.ResourceType) then
		return { Ok = false, Error = "WrongTool", NodeId = nodeId }
	end

	-- 3) Cooldown de uso de la herramienta.
	if not checkCooldown(userId, toolConfig.CooldownSeconds) then
		return { Ok = false, Error = "ToolOnCooldown", NodeId = nodeId }
	end

	-- 4) Que el nodo esté disponible. (ExtractResource también lo
	-- valida internamente, pero se chequea acá explícitamente porque
	-- la Fase 6 lo pide como paso propio, con su propio código de error.)
	if node.State ~= "Available" then
		return { Ok = false, Error = "NodeDepleted", NodeId = nodeId }
	end

	local extraction: Types.ResourceExtractionResult = resourceRef.ExtractResource(nodeId, toolConfig.Damage)
	if not extraction.Ok then
		return { Ok = false, Error = extraction.Error, NodeId = nodeId }
	end

	local extracted = extraction.Extracted :: number
	-- Fase 7: se acredita vía InventoryService.AddItem (mochila real)
	-- en vez de PlayerDataService.AddResource (retirado). Un
	-- ResourceType es, para el inventario, un ItemId más (ver
	-- ItemConfig.lua) — InventoryService no necesita saber que este
	-- en particular vino de un golpe de herramienta.
	local addResult = inventoryRef.AddItem(player, node.ResourceType, extracted)
	if not addResult.Ok then
		-- El recurso ya se extrajo del mundo (server-authoritative,
		-- no se revierte) pero no se pudo acreditar — típicamente
		-- "InventoryFull" (mochila llena) o, en un caso extremo,
		-- "DataNotLoaded" si el cliente disparó Tool_RequestHarvest
		-- antes de que PlayerDataService terminara de cargar.
		-- Documentado en vez de ignorado en silencio.
		logError(
			string.format(
				"%s (UserId %d) extrajo de %s pero no se pudo acreditar (%s); recurso perdido.",
				player.Name,
				userId,
				nodeId,
				tostring(addResult.Error)
			)
		)
	end

	log(
		string.format(
			"%s (UserId %d) golpeó %s con %s: +%d %s",
			player.Name,
			userId,
			nodeId,
			toolId,
			extracted,
			node.ResourceType
		)
	)

	HarvestPerformed:Fire(player, nodeId, node.ResourceType, extracted)

	return {
		Ok = true,
		NodeId = nodeId,
		ResourceType = node.ResourceType,
		Extracted = extracted,
		Remaining = extraction.Remaining,
		State = extraction.State,
	}
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function ToolService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	remoteRef = registry.RemoteService
	resourceRef = registry.ResourceService
	inventoryRef = registry.InventoryService
	equipmentRef = registry.EquipmentService
end

-- Envuelve un handler de RemoteFunction en pcall, mismo patrón que
-- PartyService.safeInvoke: un error inesperado nunca debe tirar
-- abajo el remote ni filtrar un stack trace interno al cliente.
local function safeInvoke(
	actionName: string,
	handler: (player: Player, ...any) -> any,
	errorResult: any
): (player: Player, ...any) -> any
	return function(player: Player, ...: any): any
		local ok, result = pcall(handler, player, ...)
		if not ok then
			logError(string.format("Error interno en %s: %s", actionName, tostring(result)))
			return errorResult
		end
		return result
	end
end

function ToolService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	local harvestRemote = remoteRef.Get("Tool_RequestHarvest") :: RemoteFunction
	harvestRemote.OnServerInvoke = safeInvoke(
		"Tool_RequestHarvest",
		function(player: Player, nodeId: any)
			return ToolService.RequestHarvest(player, nodeId)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.HarvestResult
	)

	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		lastHarvestAt[player.UserId] = nil
	end))

	log("ToolService listo.")
end

ToolService.HarvestPerformed = HarvestPerformed

return ToolService
