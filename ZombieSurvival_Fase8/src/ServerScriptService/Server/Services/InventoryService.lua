--!strict
--[[
	InventoryService.lua

	Responsabilidad: ser la única autoridad sobre el contenido de la
	mochila de cada jugador (`Types.PlayerData.InventorySlots`). Fase 7
	del proyecto.

	Server-authoritative, mismos patrones que el resto del proyecto:
	- Opera directamente sobre `PlayerDataService.Get(player)` (mismo
	  criterio que `PlayerDataService.AddResource` en la Fase 6): los
	  datos siguen viviendo en `Types.PlayerData` porque deben
	  persistir, este servicio es la capa de LÓGICA sobre esos datos
	  (agregar/mover/consumir/validar capacidad), no un almacenamiento
	  aparte.
	- `RemoteService.Get(name)` para los remotes, `CleanupService` no
	  hace falta acá (no hay estado en memoria propio de este servicio
	  que limpiar al desconectarse: todo vive en PlayerData).
	- `safeInvoke` (idéntico en espíritu al de PartyService/ToolService).
	- Todas las RemoteFunction devuelven `Types.InventoryActionResult`
	  / `Types.ConsumeItemResult`, nunca un valor suelto.

	Qué hace esta fase:
	- `AddItem(player, itemId, quantity)`: agrega objetos a la mochila
	  (apilando sobre stacks existentes si el objeto es Stackable, y
	  usando slots vacíos para el resto). NO es un remote: la
	  invocan otros servicios del servidor (ToolService tras un golpe
	  exitoso, PlayerDataService.buildDefaultData para el kit inicial)
	  porque el cliente nunca "agrega" objetos por su cuenta — de
	  dónde salen los objetos lo decide cada sistema de gameplay, este
	  servicio solo sabe CÓMO guardarlos una vez que otro sistema ya
	  decidió que corresponden.
	- `Inventory_Move` (remote): mueve/apila el contenido de un slot a
	  otro dentro de la mochila (soporta el backend de un futuro drag-
	  and-drop; esta fase no incluye esa UI, ver PROJECT_MANIFEST.md).
	- `Inventory_Consume` (remote): consume un objeto marcado
	  `Consumable` en ItemConfig (los de categoría Healing en esta
	  fase) y aplica su efecto (curar Humanoid.Health).
	- Expone además `RemoveFromSlot`/`PlaceInFirstEmptySlot`, funciones
	  internas (no remotes) que `EquipmentService` usa para mover un
	  objeto entre la mochila y un slot de equipamiento sin duplicar
	  la lógica de "encontrar/liberar un slot".

	Qué NO hace esta fase (a propósito, ver restricciones de la Fase 7):
	- No implementa peso ni UI de arrastrar-soltar (el backend de
	  "mover" ya queda listo para que una fase de UI lo consuma).
	- No conoce nada sobre zombies, construcción ni economía.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local InventoryService = {}
InventoryService.Name = "InventoryService" :: string

local debugRef: any = nil
local remoteRef: any = nil
local playerDataRef: any = nil

local function log(message: string)
	if debugRef then
		debugRef:Info("InventoryService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("InventoryService", message)
	end
end

-- ============================================================
-- Helpers internos sobre `slots` (siempre la referencia real de
-- PlayerData.InventorySlots — estas funciones MUTAN en el lugar,
-- nunca devuelven una copia, exactamente como ResourceService muta
-- sus nodos en memoria).
-- ============================================================

local function buildSnapshot(player: Player): Types.InventorySnapshot?
	local data = playerDataRef.Get(player)
	if not data then
		return nil
	end
	-- Copia superficial de primer nivel: los propios ItemStack no se
	-- clonan (son tablas pequeñas e inmutables en la práctica, se
	-- reemplazan enteras en vez de mutarse campo a campo), pero la
	-- tabla `Slots` en sí es nueva para que el cliente nunca reciba
	-- (ni pueda mutar por accidente) la referencia interna.
	local slotsCopy = table.clone(data.InventorySlots)
	return { Slots = slotsCopy, Capacity = InventoryConfig.SlotCount }
end

-- Busca el primer slot vacío. Devuelve nil si la mochila está llena.
local function findEmptySlot(slots: { Types.ItemStack? }): number?
	for index = 1, InventoryConfig.SlotCount do
		if slots[index] == nil then
			return index
		end
	end
	return nil
end

-- Agrega `quantity` unidades de `itemId` a `slots`, apilando primero
-- sobre stacks existentes (si Stackable) y usando slots vacíos para
-- el resto. Devuelve cuánto se pudo agregar realmente (puede ser
-- menor que `quantity` si la mochila se llena a mitad de camino).
local function addToSlots(slots: { Types.ItemStack? }, itemId: string, quantity: number): number
	local itemDef = ItemConfig.Items[itemId]
	if not itemDef then
		return 0
	end

	local remaining = quantity

	if itemDef.Stackable then
		for index = 1, InventoryConfig.SlotCount do
			if remaining <= 0 then
				break
			end
			local stack = slots[index]
			if stack and stack.ItemId == itemId and stack.Quantity < itemDef.MaxStack then
				local space = itemDef.MaxStack - stack.Quantity
				local toAdd = math.min(space, remaining)
				stack.Quantity += toAdd
				remaining -= toAdd
			end
		end
	end

	-- Lo que no se pudo apilar (o el objeto no apila) va a slots
	-- vacíos, en stacks de a lo sumo MaxStack cada uno.
	while remaining > 0 do
		local emptyIndex = findEmptySlot(slots)
		if not emptyIndex then
			break
		end
		local chunk = math.min(remaining, itemDef.MaxStack)
		slots[emptyIndex] = { ItemId = itemId, Quantity = chunk }
		remaining -= chunk
	end

	return quantity - remaining
end

-- ============================================================
-- API pública
-- ============================================================

-- Ver nota arriba: NO es un remote, la llaman otros servicios del
-- servidor. Devuelve Types.InventoryActionResult igual que si fuera
-- un remote, para que el llamador pueda distinguir éxito total,
-- parcial (mochila se llenó a mitad de camino) o fallo, sin tener que
-- inventar su propio contrato de retorno.
function InventoryService.AddItem(player: Player, itemId: string, quantity: number): Types.InventoryActionResult
	if type(quantity) ~= "number" or quantity <= 0 or quantity ~= quantity then
		return { Ok = false, Error = "InvalidQuantity" }
	end

	if not ItemConfig.Items[itemId] then
		return { Ok = false, Error = "InvalidItem" }
	end

	local data = playerDataRef.Get(player)
	if not data then
		return { Ok = false, Error = "DataNotLoaded" }
	end

	local added = addToSlots(data.InventorySlots, itemId, quantity)
	if added <= 0 then
		return { Ok = false, Error = "InventoryFull" }
	end

	if added < quantity and debugRef then
		debugRef:Warn(
			"InventoryService",
			string.format(
				"%s (UserId %d): mochila llena, se descartaron %d de %s.",
				player.Name,
				player.UserId,
				quantity - added,
				itemId
			)
		)
	end

	return { Ok = true, Inventory = buildSnapshot(player) }
end

-- Mueve el contenido de `fromIndex` a `toIndex`. Si `toIndex` está
-- vacío, simplemente mueve. Si tiene un stack del MISMO ItemId y
-- espacio (Stackable), apila lo que entre y deja el resto en
-- `fromIndex`. Si tiene un objeto DISTINTO, los dos stacks
-- intercambian de slot (swap) — comportamiento estándar de mochila
-- estilo Minecraft/inventarios de supervivencia, y es lo que un
-- futuro drag-and-drop esperaría de este backend.
function InventoryService.MoveItem(player: Player, fromIndex: any, toIndex: any): Types.InventoryActionResult
	if type(fromIndex) ~= "number" or type(toIndex) ~= "number" then
		return { Ok = false, Error = "InvalidSlot" }
	end
	if fromIndex < 1 or fromIndex > InventoryConfig.SlotCount or toIndex < 1 or toIndex > InventoryConfig.SlotCount then
		return { Ok = false, Error = "SlotOutOfRange" }
	end
	if fromIndex == toIndex then
		return { Ok = false, Error = "SameSlot" }
	end

	local data = playerDataRef.Get(player)
	if not data then
		return { Ok = false, Error = "DataNotLoaded" }
	end

	local slots = data.InventorySlots
	local fromStack = slots[fromIndex]
	if not fromStack then
		return { Ok = false, Error = "EmptySlot" }
	end

	local toStack = slots[toIndex]
	if toStack == nil then
		slots[toIndex] = fromStack
		slots[fromIndex] = nil
	elseif toStack.ItemId == fromStack.ItemId then
		local itemDef = ItemConfig.Items[fromStack.ItemId]
		if itemDef and itemDef.Stackable and toStack.Quantity < itemDef.MaxStack then
			local space = itemDef.MaxStack - toStack.Quantity
			local toMove = math.min(space, fromStack.Quantity)
			toStack.Quantity += toMove
			fromStack.Quantity -= toMove
			if fromStack.Quantity <= 0 then
				slots[fromIndex] = nil
			end
		else
			-- No apila (no-Stackable o el destino ya está lleno):
			-- se comporta como swap, igual que un objeto distinto.
			slots[fromIndex] = toStack
			slots[toIndex] = fromStack
		end
	else
		slots[fromIndex] = toStack
		slots[toIndex] = fromStack
	end

	log(string.format("%s (UserId %d) movió slot %d -> %d", player.Name, player.UserId, fromIndex, toIndex))

	return { Ok = true, Inventory = buildSnapshot(player) }
end

-- Consume el objeto de `slotIndex` si está marcado `Consumable` en
-- ItemConfig. Fase 7: solo objetos de categoría Healing lo son;
-- aplica `HealAmount` al Humanoid del jugador, topado en
-- Humanoid.MaxHealth (nunca "sobre-cura").
function InventoryService.ConsumeItem(player: Player, slotIndex: any): Types.ConsumeItemResult
	if type(slotIndex) ~= "number" or slotIndex < 1 or slotIndex > InventoryConfig.SlotCount then
		return { Ok = false, Error = "SlotOutOfRange" }
	end

	local data = playerDataRef.Get(player)
	if not data then
		return { Ok = false, Error = "DataNotLoaded" }
	end

	local stack = data.InventorySlots[slotIndex]
	if not stack then
		return { Ok = false, Error = "EmptySlot" }
	end

	local itemDef = ItemConfig.Items[stack.ItemId]
	if not itemDef or not itemDef.Consumable then
		return { Ok = false, Error = "NotConsumable" }
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return { Ok = false, Error = "NoCharacter" }
	end

	if humanoid.Health >= humanoid.MaxHealth then
		return { Ok = false, Error = "FullHealth" }
	end

	local healAmount = itemDef.HealAmount or 0
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healAmount)
	local healed = humanoid.Health - before

	stack.Quantity -= 1
	if stack.Quantity <= 0 then
		data.InventorySlots[slotIndex] = nil
	end

	log(
		string.format(
			"%s (UserId %d) consumió %s: +%d vida",
			player.Name,
			player.UserId,
			stack.ItemId,
			healed
		)
	)

	return { Ok = true, Inventory = buildSnapshot(player), Healed = healed }
end

function InventoryService.GetSnapshot(player: Player): Types.InventorySnapshot?
	return buildSnapshot(player)
end

-- ============================================================
-- API interna para EquipmentService (NO remotes)
-- ============================================================

-- Saca el stack completo de `slotIndex` y lo devuelve, dejando el
-- slot vacío. Usado por EquipmentService al equipar (el objeto se
-- muta de "vive en la mochila" a "vive en Equipment").
function InventoryService.RemoveFromSlot(player: Player, slotIndex: number): Types.ItemStack?
	local data = playerDataRef.Get(player)
	if not data then
		return nil
	end
	local stack = data.InventorySlots[slotIndex]
	data.InventorySlots[slotIndex] = nil
	return stack
end

-- Coloca `stack` en el primer slot vacío disponible. Usado por
-- EquipmentService al desequipar. Devuelve el índice de slot usado,
-- o nil si la mochila está llena (el llamador debe revertir la
-- desequipación en ese caso, ver EquipmentService.UnequipToInventory).
function InventoryService.PlaceInFirstEmptySlot(player: Player, stack: Types.ItemStack): number?
	local data = playerDataRef.Get(player)
	if not data then
		return nil
	end
	local index = findEmptySlot(data.InventorySlots)
	if not index then
		return nil
	end
	data.InventorySlots[index] = stack
	return index
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function InventoryService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	remoteRef = registry.RemoteService
	playerDataRef = registry.PlayerDataService
end

-- Envuelve un handler de RemoteFunction en pcall, mismo patrón que
-- ToolService.safeInvoke.
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

function InventoryService:Start()
	local moveRemote = remoteRef.Get("Inventory_Move") :: RemoteFunction
	moveRemote.OnServerInvoke = safeInvoke(
		"Inventory_Move",
		function(player: Player, fromIndex: any, toIndex: any)
			return InventoryService.MoveItem(player, fromIndex, toIndex)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.InventoryActionResult
	)

	local consumeRemote = remoteRef.Get("Inventory_Consume") :: RemoteFunction
	consumeRemote.OnServerInvoke = safeInvoke(
		"Inventory_Consume",
		function(player: Player, slotIndex: any)
			return InventoryService.ConsumeItem(player, slotIndex)
		end,
		{ Ok = false, Error = "InternalError" } :: Types.ConsumeItemResult
	)

	log("InventoryService listo.")
end

return InventoryService
