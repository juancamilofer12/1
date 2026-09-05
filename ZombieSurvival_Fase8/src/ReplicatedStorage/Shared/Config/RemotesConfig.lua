--!strict
--[[
	RemotesConfig.lua

	Única fuente de verdad sobre qué RemoteEvents y RemoteFunctions
	existen en el juego. RemoteService (servidor) lee esta lista para
	CREAR las instancias reales; NetClient (cliente) lee la misma
	lista para ENCONTRARLAS. Ningún otro módulo debe crear remotes
	manualmente ni usar strings sueltos con nombres de remote.

	Para esta fase base no hay remotes de gameplay todavía (zombies,
	armas, etc.). Solo se define la infraestructura y un remote de
	ejemplo mínimo para verificar que el sistema funciona de punta
	a punta.

	FolderName es el nombre de la carpeta bajo ReplicatedStorage
	donde viven todas las instancias de remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

export type RemoteKind = "RemoteEvent" | "RemoteFunction"

export type RemoteDefinition = {
	Name: string,
	Kind: RemoteKind,
}

local RemotesConfig = {
	FolderName = "Net",

	Definitions = {
		-- Ejemplo mínimo para validar el pipeline cliente-servidor.
		{ Name = "Ping", Kind = "RemoteFunction" } :: RemoteDefinition,

		-- Fase 2: sistema de grupos (Party) del lobby.
		-- Las acciones son RemoteFunction porque el cliente necesita
		-- saber de inmediato si su acción tuvo éxito o por qué falló
		-- (ver Types.PartyActionResult). "Party_Updated" es el único
		-- RemoteEvent: el servidor lo usa para empujar el estado
		-- actualizado (o nil si el jugador ya no está en ninguna
		-- party) a cada cliente afectado.
		{ Name = "Party_Create", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Party_Join", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Party_Leave", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Party_Kick", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Party_TransferLeadership", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Party_Updated", Kind = "RemoteEvent" } :: RemoteDefinition,

		-- Fase 3: MatchService + Countdown. "Match_Start" es
		-- RemoteFunction porque el líder necesita saber de inmediato
		-- si el servidor aceptó el pedido (ver Types.MatchActionResult).
		-- Los otros dos son RemoteEvent porque son siempre push del
		-- servidor hacia los miembros de la partida, nunca al revés:
		-- "Match_CountdownUpdate" es el tick liviano del countdown
		-- (Types.MatchCountdownUpdate) y "Match_StateUpdated" es el
		-- snapshot completo (Types.MatchState, o nil si la partida
		-- ya no existe) que se empuja en cada cambio de fase.
		{ Name = "Match_Start", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Match_CountdownUpdate", Kind = "RemoteEvent" } :: RemoteDefinition,
		{ Name = "Match_StateUpdated", Kind = "RemoteEvent" } :: RemoteDefinition,

		-- Fase 6: sistema de herramientas. "Tool_RequestHarvest" es
		-- RemoteFunction porque el cliente necesita saber de inmediato
		-- si el golpe tuvo éxito o por qué falló (ver Types.HarvestResult).
		-- No hay un remote de "push" del servidor acá: el estado de un
		-- nodo ya se ve por replicación normal de Attributes (Fase 5).
		--
		-- "Tool_Equip" (equipar SIN gatear posesión) existió en la
		-- Fase 6 y se ELIMINA en la Fase 7: ahora que existe inventario
		-- real, equipar una herramienta es un caso más de
		-- "Inventory_Equip" (mover un objeto de la mochila al slot
		-- EquipmentSlot.Tool) — ver PROJECT_MANIFEST.md Fase 7 y
		-- ToolService, que ahora lee la herramienta equipada desde
		-- EquipmentService en vez de mantener su propia tabla.
		{ Name = "Tool_RequestHarvest", Kind = "RemoteFunction" } :: RemoteDefinition,

		-- Fase 7: sistema de inventario/mochila. Todas RemoteFunction
		-- (mismo criterio que el resto del proyecto: el cliente
		-- necesita saber de inmediato si la acción tuvo éxito, ver
		-- Types.InventoryActionResult / ConsumeItemResult /
		-- EquipmentActionResult). No hay remote de "push": a diferencia
		-- de Party, nada fuerza al servidor a notificar a otros
		-- clientes sobre la mochila de un jugador (es privada), así
		-- que el snapshot devuelto en cada respuesta es suficiente
		-- para que el propio cliente actualice su UI. "Inventory_
		-- GetSnapshot" es la excepción de solo-lectura: se pide una
		-- vez al conectar para tener el estado inicial (ver
		-- Types.InventoryStateSnapshot).
		{ Name = "Inventory_GetSnapshot", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Inventory_Move", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Inventory_Consume", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Inventory_Equip", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Inventory_Unequip", Kind = "RemoteFunction" } :: RemoteDefinition,

		-- Fase 7: sistema de armas y combate. "Weapon_RequestReload"
		-- y las dos de combate son RemoteFunction por el mismo
		-- criterio de siempre (Types.ReloadResult / CombatActionResult).
		{ Name = "Weapon_RequestReload", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Combat_MeleeAttack", Kind = "RemoteFunction" } :: RemoteDefinition,
		{ Name = "Combat_RangedAttack", Kind = "RemoteFunction" } :: RemoteDefinition,
	} :: { RemoteDefinition },
}

return TableUtils.DeepFreeze(RemotesConfig)
