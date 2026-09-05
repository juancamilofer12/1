--!strict
--[[
	Types.lua

	Contratos de tipos Luau compartidos entre servidor y cliente.
	Este módulo NO contiene lógica, solo definiciones `export type`.
	Cualquier módulo que necesite estos tipos debe hacer:
		local Types = require(ReplicatedStorage.Shared.Types)
		local x: Types.PlayerData = ...
]]

local Types = {}

-- ============================================================
-- Servicios (contrato genérico que todo servicio del servidor
-- debe cumplir para poder ser cargado por el ServiceLoader)
-- ============================================================

export type ServiceRegistry = { [string]: Service }

export type Service = {
	Name: string,
	-- Init: se llama una sola vez, en orden de dependencia.
	-- Debe usarse solo para preparar estado interno, NUNCA para
	-- empezar a escuchar eventos de jugadores.
	Init: (self: Service, registry: ServiceRegistry) -> (),
	-- Start: se llama una sola vez, después de que TODOS los
	-- servicios completaron Init. Aquí sí se conectan eventos.
	Start: (self: Service) -> (),
}

-- ============================================================
-- IDs comunes (declarados temprano porque tanto Match como Party
-- los usan)
-- ============================================================

export type PartyId = string

-- Fase 7: `ItemStack` y `EquipmentSlotName` se declaran temprano
-- (mismo criterio que PartyId) porque Types.PlayerData los usa más
-- abajo, antes de que la sección "Sistema de Armas, Combate e
-- Inventario" (al final del archivo) los desarrolle en detalle.
export type ItemStack = {
	ItemId: string,
	Quantity: number,
}

export type EquipmentSlotName = "PrimaryWeapon" | "SecondaryWeapon" | "Tool" | "Utility" | "Healing"

-- ============================================================
-- Estado de partida (Match)
-- ============================================================

export type MatchPhase = "Lobby" | "Countdown" | "Preparation" | "InProgress" | "Ending" | "GameOver"

-- Fase 3: una Match ahora nace de una Party puntual (Party -> Match)
-- en vez de ser un singleton por servidor. `Id` se mantiene con ese
-- nombre (y no `MatchId`) para no romper el contrato ya usado por la
-- Fase 1; `PartyId`, `Round` y `TimeRemaining` son los campos nuevos
-- que pide la Fase 3.
export type MatchState = {
	Id: string,
	PartyId: PartyId,
	Phase: MatchPhase,
	PhaseStartedAt: number,
	-- Ronda actual. Sin significado de gameplay todavía (no hay
	-- oleadas de zombies en esta fase): queda preparado el campo
	-- para que fases futuras lo incrementen.
	Round: number,
	-- Segundos restantes de la fase actual. Solo tiene un valor
	-- distinto de 0 durante Countdown en esta fase; se deja el campo
	-- genérico para que Preparation/Ending puedan usarlo a futuro
	-- sin cambiar el contrato.
	TimeRemaining: number,
	Players: { [number]: boolean }, -- UserId -> sigue en la partida
}

-- ============================================================
-- Datos de jugador (server-authoritative)
-- ============================================================

export type PlayerData = {
	UserId: number,
	Loaded: boolean,
	SessionStart: number,
	DataVersion: number,
	-- Fase 7: reemplaza el `Inventory` temporal (ResourceType ->
	-- cantidad) de la Fase 6 por el sistema real de mochila con
	-- slots. `InventorySlots` tiene longitud fija
	-- (InventoryConfig.SlotCount); una entrada `nil` es un slot
	-- vacío. `Equipment` son los 5 slots de equipamiento
	-- (EquipmentSlot.lua), independientes de la mochila. Ver
	-- InventoryService / EquipmentService y la migración en
	-- PlayerDataService.loadData para saves de antes de esta fase.
	InventorySlots: { ItemStack? },
	Equipment: { [EquipmentSlotName]: ItemStack? },
}

-- ============================================================
-- Logging
-- ============================================================

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

-- ============================================================
-- Cleanup
-- ============================================================

export type CleanupTask = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () }

-- ============================================================
-- Sistema de Party (Fase 2 - Lobby)
-- ============================================================

export type PartyMemberInfo = {
	UserId: number,
	Name: string,
}

-- Snapshot de solo lectura de una party pensado para replicarse al
-- cliente vía remotes. No expone la tabla interna mutable del
-- servidor (PartyService la reconstruye en cada cambio).
export type PartyState = {
	PartyId: PartyId,
	Leader: number, -- UserId del líder actual
	Members: { PartyMemberInfo }, -- orden = orden de ingreso
	MaximumMembers: number,
}

-- Contrato de retorno uniforme para las RemoteFunctions de Party.
-- El cliente SIEMPRE recibe esta forma, nunca un valor suelto,
-- para poder distinguir éxito/fracaso sin adivinar por tipo.
export type PartyActionResult = {
	Ok: boolean,
	Error: string?,
	Party: PartyState?,
}

-- ============================================================
-- Match Service + Countdown (Fase 3)
-- ============================================================

-- Contrato de retorno uniforme para el RemoteFunction "Match_Start".
-- Igual filosofía que PartyActionResult: el cliente nunca adivina
-- éxito/fracaso por la forma del valor devuelto.
export type MatchActionResult = {
	Ok: boolean,
	Error: string?,
	Match: MatchState?,
}

-- Payload liviano que se empuja en cada tick de countdown. Se separa
-- de MatchState (que se empuja solo en cada cambio de fase) para no
-- replicar el snapshot completo una vez por segundo.
export type MatchCountdownUpdate = {
	PartyId: PartyId,
	TimeRemaining: number,
}

-- ============================================================
-- Sistema de Recursos (Fase 5)
-- ============================================================

-- Mismos valores que Shared/Enums/ResourceType.lua, repetidos acá
-- como unión de literales para que el chequeo de tipos --!strict
-- atrape strings inválidos en tiempo de compilación (el enum en sí
-- es una tabla runtime, no aporta ese chequeo por sí solo).
export type ResourceType = "Wood" | "Stone" | "Metal" | "Scrap"

export type ResourceNodeState = "Available" | "Depleted"

-- Snapshot de solo lectura de un nodo de recurso. No expone el
-- Instance ni el thread de respawn interno de ResourceService.
export type ResourceNodeInfo = {
	NodeId: string,
	ResourceType: ResourceType,
	Amount: number,
	MaxAmount: number,
	State: ResourceNodeState,
}

-- Contrato de retorno de ResourceService.ExtractResource. Fase 6
-- (sistema de herramientas) es quien va a llamar a esta función; el
-- contrato ya queda definido acá para que esa fase no tenga que
-- adivinar la forma del resultado.
export type ResourceExtractionResult = {
	Ok: boolean,
	Error: string?,
	Extracted: number?,
	Remaining: number?,
	State: ResourceNodeState?,
}

-- ============================================================
-- Sistema de Herramientas (Fase 6)
-- ============================================================

-- Mismos valores que Shared/Enums/ToolType.lua, repetidos acá como
-- unión de literales por el mismo motivo que ResourceType arriba.
export type ToolId = "WoodcutterAxe" | "Pickaxe"

-- `ToolEquipResult` (contrato de "Tool_Equip") existió en la Fase 6 y
-- se retiró en la Fase 7: equipar una herramienta ahora es un caso
-- más de "Inventory_Equip" (ver EquipmentActionResult más abajo).

-- Contrato de retorno uniforme del RemoteFunction "Tool_RequestHarvest".
-- Incluye el ResourceType extraído para que el cliente pueda, por
-- ejemplo, mostrar "+1 Madera" sin tener que consultar el nodo aparte.
export type HarvestResult = {
	Ok: boolean,
	Error: string?,
	NodeId: string?,
	ResourceType: ResourceType?,
	Extracted: number?,
	Remaining: number?,
	State: ResourceNodeState?,
}

-- ============================================================
-- Sistema de Armas, Combate e Inventario (Fase 7)
-- ============================================================

-- Mismos valores que Shared/Enums/WeaponType.lua / WeaponKind.lua,
-- repetidos acá como unión de literales por el mismo motivo que
-- ResourceType/ToolId más arriba.
export type WeaponId = "Machete" | "BaseballBat" | "Pistol" | "Rifle"
export type WeaponKind = "Melee" | "Firearm"

-- Snapshot de solo lectura de la mochila de un jugador, pensado para
-- replicarse al cliente. `Slots` tiene siempre longitud
-- InventoryConfig.SlotCount; una entrada `nil` es un slot vacío.
export type InventorySnapshot = {
	Slots: { ItemStack? },
	Capacity: number,
}

-- Snapshot de solo lectura de los 5 slots de equipamiento. `nil` en
-- una clave significa ese slot vacío.
export type EquipmentSnapshot = { [EquipmentSlotName]: ItemStack? }

-- Contrato de retorno uniforme de las RemoteFunction de inventario
-- (Inventory_Move, Inventory_Consume). Misma filosofía que
-- PartyActionResult: el cliente nunca adivina éxito/fracaso por la
-- forma del valor devuelto. Se devuelve el snapshot completo de la
-- mochila (no un delta) para que el cliente actualice su UI sin
-- tener que reconstruir el estado a mano.
export type InventoryActionResult = {
	Ok: boolean,
	Error: string?,
	Inventory: InventorySnapshot?,
}

-- Contrato de retorno de InventoryService.ConsumeItem
-- (Inventory_Consume). `Healed` es cuánta vida efectivamente restauró
-- (puede ser menor que ItemConfig.Items[id].HealAmount si el jugador
-- ya estaba cerca de Humanoid.MaxHealth).
export type ConsumeItemResult = {
	Ok: boolean,
	Error: string?,
	Inventory: InventorySnapshot?,
	Healed: number?,
}

-- Contrato de retorno uniforme de las RemoteFunction de equipamiento
-- (Inventory_Equip, Inventory_Unequip). Devuelve ambos snapshots
-- (mochila + equipamiento) en la misma respuesta porque equipar/
-- desequipar siempre mueve un objeto entre los dos, así el cliente
-- actualiza las dos partes de su UI con un solo round-trip.
export type EquipmentActionResult = {
	Ok: boolean,
	Error: string?,
	Inventory: InventorySnapshot?,
	Equipment: EquipmentSnapshot?,
}

-- Contrato de retorno de "Inventory_GetSnapshot": el cliente lo pide
-- una vez al conectar (Fase 7 no empuja el estado de mochila/equipo
-- por su cuenta, ver nota en InventoryService/EquipmentService) para
-- saber qué tiene antes de poder pedir un Equip/Move/Consume con
-- sentido. Después de esa carga inicial, cada acción devuelve su
-- propio snapshot actualizado (ver InventoryActionResult/
-- EquipmentActionResult) y el cliente no necesita volver a pedir este.
export type InventoryStateSnapshot = {
	Inventory: InventorySnapshot?,
	Equipment: EquipmentSnapshot?,
}

-- Estado de munición de un arma de fuego actualmente equipada en un
-- slot puntual. No existe para armas Melee (WeaponService solo lo
-- crea para WeaponKind.Firearm, ver WeaponService.getOrInitAmmo).
export type WeaponAmmoState = {
	WeaponId: WeaponId,
	CurrentMagazine: number,
	ReserveAmmo: number,
	Reloading: boolean,
}

-- Contrato de retorno uniforme del RemoteFunction "Weapon_RequestReload".
export type ReloadResult = {
	Ok: boolean,
	Error: string?,
	Ammo: WeaponAmmoState?,
}

-- Contrato de retorno uniforme de "Combat_MeleeAttack" y
-- "Combat_RangedAttack". `Ammo` solo viene poblado en la rama
-- Firearm (para que el cliente pueda refrescar su contador de balas
-- sin un round-trip aparte); queda `nil` en golpes Melee.
export type CombatActionResult = {
	Ok: boolean,
	Error: string?,
	DamageDealt: number?,
	TargetRemainingHealth: number?,
	Ammo: WeaponAmmoState?,
}

-- ============================================================
-- Sistema de Zombies, IA, Pathfinding y Rondas (Fase 8)
-- ============================================================

-- Mismos valores que Shared/Enums/ZombieType.lua, repetidos acá como
-- unión de literales por el mismo motivo que WeaponId/ToolId más
-- arriba.
export type ZombieTypeId =
	"Normal"
	| "Runner"
	| "Brute"
	| "Giant"
	| "Explosive"
	| "Toxic"
	| "Climber"
	| "Stealth"
	| "Nightmare"

-- Mismos valores que Shared/Enums/ZombieAIState.lua.
export type ZombieAIStateId = "Idle" | "Searching" | "Chasing" | "Attacking" | "Dead"

-- Mismos valores que Shared/Enums/RoundPhase.lua.
export type RoundPhaseId = "Preparation" | "Wave" | "Intermission"

export type ZombieId = string

-- Snapshot de solo lectura de un zombie administrado por
-- ZombieService. No expone el Model ni el Humanoid directamente para
-- que el llamador no pueda mutarlos por fuera de la API del
-- servicio (mismo criterio que ResourceNodeInfo con NodeInternal).
export type ZombieInfo = {
	ZombieId: ZombieId,
	ZombieType: ZombieTypeId,
	Health: number,
	MaxHealth: number,
}

-- Contrato de retorno de ZombieService.SpawnZombie. `Model` sí se
-- expone acá (a diferencia de ZombieInfo): quien pide spawnear un
-- zombie (WaveService) necesita la instancia real para, por ejemplo,
-- loguear su posición o que ZombieAIService la reciba vía el Signal
-- ZombieSpawned.
export type ZombieSpawnResult = {
	Ok: boolean,
	Error: string?,
	ZombieId: ZombieId?,
	Model: Model?,
}

-- Snapshot de solo lectura del estado de rondas de una Match
-- puntual (indexado por PartyId, igual que Types.MatchState).
-- Pensado para que una futura fase de UI/HUD lo consuma sin tener
-- que reconstruirlo a mano; esta fase no lo replica por remote
-- todavía (ver WaveService.RoundStateChanged, mismo criterio que
-- ResourceService.NodeStateChanged en la Fase 5: el Signal queda
-- listo, nada lo conecta a un remote hasta que haga falta).
export type RoundState = {
	PartyId: PartyId,
	Round: number,
	Phase: RoundPhaseId,
	PhaseStartedAt: number,
	TimeRemaining: number,
	ZombiesRemaining: number,
}

return Types
