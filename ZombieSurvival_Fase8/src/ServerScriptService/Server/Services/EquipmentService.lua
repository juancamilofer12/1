--!strict
--[[
	EquipmentService.lua

	Responsabilidad: ser la única autoridad sobre qué objeto tiene
	cada jugador en cada uno de los 5 slots de equipamiento
	(EquipmentSlot.lua: Arma Principal, Arma Secundaria, Herramienta,
	Utilidad, Curación). Fase 7 del proyecto.

	Igual que InventoryService, opera directamente sobre
	`PlayerDataService.Get(player).Equipment` (persistido), y delega
	en `InventoryService.RemoveFromSlot`/`PlaceInFirstEmptySlot` para
	mover el objeto físico entre la mochila y el equipamiento sin
	duplicar la lógica de "encontrar/liberar un slot de mochila".

	`SLOT_ACCEPTS` es la única fuente de verdad sobre qué ItemCategory
	puede ir en cada slot: PrimaryWeapon/SecondaryWeapon aceptan
	Weapon, Tool acepta Tool, Utility acepta Utility, Healing acepta
	Healing. Un objeto de categoría Resource nunca es equipable (no
	tiene entrada acá).

	Esta fase reemplaza y GATEA lo que la Fase 6 dejó pendiente
	explícitamente (ver PROJECT_MANIFEST.md, "Próxima fase sugerida"
	de la Fase 6): equipar una herramienta ya NO acepta cualquier
	ToolId sin verificar posesión — ahora hay que tenerla realmente en
	la mochila. `ToolService` dejó de mantener su propia tabla
	`equippedTool` y en su lugar consulta
	`EquipmentService.GetEquippedItemId(player, EquipmentSlot.Tool)`.
	El remote `Tool_Equip` de la Fase 6 se retira: equipar una
	herramienta es ahora un caso más de `Inventory_Equip`.

	Qué NO hace esta fase:
	- No conoce nada sobre daño/munición (eso es WeaponService/
	  CombatService, que consultan `GetEquippedItemId` para saber qué
	  arma está en PrimaryWeapon/SecondaryWeapon).
	- No implementa un HUD de equipamiento: el cliente arma su UI a
	  partir del `Types.EquipmentSnapshot` que cada remote devuelve.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local EquipmentSlot = require(ReplicatedStorage.Shared.Enums.EquipmentSlot)
local ItemCategory = require(ReplicatedStorage.Shared.Enums.ItemCategory)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local EquipmentService = {}
EquipmentService.Name = "EquipmentService" :: string

-- Qué ItemCategory acepta cada slot. Único punto de verdad: tanto la
-- validación de Inventory_Equip como cualquier futura UI de mochila
-- deberían consultar esto en vez de tener su propia copia.
local SLOT_ACCEPTS: { [string]: string } = {
	[EquipmentSlot.PrimaryWeapon] = ItemCategory.Weapon,
	[EquipmentSlot.SecondaryWeapon] = ItemCategory.Weapon,
	[EquipmentSlot.Tool] = ItemCategory.Tool,
	[EquipmentSlot.Utility] = ItemCategory.Utility,
	[EquipmentSlot.Healing] = ItemCategory.Healing,
}

local debugRef: any = nil
local remoteRef: any = nil
local playerDataRef: any = nil
local inventoryRef: any = nil

local function log(message: string)
	if debugRef then
		debugRef:Info("EquipmentService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("EquipmentService", message)
	end
end

local function buildInventorySnapshot(player: Player): Types.InventorySnapshot?
	return inventoryRef.GetSnapshot(player)
end

local function buildEquipmentSnapshot(player: Player): Types.EquipmentSnapshot?
	local data = playerDataRef.Get(player)
	if not data then
		return nil
	end
	-- Copia superficial de primer nivel, mismo criterio que
	-- InventoryService.buildSnapshot: nunca se expone la tabla
	-- `Equipment` interna tal cual.
	return table.clone(data.Equipment) :: Types.EquipmentSnapshot
end

-- ============================================================
-- API pública
-- ============================================================

-- Lectura de solo consulta usada por ToolService/WeaponService/
-- CombatService para saber qué ItemId tiene un jugador en un slot
-- puntual, sin pasar por remotes. Devuelve nil si el slot está vacío
-- o los datos no cargaron.
function EquipmentService.GetEquippedItemId(player: Player, slotName: string): string?
	local data = playerDataRef.Get(player)
	if not data then
		return nil
	end
	local stack = data.Equipment[slotName]
	return stack and stack.ItemId or nil
end

function EquipmentService.GetSnapshot(player: Player): Types.EquipmentSnapshot?
	return buildEquipmentSnapshot(player)
end

-- Snapshot combinado de mochila + equipamiento. Único propósito:
-- servir al remote de solo-lectura "Inventory_GetSnapshot" (ver
-- Types.InventoryStateSnapshot) que el cliente pide una vez al
-- conectar. Vive acá (no en InventoryService) porque es el único
-- lugar del servidor que ya tiene ambas referencias (`inventoryRef` y
-- `playerDataRef`) sin crear una dependencia nueva.
function EquipmentService.GetFullState(player: Player): Types.InventoryStateSnapshot
	return {
		Inventory = buildInventorySnapshot(player),
		Equipment = buildEquipmentSnapshot(player),
	}
end

-- Mueve el objeto de `inventorySlotIndex` (mochila) al slot de
-- equipamiento `equipSlotName`. Si ese slot ya tenía algo equipado,
-- lo intercambia (swap): el objeto previamente equipado vuelve al
-- MISMO índice de mochila que se vació, así el jugador nunca pierde
-- de vista dónde quedó.
function EquipmentService.EquipFromInventorySlot(
	player: Player,
	inventorySlotIndex: any,
	equipSlotName: any
): Types.EquipmentActionResult
	if type(inventorySlotIndex) ~= "number" then
		return { Ok = false, Error = "InvalidSlot" }
	end
	if type(equipSlotName) ~= "string" or not SLOT_ACCEPTS[equipSlotName] then
		return { Ok = false, Error = "InvalidEquipmentSlot" }
	end

	local data = playerDataRef.Get(player)
	if not data then
		return { Ok = false, Error = "DataNotLoaded" }
	end

	local stack = data.InventorySlots[inventorySlotIndex]
	if not stack then
		return { Ok = false, Error = "EmptySlot" }
	end

	local itemDef = ItemConfig.Items[stack.ItemId]
	if not itemDef or itemDef.Category ~= SLOT_ACCEPTS[equipSlotName] then
		return { Ok = false, Error = "WrongCategory" }
	end

	-- No-Stackable (armas/herramientas/utilidad) siempre equipa el
	-- stack completo (Quantity == 1, ver ItemConfig). Un objeto
	-- Stackable (no debería llegar acá salvo un futuro ItemConfig con
	-- una categoría equipable Y apilable) equipa una sola unidad,
	-- dejando el resto en la mochila.
	local equippedStack: Types.ItemStack
	if itemDef.Stackable and stack.Quantity > 1 then
		equippedStack = { ItemId = stack.ItemId, Quantity = 1 }
		stack.Quantity -= 1
	else
		equippedStack = inventoryRef.RemoveFromSlot(player, inventorySlotIndex) :: Types.ItemStack
	end

	local previouslyEquipped = data.Equipment[equipSlotName]
	data.Equipment[equipSlotName] = equippedStack

	if previouslyEquipped then
		-- El objeto que se vació del slot de equipamiento vuelve
		-- exactamente al índice que dejó libre `equippedStack`.
		if itemDef.Stackable and stack.Quantity > 0 then
			-- El slot de mochila original todavía tiene resto del
			-- mismo stack: el objeto reemplazado va al primer slot
			-- vacío distinto.
			inventoryRef.PlaceInFirstEmptySlot(player, previouslyEquipped)
		else
			data.InventorySlots[inventorySlotIndex] = previouslyEquipped
		end
	end

	log(
		string.format(
			"%s (UserId %d) equipó %s en %s",
			player.Name,
			player.UserId,
			equippedStack.ItemId,
			equipSlotName
		)
	)

	return { Ok = true, Inventory = buildInventorySnapshot(player), Equipment = buildEquipmentSnapshot(player) }
end

-- Mueve el objeto equipado en `equipSlotName` de vuelta al primer
-- slot vacío de la mochila. Falla con "InventoryFull" (sin modificar
-- nada) si no hay lugar — nunca se descarta un objeto en silencio.
function EquipmentService.UnequipToInventory(player: Player, equipSlotName: any): Types.EquipmentActionResult
	if type(equipSlotName) ~= "string" or not SLOT_ACCEPTS[equipSlotName] then
		return { Ok = false, Error = "InvalidEquipmentSlot" }
	end

	local data = playerDataRef.Get(player)
	if not data then
		return { Ok = false, Error = "DataNotLoaded" }
	end

	local stack = data.Equipment[equipSlotName]
	if not stack then
		return { Ok = false, Error = "SlotAlreadyEmpty" }
	end

	local placedIndex = inventoryRef.PlaceInFirstEmptySlot(player, stack)
	if not placedIndex then
		return { Ok = false, Error = "InventoryFull" }
	end

	data.Equipment[equipSlotName] = nil

	log(string.format("%s (UserId %d) desequipó %s", player.Name, player.UserId, stack.ItemId))

	return { Ok = true, Inventory = buildInventorySnapshot(player), Equipment = buildEquipmentSnapshot(player) }
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function EquipmentService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	remoteRef = registry.RemoteService
	playerDataRef = registry.PlayerDataService
	inventoryRef = registry.InventoryService
end

-- Envuelve un handler de RemoteFunction en pcall, mismo patrón que
-- InventoryService.safeInvoke/ToolService.safeInvoke.
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

function EquipmentService:Start()
	local snapshotRemote = remoteRef.Get("Inventory_GetSnapshot") :: RemoteFunction
	snapshotRemote.OnServerInvoke = safeInvoke(
		"Inventory_GetSnapshot",
		function(player: Player)
			return EquipmentService.GetFullState(player)
		end,
		{ Inventory = nil, Equipment = nil } :: Types.InventoryStateSnapshot
	)

	local equipRemote = remoteRef.Get("Inventory_Equip") :: RemoteFunction
	equipRemote.OnServerInvoke = safeInvoke(
		"Inventory_Equip",
		function(player: Player, inventorySlotIndex: any, equipSlotName: any)
			return EquipmentService.EquipFromInventorySlot(player, inventorySlotIndex, equipSlotName)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.EquipmentActionResult
	)

	local unequipRemote = remoteRef.Get("Inventory_Unequip") :: RemoteFunction
	unequipRemote.OnServerInvoke = safeInvoke(
		"Inventory_Unequip",
		function(player: Player, equipSlotName: any)
			return EquipmentService.UnequipToInventory(player, equipSlotName)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.EquipmentActionResult
	)

	log("EquipmentService listo.")
end

EquipmentService.SLOT_ACCEPTS = SLOT_ACCEPTS

return EquipmentService
