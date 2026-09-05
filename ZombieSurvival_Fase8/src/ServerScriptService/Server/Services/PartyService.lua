--!strict
--[[
	PartyService.lua

	Responsabilidad: administrar los grupos (Party) de 1 a 4
	jugadores que se forman en el lobby antes de iniciar una
	partida. Fase 2 del proyecto.

	Server-authoritative: toda la data de las parties vive
	únicamente acá. El cliente solo pide acciones vía remotes y
	recibe snapshots de solo lectura (Types.PartyState); nunca
	puede escribir el estado directamente.

	Esta fase (2) NO conoce el concepto de "partida" en sí: solo
	administra el grupo. Desde la Fase 3, expone el Signal
	`PartyChanged` y consulta `MatchService.IsPartyLocked` para que
	una party no pueda sumar miembros mientras está jugando una
	Match, pero la lógica de partida en sí (MatchService) sigue
	viviendo enteramente en su propio archivo.

	Patrones reutilizados de la arquitectura existente:
	- RemoteService.Get(name) para obtener las instancias de remotes
	  (nunca se crean remotes acá).
	- CleanupService.GetGlobalTrove() para la conexión de
	  Players.PlayerRemoving, igual que hace MatchService con su
	  roster.
	- DebugService para logging de eventos importantes.
	- Todas las RemoteFunction devuelven Types.PartyActionResult,
	  nunca un valor suelto, para que el cliente distinga
	  éxito/fracaso sin adivinar.

	Concurrencia: los handlers de OnServerInvoke de este servicio no
	hacen ninguna operación que ceda el hilo (no hay task.wait, no hay
	yields de ningún tipo), por lo que cada invocación de un mismo
	remote se procesa de principio a fin antes de que Luau pueda
	empezar a procesar la siguiente. Esto evita condiciones de
	carrera clásicas (dos joins simultáneos a la última silla libre,
	etc.) sin necesidad de un mutex explícito.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local PartyConfig = require(ReplicatedStorage.Shared.Config.PartyConfig)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local PartyService = {}
PartyService.Name = "PartyService" :: string

-- Representación interna de una party. NO se expone tal cual al
-- cliente: buildPartyState() la traduce a Types.PartyState.
type PartyInternal = {
	Id: string,
	Leader: number, -- UserId
	Members: { number }, -- UserIds, orden = orden de ingreso
}

local parties: { [string]: PartyInternal } = {}

-- Índice inverso para O(1): a qué party pertenece cada jugador.
-- Invariante mantenido por este servicio: un UserId aparece en, como
-- máximo, una entrada de `parties` a la vez.
local playerParty: { [number]: string } = {}

-- Rate limiting simple por jugador: último os.clock() en que se
-- procesó CUALQUIER acción de party de ese UserId.
local lastActionAt: { [number]: number } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local remoteRef: any = nil
local matchRef: any = nil

-- Fase 3: única forma en que MatchService se entera de que una party
-- cambió (nuevo/menos miembros) o fue destruida, sin que PartyService
-- necesite saber nada sobre partidas. Se dispara con los mismos
-- datos que ya se le empujan al cliente (buildPartyState), o nil
-- cuando la party deja de existir. No duplica estado: es simplemente
-- un pub/sub sobre el mismo evento que ya generaba notifyPlayer.
local PartyChanged = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("PartyService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("PartyService", message)
	end
end

-- Devuelve false (y bloquea la acción) si el jugador está actuando
-- más rápido que PartyConfig.ActionCooldownSeconds. Actualiza el
-- timestamp únicamente cuando la acción SÍ se permite.
local function checkRateLimit(userId: number): boolean
	local now = os.clock()
	local last = lastActionAt[userId]
	if last ~= nil and (now - last) < PartyConfig.ActionCooldownSeconds then
		return false
	end
	lastActionAt[userId] = now
	return true
end

-- Construye el snapshot de solo lectura que se envía al cliente.
local function buildPartyState(party: PartyInternal): Types.PartyState
	local members: { Types.PartyMemberInfo } = {}
	for _, userId in ipairs(party.Members) do
		local memberPlayer = Players:GetPlayerByUserId(userId)
		table.insert(members, {
			UserId = userId,
			Name = memberPlayer and memberPlayer.Name or "???",
		})
	end

	return {
		PartyId = party.Id,
		Leader = party.Leader,
		Members = members,
		MaximumMembers = PartyConfig.MaximumMembers,
	}
end

-- Empuja `state` (o nil si el jugador ya no está en ninguna party)
-- al cliente de ese UserId puntual, si sigue conectado.
local function notifyPlayer(userId: number, state: Types.PartyState?)
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then
		return
	end

	local ok, remote = pcall(function()
		return remoteRef.Get("Party_Updated")
	end)
	if not ok then
		logError("No se pudo obtener el remote Party_Updated: " .. tostring(remote))
		return
	end

	(remote :: RemoteEvent):FireClient(targetPlayer, state)
end

-- Notifica el estado actualizado a TODOS los miembros actuales de
-- la party (cada uno recibe el mismo snapshot).
local function broadcastParty(party: PartyInternal)
	local state = buildPartyState(party)
	for _, userId in ipairs(party.Members) do
		notifyPlayer(userId, state)
	end
	PartyChanged:Fire(party.Id, state)
end

local function destroyParty(party: PartyInternal, reason: string)
	parties[party.Id] = nil
	log(string.format("Party %s destruida (%s)", party.Id, reason))
	PartyChanged:Fire(party.Id, nil)
end

-- Quita a `userId` de `party`, reasigna liderazgo si hacía falta,
-- destruye la party si queda vacía, y notifica a todos los
-- afectados. Único punto de salida de un miembro (lo usan Leave,
-- Kick y la desconexión), para no duplicar la lógica de reasignación
-- de líder / limpieza en varios lugares.
local function removeMember(party: PartyInternal, userId: number)
	local index = table.find(party.Members, userId)
	if not index then
		-- Referencia inconsistente defensiva: no debería pasar dado
		-- el invariante de playerParty, pero no reventamos por esto.
		playerParty[userId] = nil
		return
	end

	table.remove(party.Members, index)
	playerParty[userId] = nil

	if #party.Members == 0 then
		destroyParty(party, "sin miembros restantes")
		return
	end

	if party.Leader == userId then
		-- El líder que se va cede el puesto al miembro más antiguo
		-- que quede (Members[1] tras el remove, porque el orden de
		-- la lista es orden de ingreso).
		party.Leader = party.Members[1]
		log(string.format("Nuevo líder de la party %s: UserId %d", party.Id, party.Leader))
	end

	broadcastParty(party)
end

-- ============================================================
-- API pública (llamada desde los handlers de remotes más abajo)
-- ============================================================

function PartyService.CreateParty(player: Player): Types.PartyActionResult
	local userId = player.UserId

	if not checkRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	if playerParty[userId] ~= nil then
		return { Ok = false, Error = "AlreadyInParty" }
	end

	local id = HttpService:GenerateGUID(false)
	local party: PartyInternal = {
		Id = id,
		Leader = userId,
		Members = { userId },
	}
	parties[id] = party
	playerParty[userId] = id

	log(string.format("%s (UserId %d) creó la party %s", player.Name, userId, id))

	local state = buildPartyState(party)
	notifyPlayer(userId, state)
	return { Ok = true, Party = state }
end

function PartyService.JoinParty(player: Player, partyId: any): Types.PartyActionResult
	local userId = player.UserId

	if not checkRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	if type(partyId) ~= "string" then
		return { Ok = false, Error = "InvalidPartyId" }
	end

	if playerParty[userId] ~= nil then
		return { Ok = false, Error = "AlreadyInParty" }
	end

	local party = parties[partyId]
	if not party then
		return { Ok = false, Error = "PartyNotFound" }
	end

	-- Fase 3: mientras la party esté asociada a una Match (desde
	-- Countdown en adelante), no puede sumar miembros nuevos.
	-- MatchService es la única fuente de verdad sobre ese lock;
	-- PartyService no guarda su propia copia de "está en partida".
	if matchRef and matchRef.IsPartyLocked(partyId) then
		return { Ok = false, Error = "PartyInMatch" }
	end

	if #party.Members >= PartyConfig.MaximumMembers then
		return { Ok = false, Error = "PartyFull" }
	end

	table.insert(party.Members, userId)
	playerParty[userId] = party.Id

	log(string.format("%s (UserId %d) se unió a la party %s", player.Name, userId, party.Id))

	broadcastParty(party)
	return { Ok = true, Party = buildPartyState(party) }
end

function PartyService.LeaveParty(player: Player): Types.PartyActionResult
	local userId = player.UserId

	if not checkRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	local partyId = playerParty[userId]
	if not partyId then
		return { Ok = false, Error = "NotInParty" }
	end

	local party = parties[partyId]
	if not party then
		playerParty[userId] = nil
		return { Ok = false, Error = "NotInParty" }
	end

	log(string.format("%s (UserId %d) abandonó la party %s", player.Name, userId, partyId))

	removeMember(party, userId)
	notifyPlayer(userId, nil)

	return { Ok = true, Party = nil }
end

function PartyService.KickMember(player: Player, targetUserId: any): Types.PartyActionResult
	local userId = player.UserId

	if not checkRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	if type(targetUserId) ~= "number" then
		return { Ok = false, Error = "InvalidTarget" }
	end

	local partyId = playerParty[userId]
	if not partyId then
		return { Ok = false, Error = "NotInParty" }
	end

	local party = parties[partyId]
	if not party then
		playerParty[userId] = nil
		return { Ok = false, Error = "NotInParty" }
	end

	if party.Leader ~= userId then
		return { Ok = false, Error = "NotLeader" }
	end

	if targetUserId == userId then
		return { Ok = false, Error = "CannotKickSelf" }
	end

	if playerParty[targetUserId :: number] ~= partyId then
		return { Ok = false, Error = "TargetNotInParty" }
	end

	log(
		string.format(
			"%s (UserId %d) expulsó a UserId %d de la party %s",
			player.Name,
			userId,
			targetUserId :: number,
			partyId
		)
	)

	removeMember(party, targetUserId :: number)
	notifyPlayer(targetUserId :: number, nil)

	-- La party sigue existiendo (el líder no se expulsó a sí mismo),
	-- así que siempre hay un estado válido para devolver.
	return { Ok = true, Party = buildPartyState(party) }
end

function PartyService.TransferLeadership(player: Player, targetUserId: any): Types.PartyActionResult
	local userId = player.UserId

	if not checkRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	if type(targetUserId) ~= "number" then
		return { Ok = false, Error = "InvalidTarget" }
	end

	local partyId = playerParty[userId]
	if not partyId then
		return { Ok = false, Error = "NotInParty" }
	end

	local party = parties[partyId]
	if not party then
		playerParty[userId] = nil
		return { Ok = false, Error = "NotInParty" }
	end

	if party.Leader ~= userId then
		return { Ok = false, Error = "NotLeader" }
	end

	if targetUserId == userId then
		return { Ok = false, Error = "AlreadyLeader" }
	end

	if playerParty[targetUserId :: number] ~= partyId then
		return { Ok = false, Error = "TargetNotInParty" }
	end

	party.Leader = targetUserId :: number

	log(
		string.format(
			"%s (UserId %d) transfirió el liderazgo de la party %s a UserId %d",
			player.Name,
			userId,
			partyId,
			targetUserId :: number
		)
	)

	broadcastParty(party)
	return { Ok = true, Party = buildPartyState(party) }
end

-- Lectura de solo consulta, por si otro servicio (fases futuras,
-- p. ej. matchmaking real) necesita saber la party de un jugador
-- sin pasar por remotes. Devuelve una copia (buildPartyState ya
-- construye una tabla nueva cada vez), nunca la referencia interna.
function PartyService.GetPartyState(player: Player): Types.PartyState?
	local partyId = playerParty[player.UserId]
	if not partyId then
		return nil
	end
	local party = parties[partyId]
	if not party then
		return nil
	end
	return buildPartyState(party)
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function PartyService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	remoteRef = registry.RemoteService
	-- Referencia guardada para consultar el lock de Match (ver
	-- JoinParty). El registry ya está completamente poblado acá
	-- (ServiceLoader llena TODO el registry antes de llamar a
	-- cualquier :Init), así que esto es válido sin importar el
	-- orden real de carga entre PartyService y MatchService.
	matchRef = registry.MatchService
end

-- Envuelve un handler de RemoteFunction en pcall: un error inesperado
-- (referencia nil, argumento raro, etc.) nunca debe tirar abajo el
-- remote ni filtrar un stack trace interno al cliente; se loguea acá
-- y el cliente recibe un resultado de error controlado.
local function safeInvoke(
	actionName: string,
	handler: (player: Player, ...any) -> Types.PartyActionResult
): (player: Player, ...any) -> Types.PartyActionResult
	return function(player: Player, ...: any): Types.PartyActionResult
		local ok, result = pcall(handler, player, ...)
		if not ok then
			logError(string.format("Error interno en %s: %s", actionName, tostring(result)))
			return { Ok = false, Error = "InternalError" }
		end
		return result :: Types.PartyActionResult
	end
end

function PartyService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	local createRemote = remoteRef.Get("Party_Create") :: RemoteFunction
	createRemote.OnServerInvoke = safeInvoke("Party_Create", function(player: Player)
		return PartyService.CreateParty(player)
	end)

	local joinRemote = remoteRef.Get("Party_Join") :: RemoteFunction
	joinRemote.OnServerInvoke = safeInvoke("Party_Join", function(player: Player, partyId: any)
		return PartyService.JoinParty(player, partyId)
	end)

	local leaveRemote = remoteRef.Get("Party_Leave") :: RemoteFunction
	leaveRemote.OnServerInvoke = safeInvoke("Party_Leave", function(player: Player)
		return PartyService.LeaveParty(player)
	end)

	local kickRemote = remoteRef.Get("Party_Kick") :: RemoteFunction
	kickRemote.OnServerInvoke = safeInvoke("Party_Kick", function(player: Player, targetUserId: any)
		return PartyService.KickMember(player, targetUserId)
	end)

	local transferRemote = remoteRef.Get("Party_TransferLeadership") :: RemoteFunction
	transferRemote.OnServerInvoke = safeInvoke(
		"Party_TransferLeadership",
		function(player: Player, targetUserId: any)
			return PartyService.TransferLeadership(player, targetUserId)
		end
	)

	-- Desconexión: tratamos a un jugador que se va como un Leave
	-- implícito. Se conecta directamente sobre el trove global
	-- (mismo patrón que MatchService usa para su roster), en vez de
	-- indirectamente vía CleanupService.GetPlayerTrove, porque esto
	-- no es "un recurso a limpiar" sino lógica de negocio que debe
	-- ejecutarse en el momento de la desconexión.
	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		local userId = player.UserId
		local partyId = playerParty[userId]

		if partyId then
			local party = parties[partyId]
			if party then
				removeMember(party, userId)
			else
				playerParty[userId] = nil
			end
		end

		-- No dejar basura acumulándose en el mapa de rate limiting
		-- para UserIds que ya no están conectados.
		lastActionAt[userId] = nil
	end))

	log("PartyService listo.")
end

-- Fase 3: MatchService se suscribe a esto para reaccionar a
-- abandonos/desconexiones y a la destrucción de una party sin que
-- PartyService necesite conocer nada sobre partidas.
PartyService.PartyChanged = PartyChanged

return PartyService
