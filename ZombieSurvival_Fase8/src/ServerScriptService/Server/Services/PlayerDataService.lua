--!strict
--[[
	PlayerDataService.lua

	Responsabilidad: cargar y guardar los datos de cada jugador de
	forma autoritativa (el cliente nunca escribe estos datos
	directamente). Usa DataStoreService con reintentos ante errores
	transitorios.

	El "esquema" de datos sigue siendo mínimo (ver
	PlayerDataConfig.DefaultTemplate / Types.PlayerData): identidad,
	metadatos de sesión y, desde la Fase 7, `InventorySlots`/
	`Equipment` (la mochila real — ver InventoryService/
	EquipmentService, que son quienes MANIPULAN estos campos; este
	servicio solo los carga/guarda/inicializa, igual que ya hacía con
	el `Inventory` temporal de la Fase 6). Fases futuras extenderán la
	plantilla con más campos de gameplay (stats, economía, etc.) sin
	tener que tocar la lógica de carga/guardado de este servicio.

	Flujo:
	  PlayerAdded -> LoadData (con reintentos) -> se guarda en caché
	                 en memoria (`profiles`)
	  PlayerRemoving -> SaveData -> se limpia la caché
	  BindToClose -> se intenta guardar todo lo que siga en caché
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataConfig = require(ReplicatedStorage.Shared.Config.PlayerDataConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService" :: string

local dataStore = DataStoreService:GetDataStore(PlayerDataConfig.DataStoreName)

local profiles: { [Player]: Types.PlayerData } = {}

local debugRef: any = nil
local cleanupRef: any = nil

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

-- Intenta una operación de DataStore con reintentos y backoff simple.
-- Retorna (ok: boolean, result: any)
local function withRetries(operation: () -> any): (boolean, any)
	local attempts = 0
	local lastError: any = nil

	while attempts <= PlayerDataConfig.MaxRetries do
		attempts += 1
		local ok, result = pcall(operation)
		if ok then
			return true, result
		end
		lastError = result
		if attempts <= PlayerDataConfig.MaxRetries then
			task.wait(PlayerDataConfig.RetryBackoffSeconds)
		end
	end

	return false, lastError
end

-- Coloca `stack` en el primer slot vacío de `slots`, o lo apila sobre
-- un slot existente del mismo ItemId si el objeto es Stackable y
-- queda lugar. Duplica una porción mínima de la lógica de
-- "colocación" que InventoryService también implementa para su propio
-- uso (Inventory_Move / AddItem) en vez de requerir ese servicio acá:
-- PlayerDataService se carga ANTES que InventoryService en
-- ServiceLoader (InventoryService depende de PlayerDataService, no al
-- revés), así que requerirlo crearía un ciclo. Esta copia es
-- deliberadamente simple (sin partir un stack que no entra completo)
-- porque solo se usa una vez, al construir el kit inicial de un
-- jugador nuevo — nunca en el camino caliente de gameplay.
local function placeStarterItem(slots: { Types.ItemStack? }, itemId: string, quantity: number)
	local itemDef = ItemConfig.Items[itemId]
	if not itemDef then
		return
	end

	-- IMPORTANTE: `slots` es sparse (un slot vacío es, literalmente,
	-- una clave ausente de la tabla, no un valor `nil` "puesto" en
	-- ella) — ni `#slots` ni `ipairs(slots)` son confiables acá (se
	-- detienen/miden mal en el primer hueco). Se recorre siempre por
	-- rango explícito 1..InventoryConfig.SlotCount, igual que hace
	-- InventoryService con la mochila real.
	if itemDef.Stackable then
		for index = 1, InventoryConfig.SlotCount do
			local stack = slots[index]
			if stack and stack.ItemId == itemId and stack.Quantity + quantity <= itemDef.MaxStack then
				stack.Quantity += quantity
				return
			end
		end
	end

	for index = 1, InventoryConfig.SlotCount do
		if slots[index] == nil then
			slots[index] = { ItemId = itemId, Quantity = quantity }
			return
		end
	end
	-- Mochila llena de más StarterItems que slots: no debería pasar
	-- con la configuración actual (InventoryConfig.SlotCount = 10,
	-- 2 StarterItems), se ignora en silencio en vez de reventar.
end

local function buildDefaultData(userId: number): Types.PlayerData
	local data = TableUtils.DeepCopy(PlayerDataConfig.DefaultTemplate) :: any
	data.UserId = userId
	data.Loaded = true
	data.SessionStart = os.time()

	-- Fase 7: arma los InventoryConfig.SlotCount slots vacíos y coloca
	-- el kit inicial (InventoryConfig.StarterItems) en ellos. Se hace
	-- acá (no en PlayerDataConfig.DefaultTemplate) para no acoplar el
	-- esquema de datos al tamaño/contenido del kit. `slots` arranca
	-- como tabla vacía a propósito (ver nota de placeStarterItem sobre
	-- por qué NO se "pre-llena" de nils: asignar `nil` a una clave que
	-- no existe es un no-op en Lua, así que hacerlo no cambiaría nada
	-- — el tamaño real de la mochila lo define InventoryConfig.SlotCount,
	-- no el contenido de esta tabla).
	local slots: { Types.ItemStack? } = {}
	for _, starter in ipairs(InventoryConfig.StarterItems) do
		placeStarterItem(slots, starter.ItemId, starter.Quantity)
	end
	data.InventorySlots = slots
	data.Equipment = {}

	return data :: Types.PlayerData
end

-- Migración Fase 7: convierte el `Inventory` temporal de la Fase 6
-- (ResourceType -> cantidad) a InventorySlots real, para no perder
-- los recursos que un jugador ya tenía guardados antes de esta fase.
-- Cada tipo de recurso con cantidad > 0 se reparte en tantos slots
-- como haga falta según su MaxStack (ver ItemConfig). Si la mochila
-- se llena antes de terminar de migrar todo, el resto se descarta y
-- se loguea — mismo criterio pragmático que el resto del proyecto
-- ante datos viejos que ya no encajan del todo en un esquema nuevo.
local function migrateLegacyInventory(savedData: any): { Types.ItemStack? }
	local slots: { Types.ItemStack? } = {}

	local legacyInventory = savedData.Inventory :: { [string]: number }?
	if legacyInventory then
		for resourceType, amount in pairs(legacyInventory) do
			local remaining = amount
			local itemDef = ItemConfig.Items[resourceType]
			local maxStack = (itemDef and itemDef.MaxStack) or amount
			while remaining > 0 do
				local chunk = math.min(remaining, maxStack)
				-- Ver nota en placeStarterItem: rango explícito, no
				-- `#slots`/`ipairs` (tabla sparse).
				local placedSlot = nil
				for index = 1, InventoryConfig.SlotCount do
					if slots[index] == nil then
						placedSlot = index
						break
					end
				end
				if not placedSlot then
					if debugRef then
						debugRef:Warn(
							"PlayerDataService",
							string.format(
								"Migración Fase 7: mochila llena, se descartan %d de %s.",
								remaining,
								resourceType
							)
						)
					end
					break
				end
				slots[placedSlot] = { ItemId = resourceType, Quantity = chunk }
				remaining -= chunk
			end
		end
	end

	return slots
end

local function loadData(player: Player)
	local ok, result = withRetries(function()
		return dataStore:GetAsync(keyFor(player.UserId))
	end)

	if not player:IsDescendantOf(Players) then
		-- El jugador se fue mientras cargaba; no seguir.
		return
	end

	if not ok then
		if debugRef then
			debugRef:Error(
				"PlayerDataService",
				string.format("Falló GetAsync para %s: %s", player.Name, tostring(result))
			)
		end
		-- Fallback server-authoritative: se le da una sesión con
		-- datos por defecto para no bloquear al jugador, pero se
		-- marca igual para que futuras fases puedan decidir cómo
		-- manejar este caso (p. ej. bloquear guardado hasta reintentar).
		profiles[player] = buildDefaultData(player.UserId)
		return
	end

	local savedData = result :: any
	if savedData == nil then
		profiles[player] = buildDefaultData(player.UserId)
	else
		-- Migración Fase 7: datos guardados antes de que
		-- `InventorySlots`/`Equipment` existieran (Fase 6 y anteriores,
		-- que tenían `Inventory` en su lugar, o ninguno de los dos si
		-- son de antes de la Fase 6) se migran acá. En vez de un
		-- sistema de versionado completo (fuera de alcance de esta
		-- fase), se detecta por ausencia de `InventorySlots` y se
		-- rellena una sola vez.
		if savedData.InventorySlots == nil then
			savedData.InventorySlots = migrateLegacyInventory(savedData)
			savedData.Inventory = nil -- campo viejo, ya no forma parte del esquema
		end
		if savedData.Equipment == nil then
			savedData.Equipment = {}
		end
		profiles[player] = savedData :: Types.PlayerData
	end

	if debugRef then
		debugRef:Info("PlayerDataService", "Datos cargados para " .. player.Name)
	end
end

local function saveData(player: Player)
	local data = profiles[player]
	if not data then
		return
	end

	local ok, err = withRetries(function()
		return dataStore:SetAsync(keyFor(player.UserId), data)
	end)

	if not ok and debugRef then
		debugRef:Error(
			"PlayerDataService",
			string.format("Falló SetAsync para %s: %s", player.Name, tostring(err))
		)
	elseif ok and debugRef then
		debugRef:Info("PlayerDataService", "Datos guardados para " .. player.Name)
	end
end

function PlayerDataService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
end

function PlayerDataService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	globalTrove:Add(Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(loadData, player)
	end))

	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		saveData(player)
		profiles[player] = nil
	end))

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end)
end

-- Retorna los datos del jugador si ya terminaron de cargar, o nil si
-- todavía está cargando o no se encontró (el llamador debe manejar
-- el caso nil, NUNCA asumir que los datos ya están listos).
function PlayerDataService.Get(player: Player): Types.PlayerData?
	return profiles[player]
end

-- Fase 6 tenía acá `PlayerDataService.AddResource`, que sumaba
-- directo al `Inventory` temporal. Fase 7 la retira: agregar objetos
-- ahora es responsabilidad de `InventoryService.AddItem` (que sabe de
-- slots, stacks y capacidad); `ToolService.RequestHarvest` llama a esa
-- función en su lugar. Este servicio vuelve a ser una capa de datos
-- pura (cargar/guardar/inicializar), sin lógica de "qué significa"
-- cada campo de `Types.PlayerData`.

return PlayerDataService
