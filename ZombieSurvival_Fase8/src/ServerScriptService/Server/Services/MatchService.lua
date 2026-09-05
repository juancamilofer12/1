--!strict
--[[
	MatchService.lua

	Responsabilidad (Fase 3): conectar el Party System con una
	partida real. Una Match ahora nace de una Party puntual cuando su
	líder lo solicita -- ya NO es un singleton de servidor que
	arranca solo al juntarse suficientes jugadores conectados (eso
	era el comportamiento placeholder de la Fase 1, explícitamente
	pendiente de reemplazo).

	Relación Party -> Match: como máximo una Match activa por Party
	a la vez. La Match vive en `matchesByParty`, indexada por
	PartyId; esa tabla ES la relación (no se duplica en otro lado).

	Server-authoritative: todo el estado de cada Match vive acá. El
	cliente solo pide iniciar partida (remote "Match_Start") y recibe
	snapshots de solo lectura vía "Match_StateUpdated" /
	"Match_CountdownUpdate".

	Reutiliza tal cual (sin reescribirla) la StateMachine genérica de
	Shared/Utils: cada Match tiene su PROPIA instancia, como la API
	de StateMachine.new() ya soporta -- no es una máquina de estados
	nueva, es el mismo módulo usado varias veces.

	Esta fase SOLO gestiona inicio de partida + countdown +
	preparación + infraestructura mínima de finalización. NO
	contiene zombies, oleadas, spawns, combate, inventario,
	construcción, recursos, economía, bosses ni loot: eso se
	construirá en fases posteriores escuchando MatchService.StateChanged
	o llamando a MatchService.RequestTransition.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameState = require(ReplicatedStorage.Shared.Enums.GameState)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local StateMachine = require(ReplicatedStorage.Shared.Utils.StateMachine)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local Trove = require(ReplicatedStorage.Shared.Utils.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local MatchService = {}
MatchService.Name = "MatchService" :: string

-- Transiciones permitidas. Se declaran los 6 estados que pide la
-- Fase 3; Preparation -> Lobby existe solo como salida de
-- cancelación defensiva (Party queda vacía durante Preparation),
-- igual que Countdown -> Lobby. GameOver -> Lobby se deja declarado
-- para dejar "preparado el retorno al Lobby" que pide la fase, aun
-- cuando esta fase no lo dispare automáticamente (ver limpieza más
-- abajo: al llegar a GameOver la Match se limpia y se elimina, así
-- que la Party queda libre para arrancar una Match nueva, que
-- cumple el mismo rol práctico que "volver al Lobby").
local ALLOWED_TRANSITIONS = {
	[GameState.Lobby] = { GameState.Countdown },
	[GameState.Countdown] = { GameState.Preparation, GameState.Lobby },
	[GameState.Preparation] = { GameState.InProgress, GameState.Lobby },
	[GameState.InProgress] = { GameState.Ending },
	[GameState.Ending] = { GameState.GameOver },
	[GameState.GameOver] = { GameState.Lobby },
}

-- Representación interna de una Match. NO se expone tal cual al
-- cliente: buildMatchState() la traduce a Types.MatchState.
type MatchInternal = {
	MatchId: string,
	PartyId: string,
	Players: { [number]: boolean }, -- UserId -> sigue en la partida
	StateMachine: StateMachine.StateMachine,
	Round: number,
	PhaseStartedAt: number,
	CountdownEndsAt: number?,
	-- Recursos de vida == duración de ESTA Match puntual (timers de
	-- countdown/ending). Se destruye entero al cancelar o finalizar,
	-- nunca se comparte entre Matches.
	Trove: Trove.Trove,
}

local matchesByParty: { [string]: MatchInternal } = {}

-- Rate limiting de Match_Start, mismo patrón que
-- PartyService.lastActionAt (último os.clock() por UserId).
local lastStartAttemptAt: { [number]: number } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local remoteRef: any = nil
local partyRef: any = nil

-- Se re-expone como un Signal propio (en vez de escuchar cada
-- StateMachine individual desde afuera) para que MatchService
-- controle su API pública y pueda enriquecer el payload sin romper
-- consumidores futuros. Fase 3: ahora incluye PartyId porque puede
-- haber varias Matches activas a la vez.
local StateChanged = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("MatchService", message)
	end
end

local function logError(message: string)
	if debugRef then
		debugRef:Error("MatchService", message)
	end
end

local function countPlayers(playersSet: { [number]: boolean }): number
	local count = 0
	for _ in pairs(playersSet) do
		count += 1
	end
	return count
end

-- Devuelve false (y bloquea la acción) si el jugador solicitó un
-- inicio de partida más rápido que MatchConfig.StartMatchCooldownSeconds.
local function checkStartRateLimit(userId: number): boolean
	local now = os.clock()
	local last = lastStartAttemptAt[userId]
	if last ~= nil and (now - last) < MatchConfig.StartMatchCooldownSeconds then
		return false
	end
	lastStartAttemptAt[userId] = now
	return true
end

-- API pública de solo lectura.
local function buildMatchState(match: MatchInternal): Types.MatchState
	local timeRemaining = 0
	if match.CountdownEndsAt then
		timeRemaining = math.max(0, match.CountdownEndsAt - os.clock())
	end

	return {
		Id = match.MatchId,
		PartyId = match.PartyId,
		Phase = match.StateMachine:GetState() :: Types.MatchPhase,
		PhaseStartedAt = match.PhaseStartedAt,
		Round = match.Round,
		TimeRemaining = timeRemaining,
		-- Copia para que el llamador no pueda mutar el roster interno.
		Players = TableUtils.DeepCopy(match.Players),
	} :: any
end

-- Empuja `state` (o nil, cuando la Match ya no existe) a todos los
-- jugadores que todavía figuran en el roster de la Match.
local function broadcastState(match: MatchInternal, state: Types.MatchState?)
	local ok, remote = pcall(function()
		return remoteRef.Get("Match_StateUpdated")
	end)
	if not ok then
		logError("No se pudo obtener el remote Match_StateUpdated: " .. tostring(remote))
		return
	end

	for userId in pairs(match.Players) do
		local targetPlayer = Players:GetPlayerByUserId(userId)
		if targetPlayer then
			(remote :: RemoteEvent):FireClient(targetPlayer, state)
		end
	end
end

local function broadcastCountdown(match: MatchInternal, timeRemaining: number)
	local ok, remote = pcall(function()
		return remoteRef.Get("Match_CountdownUpdate")
	end)
	if not ok then
		logError("No se pudo obtener el remote Match_CountdownUpdate: " .. tostring(remote))
		return
	end

	local payload: Types.MatchCountdownUpdate = {
		PartyId = match.PartyId,
		TimeRemaining = timeRemaining,
	}

	for userId in pairs(match.Players) do
		local targetPlayer = Players:GetPlayerByUserId(userId)
		if targetPlayer then
			(remote :: RemoteEvent):FireClient(targetPlayer, payload)
		end
	end
end

-- Único punto de salida de una Match: cancelación (Party inválida) o
-- finalización normal (GameOver) pasan por acá. Limpia timers/
-- conexiones (Trove), notifica a los clientes afectados con `nil` y
-- rompe la relación Party -> Match (matchesByParty[partyId] = nil).
local function removeMatch(match: MatchInternal, eventName: string, reason: string)
	if matchesByParty[match.PartyId] ~= match then
		-- Ya se removió (llamada doble defensiva): no hacer nada más.
		return
	end

	broadcastState(match, nil)
	match.Trove:Destroy()
	matchesByParty[match.PartyId] = nil

	if debugRef then
		debugRef:Info(
			"MatchService",
			string.format("[%s] Match %s (Party %s) removida: %s", eventName, match.MatchId, match.PartyId, reason)
		)
	end
end

-- Transición controlada: valida contra ALLOWED_TRANSITIONS (vía
-- StateMachine:TransitionTo), y si se realizó, actualiza
-- PhaseStartedAt, notifica StateChanged y empuja el nuevo snapshot.
-- Devuelve false sin efecto alguno ante una transición inválida
-- (StateMachine ya loguea el warning).
local function transitionMatch(match: MatchInternal, newState: string): boolean
	local oldState = match.StateMachine:GetState()
	local didTransition = match.StateMachine:TransitionTo(newState)
	if not didTransition then
		return false
	end

	match.PhaseStartedAt = os.clock()
	log(string.format("[StateChanged] Match %s (Party %s): %s -> %s", match.MatchId, match.PartyId, oldState, newState))
	StateChanged:Fire(match.PartyId, newState, oldState)
	broadcastState(match, buildMatchState(match))
	return true
end

-- Arranca el ticker de countdown: cada CountdownTickInterval
-- segundos empuja el tiempo restante, y al llegar a 0 dispara la
-- transición a Preparation. El tiempo lo controla el servidor
-- (os.clock() acá, nunca un contador que el cliente pueda influir).
local function startCountdown(match: MatchInternal)
	match.CountdownEndsAt = os.clock() + MatchConfig.CountdownDuration

	if debugRef then
		debugRef:Info(
			"MatchService",
			string.format("[CountdownStarted] Match %s (Party %s)", match.MatchId, match.PartyId)
		)
	end

	local thread = task.spawn(function()
		while true do
			local remaining = (match.CountdownEndsAt :: number) - os.clock()
			if remaining <= 0 then
				broadcastCountdown(match, 0)
				transitionMatch(match, GameState.Preparation)
				return
			end

			broadcastCountdown(match, remaining)
			task.wait(MatchConfig.CountdownTickInterval)
		end
	end)

	match.Trove:Add(function()
		task.cancel(thread)
	end)
end

-- Arranca el timer de Ending -> GameOver. Al llegar a GameOver, la
-- Match se limpia y se elimina (ver removeMatch): la Party queda
-- libre de nuevo, que es la forma en la que esta fase deja
-- "preparado el retorno al Lobby" sin necesitar un estado
-- intermedio con vida propia.
local function startEndingTimer(match: MatchInternal)
	local thread = task.delay(MatchConfig.EndingDuration, function()
		if transitionMatch(match, GameState.GameOver) then
			if debugRef then
				debugRef:Info(
					"MatchService",
					string.format("[MatchEnded] Match %s (Party %s)", match.MatchId, match.PartyId)
				)
			end
			removeMatch(match, "MatchEnded", "GameOver alcanzado")
		end
	end)

	match.Trove:Add(function()
		task.cancel(thread)
	end)
end

local function onPhaseEntered(match: MatchInternal, newState: string)
	if newState == GameState.Countdown then
		startCountdown(match)
	elseif newState == GameState.InProgress then
		match.Round = 1
		if debugRef then
			debugRef:Info("MatchService", string.format("[MatchStarted] Match %s (Party %s)", match.MatchId, match.PartyId))
		end
	elseif newState == GameState.Ending then
		startEndingTimer(match)
	end
end

-- Crea la Match para una Party ya validada y la deja arrancando su
-- Countdown. Único punto de creación: no hay otro lugar del código
-- que inserte en matchesByParty.
local function createMatch(partyState: Types.PartyState): MatchInternal
	local playersSet: { [number]: boolean } = {}
	for _, member in ipairs(partyState.Members) do
		playersSet[member.UserId] = true
	end

	local match: MatchInternal = {
		MatchId = HttpService:GenerateGUID(false),
		PartyId = partyState.PartyId,
		Players = playersSet,
		StateMachine = StateMachine.new(GameState.Lobby, ALLOWED_TRANSITIONS),
		Round = 0,
		PhaseStartedAt = os.clock(),
		CountdownEndsAt = nil,
		Trove = Trove.new(),
	}

	matchesByParty[match.PartyId] = match

	if debugRef then
		debugRef:Info(
			"MatchService",
			string.format("[MatchCreated] Match %s para Party %s", match.MatchId, match.PartyId)
		)
	end

	match.StateMachine.Changed:Connect(function(newState: string, _oldState: string)
		onPhaseEntered(match, newState)
	end)

	-- Lobby -> Countdown inmediato: el registro nace en Lobby por un
	-- instante lógico (para que la StateMachine tenga un origen
	-- válido) pero el pedido del líder YA es "arrancar", así que se
	-- dispara la primera transición acá mismo, de forma síncrona.
	transitionMatch(match, GameState.Countdown)

	return match
end

-- Reacciona a cambios de la Party asociada a una Match (abandono,
-- desconexión, o destrucción completa de la Party). PartyService no
-- sabe nada de Matches: esto es pura reacción del lado de
-- MatchService al Signal PartyChanged.
local function onPartyChanged(partyId: string, partyState: Types.PartyState?)
	local match = matchesByParty[partyId]
	if not match then
		return
	end

	if partyState == nil then
		-- La Party quedó vacía y PartyService ya la destruyó: cancelar
		-- countdown/timers, limpiar la Match y sus referencias.
		removeMatch(match, "MatchEnded", "Party vacía/destruida")
		return
	end

	-- Reconciliar el roster de la Match contra los miembros actuales
	-- de la Party: cualquier UserId que ya no esté en la Party se
	-- considera que abandonó la partida.
	local stillInParty: { [number]: boolean } = {}
	for _, member in ipairs(partyState.Members) do
		stillInParty[member.UserId] = true
	end

	local anyoneLeft = false
	for userId in pairs(match.Players) do
		if not stillInParty[userId] then
			match.Players[userId] = nil
			anyoneLeft = true
			if debugRef then
				debugRef:Info(
					"MatchService",
					string.format("[PlayerLeftMatch] UserId %d dejó la Match %s (Party %s)", userId, match.MatchId, match.PartyId)
				)
			end
		end
	end

	if not anyoneLeft then
		return
	end

	if countPlayers(match.Players) == 0 then
		removeMatch(match, "MatchEnded", "Sin jugadores restantes en la Match")
		return
	end

	-- Todavía queda al menos un jugador: se informa el roster
	-- actualizado a los que quedan, sin cancelar nada.
	broadcastState(match, buildMatchState(match))
end

-- ============================================================
-- API pública (llamada desde el handler de Match_Start y, a
-- futuro, desde servicios de gameplay que construyan sobre esta
-- base).
-- ============================================================

-- Fase 3, punto 1: validaciones de inicio de partida, en el mismo
-- orden en que las pide la especificación. El cliente solo pide; el
-- servidor decide todo -- no recibe ni confía en ningún dato del
-- cliente más allá de la identidad del `player` que invoca (que
-- Roblox garantiza).
function MatchService.RequestStart(player: Player): Types.MatchActionResult
	local userId = player.UserId

	-- "la operación no está siendo ejecutada dos veces": el handler
	-- no hace ningún yield (ver nota de concurrencia en
	-- PartyService.lua), así que dos invocaciones casi simultáneas
	-- se procesan de punta a punta una después de la otra; sumado al
	-- rate limit y al chequeo de MatchAlreadyExists más abajo, un
	-- doble click nunca crea dos Matches.
	if not checkStartRateLimit(userId) then
		return { Ok = false, Error = "RateLimited" }
	end

	-- "el jugador existe": el `player` que entrega OnServerInvoke es
	-- siempre una instancia válida y conectada (Roblox no permite
	-- invocar RemoteFunctions con un Player stale); se valida además
	-- de forma defensiva.
	if not player:IsDescendantOf(Players) then
		return { Ok = false, Error = "PlayerNotFound" }
	end

	-- "pertenece a una Party" + "la Party sigue existiendo": ambas
	-- las resuelve GetPartyState (nil si no está en ninguna o si la
	-- party ya no existe).
	local partyState = partyRef.GetPartyState(player)
	if not partyState then
		return { Ok = false, Error = "NotInParty" }
	end

	-- "es el líder"
	if partyState.Leader ~= userId then
		return { Ok = false, Error = "NotLeader" }
	end

	-- "tiene al menos 1 miembro" (parametrizado vía MatchConfig en
	-- vez de asumir 1 hardcodeado).
	if #partyState.Members < MatchConfig.MinPlayersToStart then
		return { Ok = false, Error = "NotEnoughPlayers" }
	end

	-- "no existe ya una partida para esa Party"
	if matchesByParty[partyState.PartyId] then
		return { Ok = false, Error = "MatchAlreadyExists" }
	end

	-- "los miembros siguen conectados"
	for _, member in ipairs(partyState.Members) do
		if not Players:GetPlayerByUserId(member.UserId) then
			return { Ok = false, Error = "MemberDisconnected" }
		end
	end

	local match = createMatch(partyState)
	return { Ok = true, Match = buildMatchState(match) }
end

-- Lectura de solo consulta. Devuelve una copia (buildMatchState ya
-- construye una tabla nueva cada vez), nunca la referencia interna.
function MatchService.GetMatchState(partyId: string): Types.MatchState?
	local match = matchesByParty[partyId]
	if not match then
		return nil
	end
	return buildMatchState(match)
end

-- Fase 3, punto 6: única fuente de verdad sobre si una Party está
-- asociada a una Match. PartyService la consulta desde JoinParty
-- para impedir que entren miembros nuevos mientras dure la partida;
-- no se duplica este booleano en ningún otro lado.
function MatchService.IsPartyLocked(partyId: string): boolean
	return matchesByParty[partyId] ~= nil
end

-- Transición controlada de uso interno/futuro: por ejemplo, un
-- servicio de gameplay de una fase posterior puede llamar
-- MatchService.RequestTransition(partyId, GameState.InProgress)
-- cuando termine de preparar la ronda, sin necesitar acceso directo
-- a la StateMachine de la Match ni reimplementar validación.
function MatchService.RequestTransition(partyId: string, newState: string): boolean
	local match = matchesByParty[partyId]
	if not match then
		logError("RequestTransition: no hay Match para la Party " .. partyId)
		return false
	end
	return transitionMatch(match, newState)
end

-- Fuerza el fin de la partida actual (InProgress/Preparation ->
-- Ending). La infraestructura de fases futuras la usará cuando haya
-- lógica real de fin de partida (todos los zombies muertos, todos
-- los jugadores muertos, etc.); por ahora queda disponible para
-- pruebas manuales y para completar el punto 8 de esta fase.
function MatchService.EndMatch(partyId: string): boolean
	return MatchService.RequestTransition(partyId, GameState.Ending)
end

MatchService.StateChanged = StateChanged

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function MatchService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	remoteRef = registry.RemoteService
	partyRef = registry.PartyService
end

-- Envuelve el handler de Match_Start en pcall, mismo patrón que
-- PartyService.safeInvoke: un error inesperado nunca debe tirar
-- abajo el remote ni filtrar un stack trace interno al cliente.
local function safeInvoke(
	actionName: string,
	handler: (player: Player) -> Types.MatchActionResult
): (player: Player) -> Types.MatchActionResult
	return function(player: Player): Types.MatchActionResult
		local ok, result = pcall(handler, player)
		if not ok then
			logError(string.format("Error interno en %s: %s", actionName, tostring(result)))
			return { Ok = false, Error = "InternalError" }
		end
		return result :: Types.MatchActionResult
	end
end

function MatchService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	local startRemote = remoteRef.Get("Match_Start") :: RemoteFunction
	startRemote.OnServerInvoke = safeInvoke("Match_Start", function(player: Player)
		return MatchService.RequestStart(player)
	end)

	-- Única suscripción, de por vida del servidor, al Signal de
	-- PartyService: cubre líder/miembro que abandona, desconexiones
	-- (PartyService ya trata PlayerRemoving como un Leave implícito
	-- y dispara este mismo Signal) y Party que queda vacía.
	globalTrove:Add(partyRef.PartyChanged:Connect(onPartyChanged))

	-- No dejar basura acumulándose en el mapa de rate limiting para
	-- UserIds que ya no están conectados (mismo cuidado que
	-- PartyService.lastActionAt).
	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		lastStartAttemptAt[player.UserId] = nil
	end))

	log("MatchService listo.")
end

return MatchService
