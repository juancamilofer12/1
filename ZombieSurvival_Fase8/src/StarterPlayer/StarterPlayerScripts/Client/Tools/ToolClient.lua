--!strict
--[[
	ToolClient.lua

	Arnés de prueba mínimo para el sistema de herramientas (Fase 6).
	Explícitamente NO es la UI final (sin mochila, sin hotbar visual,
	sin animaciones de golpe): solo lo mínimo para poder equipar hacha/
	pico y golpear el nodo de recurso más cercano desde el teclado,
	e imprimir en el output qué devolvió el servidor. Mismo espíritu
	de "UI de prueba" que `Client/Party/PartyUI.lua` en la Fase 2.

	Controles:
		1 -> equipar WoodcutterAxe (vía InventoryClient.Equip, Fase 7)
		2 -> equipar Pickaxe (ídem)
		F -> golpear el nodo de recurso más cercano dentro de rango
		     (Tool_RequestHarvest)

	Fase 7: equipar ya NO es un remote propio de herramientas
	(Tool_Equip se retiró) — es un caso más de mochila real
	(Inventory_Equip hacia EquipmentSlot.Tool), y por eso exige tener
	la herramienta en la mochila (ver InventoryConfig.StarterItems:
	el kit inicial no incluye ninguna herramienta, así que probar "1"/
	"2" sin haber conseguido una vía otro medio devuelve
	"NotInInventory" — documentado, no es un bug del arnés).

	El servidor sigue siendo la autoridad: este cliente solo elige QUÉ
	nodo pedir golpear (el más cercano visible en Workspace) y muestra
	el resultado; nunca decide localmente si el golpe es válido — eso
	siempre lo valida ToolService del lado servidor.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local ToolType = require(ReplicatedStorage.Shared.Enums.ToolType)
local EquipmentSlot = require(ReplicatedStorage.Shared.Enums.EquipmentSlot)
local Types = require(ReplicatedStorage.Shared.Types)

local InventoryClient = require(script.Parent.Parent.Inventory.InventoryClient)

local localPlayer = Players.LocalPlayer

local ToolClient = {}

-- Evita que un mismo InputBegan dispare dos invokes simultáneos
-- mientras el primero no respondió todavía. Solo comodidad de
-- cliente: la protección real de spam es el cooldown server-side
-- (ToolConfig.Tools[toolId].CooldownSeconds).
local actionInFlight = false

local function withDebounce(callback: () -> ())
	if actionInFlight then
		return
	end
	actionInFlight = true
	local ok, err = pcall(callback)
	actionInFlight = false
	if not ok then
		warn("[ToolClient] Error ejecutando acción:", err)
	end
end

-- Busca, entre los nodos de recursos replicados en
-- Workspace.WorldMap.ResourceNodes, el más cercano al jugador que
-- esté dentro de ToolConfig.MaxHarvestDistance y marcado "Available"
-- por sus Attributes (ver ResourceService.syncAttributes, Fase 5).
-- Devuelve nil si no hay ninguno en rango: es solo una ayuda de
-- cliente para elegir a qué nodo apuntar, el servidor igual vuelve a
-- validar distancia y disponibilidad de forma independiente.
local function findNearestAvailableNode(): string?
	local character = localPlayer.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return nil
	end

	local worldMap = Workspace:FindFirstChild("WorldMap")
	local resourceNodesFolder = worldMap and worldMap:FindFirstChild("ResourceNodes")
	if not resourceNodesFolder then
		return nil
	end

	local rootPosition = (humanoidRootPart :: BasePart).Position

	local nearestNodeId: string? = nil
	local nearestDistance = math.huge

	for _, instance in ipairs(resourceNodesFolder:GetChildren()) do
		if instance:IsA("BasePart") and instance:GetAttribute("State") == "Available" then
			local distance = (instance.Position - rootPosition).Magnitude
			if distance <= ToolConfig.MaxHarvestDistance and distance < nearestDistance then
				nearestDistance = distance
				nearestNodeId = instance.Name
			end
		end
	end

	return nearestNodeId
end

local function equip(toolId: Types.ToolId)
	withDebounce(function()
		local result = InventoryClient.Equip(toolId, EquipmentSlot.Tool)
		if result.Ok then
			print("[ToolClient] Herramienta equipada:", toolId)
		else
			warn("[ToolClient] No se pudo equipar", toolId, "->", result.Error)
		end
	end)
end

local function harvestNearest()
	withDebounce(function()
		local nodeId = findNearestAvailableNode()
		if not nodeId then
			print("[ToolClient] Ningún nodo disponible en rango.")
			return
		end

		local result = NetClient.InvokeServer("Tool_RequestHarvest", nodeId) :: Types.HarvestResult
		if result.Ok then
			print(
				string.format(
					"[ToolClient] Golpe a %s: +%d %s (quedan %d)",
					nodeId,
					result.Extracted :: number,
					result.ResourceType :: string,
					result.Remaining :: number
				)
			)
		else
			warn(string.format("[ToolClient] Golpe a %s rechazado: %s", nodeId, tostring(result.Error)))
		end
	end)
end

function ToolClient.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.KeyCode == Enum.KeyCode.One then
			equip(ToolType.WoodcutterAxe)
		elseif input.KeyCode == Enum.KeyCode.Two then
			equip(ToolType.Pickaxe)
		elseif input.KeyCode == Enum.KeyCode.F then
			harvestNearest()
		end
	end)
end

return ToolClient
