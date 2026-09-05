--!strict
--[[
	WaveService.lua

	Responsabilidad: el sub-ciclo de rondas (Preparación -> Oleada ->
	Intermisión -> ronda siguiente) que corre MIENTRAS una Match está
	en `GameState.InProgress`. Fase 8 del proyecto.

	Relación con MatchService (Fase 3): este servicio NO es una
	StateMachine de Match nueva ni reemplaza nada de esa fase --
	escucha `MatchService.StateChanged` para saber cuándo una Match
	puntual (identificada por `PartyId`, igual que `matchesByParty`)
	entra o sale de `InProgress`, y solo entonces arranca/frena su
	propio ciclo de rondas para esa Match. Indexado por `PartyId`
	(`roundsByParty`), mismo patrón que `MatchService.matchesByParty`.

	Relación con ZombieService/ZombieAIService: WaveService solo le
	pide a `ZombieService.SpawnZombie` que spawnee UN zombie de un
	tipo puntual con ciertos multiplicadores -- no sabe nada de rigs,
	tags ni IA. Se entera de que un zombie murió/despawneó
	suscribiéndose a `ZombieService.ZombieRemoved` (igual que
	`ZombieAIService`), y usa eso para saber cuándo terminó la
	oleada actual (cero zombies vivos de ESTA ronda).

	Dificultad progresiva (`WaveConfig.GetDifficultyForRound`):
	cantidad de zombies, multiplicador de salud/velocidad y anillo
	máximo de spawn se recalculan para cada ronda nueva -- nunca
	hardcodeados acá. El tipo de cada zombie individual sale de un
	sorteo ponderado (`pickWeightedType`) sobre
	`WaveConfig.GetAvailableZombieTypes(ronda)`.

	Limpieza ante fin de Match abrupto: `MatchService.StateChanged`
	cubre la salida NORMAL de `InProgress` (-> Ending). Pero
	`MatchService.onPartyChanged` puede remover una Match directamente
	(Party destruida/vacía) SIN pasar por esa transición si nadie
	queda en la partida -- por eso este servicio también escucha
	`PartyService.PartyChanged` (mismo Signal que ya consume
	`MatchService`) para detectar ese caso límite y frenar/limpiar sus
	rondas igual, en vez de dejar timers y zombies huérfanos.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(ReplicatedStorage.Shared.Enums.GameState)
local RoundPhase = require(ReplicatedStorage.Shared.Enums.RoundPhase)
local ZombieType = require(ReplicatedStorage.Shared.Enums.ZombieType)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)
local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Trove = require(ReplicatedStorage.Shared.Utils.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local WaveService = {}
WaveService.Name = "WaveService" :: string

type RoundInternal = {
	PartyId: string,
	Round: number,
	Phase: Types.RoundPhaseId,
	PhaseStartedAt: number,
	ActiveZombieIds: { [Types.ZombieId]: boolean },
	-- true recién cuando el loop de spawn escalonado terminó de
	-- INTENTAR spawnear los N zombies de la ronda (haya tenido éxito
	-- en todos o no). Sin esto, el primer zombie en morir mientras
	-- todavía se están spawneando los demás dispararía una
	-- Intermisión prematura (ActiveZombieIds pasando por 0 a mitad
	-- de una oleada que ni terminó de nacer).
	SpawnedAllZombies: boolean,
	-- Recursos con vida == duración de ESTA ronda puntual (timers de
	-- Preparación/Intermisión, loop de spawn). Se destruye entero al
	-- pasar de ronda o al terminar la Match, nunca se comparte entre
	-- rondas.
	Trove: Trove.Trove,
}

local roundsByParty: { [string]: RoundInternal } = {}
-- ZombieId -> PartyId dueño, para poder rutear ZombieService.
-- ZombieRemoved (evento GLOBAL, no sabe de rondas) hacia la ronda
-- correcta sin iterar `roundsByParty` entero en cada muerte.
local zombieOwner: { [Types.ZombieId]: string } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local zombieRef: any = nil
local matchRef: any = nil
local partyRef: any = nil

-- Fase de UI/HUD futura: snapshot de solo lectura de una ronda en
-- cada cambio de fase (o `nil` cuando la ronda se frena). Mismo
-- criterio que ResourceService.NodeStateChanged en la Fase 5 -- el
-- Signal queda listo, nada lo conecta a un remote hasta que haga
-- falta.
local RoundStateChanged = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("WaveService", message)
	end
end

local function logWarn(message: string)
	if debugRef then
		debugRef:Warn("WaveService", message)
	end
end

local function countActiveZombies(record: RoundInternal): number
	local count = 0
	for _ in pairs(record.ActiveZombieIds) do
		count += 1
	end
	return count
end

local function buildRoundState(record: RoundInternal): Types.RoundState
	local timeRemaining = 0
	if record.Phase == RoundPhase.Preparation then
		timeRemaining = math.max(0, WaveConfig.PreparationSeconds - (os.clock() - record.PhaseStartedAt))
	elseif record.Phase == RoundPhase.Intermission then
		timeRemaining = math.max(0, WaveConfig.IntermissionSeconds - (os.clock() - record.PhaseStartedAt))
	end

	return {
		PartyId = record.PartyId,
		Round = record.Round,
		Phase = record.Phase,
		PhaseStartedAt = record.PhaseStartedAt,
		TimeRemaining = timeRemaining,
		ZombiesRemaining = countActiveZombies(record),
	}
end

-- Sorteo ponderado simple sobre la lista que devuelve
-- `WaveConfig.GetAvailableZombieTypes`. Cae a `ZombieType.Normal` si
-- por alguna razón la lista viene vacía o con peso total 0 (config
-- inconsistente) -- nunca debe impedir que la oleada avance.
local function pickWeightedType(available: { { ZombieType: string, Weight: number } }): string
	local totalWeight = 0
	for _, entry in ipairs(available) do
		totalWeight += entry.Weight
	end

	if totalWeight <= 0 then
		return ZombieType.Normal
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in ipairs(available) do
		cumulative += entry.Weight
		if roll <= cumulative then
			return entry.ZombieType
		end
	end

	return available[#available].ZombieType
end

-- ============================================================
-- Transiciones de fase de ronda
-- ============================================================

local enterPreparation: (record: RoundInternal) -> ()
local enterWave: (record: RoundInternal) -> ()
local enterIntermission: (record: RoundInternal) -> ()

-- Si tras spawnear todo lo que había que spawnear (o tras la muerte
-- de un zombie a mitad de oleada) ya no queda ninguno vivo de esta
-- ronda, se pasa a Intermisión. Separado de `enterIntermission` para
-- no duplicar el chequeo `SpawnedAllZombies and count == 0` en los
-- dos lugares que pueden dispararlo (fin del loop de spawn, y cada
-- ZombieRemoved).
local function checkWaveCompletion(record: RoundInternal)
	if record.Phase ~= RoundPhase.Wave then
		return
	end
	if not record.SpawnedAllZombies then
		return
	end
	if countActiveZombies(record) > 0 then
		return
	end
	enterIntermission(record)
end

local function spawnWaveZombies(record: RoundInternal, difficulty: { ZombieCount: number, HealthMultiplier: number, SpeedMultiplier: number, MaxRing: number })
	local thread = task.spawn(function()
		for _ = 1, difficulty.ZombieCount do
			-- Defensivo: la ronda pudo haber sido frenada
			-- (MatchEnded) mientras este loop dormía en el
			-- `task.wait` de más abajo.
			if roundsByParty[record.PartyId] ~= record then
				return
			end

			local zombieType = pickWeightedType(WaveConfig.GetAvailableZombieTypes(record.Round))
			local result = zombieRef.SpawnZombie(zombieType, {
				MaxRing = difficulty.MaxRing,
				HealthMultiplier = difficulty.HealthMultiplier,
				SpeedMultiplier = difficulty.SpeedMultiplier,
			})

			if result.Ok and result.ZombieId then
				zombieOwner[result.ZombieId] = record.PartyId
				record.ActiveZombieIds[result.ZombieId] = true
			else
				logWarn(
					string.format(
						"No se pudo spawnear %s para la ronda %d (Party %s): %s",
						zombieType,
						record.Round,
						record.PartyId,
						tostring(result.Error)
					)
				)
			end

			task.wait(WaveConfig.SpawnIntervalSeconds)
		end

		if roundsByParty[record.PartyId] ~= record then
			return
		end

		record.SpawnedAllZombies = true
		checkWaveCompletion(record)
	end)

	record.Trove:Add(function()
		task.cancel(thread)
	end)
end

enterPreparation = function(record: RoundInternal)
	record.Phase = RoundPhase.Preparation
	record.PhaseStartedAt = os.clock()

	log(string.format("[Preparation] Party %s: ronda %d en %d s.", record.PartyId, record.Round, WaveConfig.PreparationSeconds))
	RoundStateChanged:Fire(record.PartyId, buildRoundState(record))

	local thread = task.delay(WaveConfig.PreparationSeconds, function()
		enterWave(record)
	end)
	record.Trove:Add(function()
		task.cancel(thread)
	end)
end

enterWave = function(record: RoundInternal)
	record.Phase = RoundPhase.Wave
	record.PhaseStartedAt = os.clock()
	record.ActiveZombieIds = {}
	record.SpawnedAllZombies = false

	local difficulty = WaveConfig.GetDifficultyForRound(record.Round, ZombieConfig.MaxConcurrentZombies)

	log(
		string.format(
			"[Wave] Party %s: ronda %d, %d zombies (x%.2f salud, x%.2f velocidad, anillo <= %d).",
			record.PartyId,
			record.Round,
			difficulty.ZombieCount,
			difficulty.HealthMultiplier,
			difficulty.SpeedMultiplier,
			difficulty.MaxRing
		)
	)
	RoundStateChanged:Fire(record.PartyId, buildRoundState(record))

	spawnWaveZombies(record, difficulty)
end

enterIntermission = function(record: RoundInternal)
	record.Phase = RoundPhase.Intermission
	record.PhaseStartedAt = os.clock()

	log(string.format("[Intermission] Party %s: ronda %d completada.", record.PartyId, record.Round))
	RoundStateChanged:Fire(record.PartyId, buildRoundState(record))

	local thread = task.delay(WaveConfig.IntermissionSeconds, function()
		record.Round += 1
		enterPreparation(record)
	end)
	record.Trove:Add(function()
		task.cancel(thread)
	end)
end

-- ============================================================
-- Arranque/frenado por Match (PartyId)
-- ============================================================

local function startRounds(partyId: string)
	if roundsByParty[partyId] then
		-- Defensivo: no debería poder pedirse InProgress dos veces
		-- para la misma Match (ver ALLOWED_TRANSITIONS de
		-- MatchService), pero no cuesta nada no duplicar el estado.
		return
	end

	local record: RoundInternal = {
		PartyId = partyId,
		Round = 1,
		Phase = RoundPhase.Preparation,
		PhaseStartedAt = os.clock(),
		ActiveZombieIds = {},
		SpawnedAllZombies = false,
		Trove = Trove.new(),
	}
	roundsByParty[partyId] = record

	log(string.format("[RoundsStarted] Party %s.", partyId))
	enterPreparation(record)
end

local function stopRounds(partyId: string, reason: string)
	local record = roundsByParty[partyId]
	if not record then
		return
	end
	roundsByParty[partyId] = nil

	-- Cancela cualquier timer de fase/loop de spawn pendiente antes
	-- de tocar los zombies -- evita que un spawn en vuelo agregue una
	-- entrada nueva a ActiveZombieIds después de haberlo limpiado.
	record.Trove:Destroy()

	for zombieId in pairs(record.ActiveZombieIds) do
		zombieOwner[zombieId] = nil
		zombieRef.DespawnZombie(zombieId, "MatchEnded")
	end

	log(string.format("[RoundsStopped] Party %s: %s.", partyId, reason))
	RoundStateChanged:Fire(partyId, nil)
end

-- ============================================================
-- Reacciones a otros servicios
-- ============================================================

local function onMatchStateChanged(partyId: string, newState: string, oldState: string)
	if newState == GameState.InProgress then
		startRounds(partyId)
	elseif oldState == GameState.InProgress then
		stopRounds(partyId, "Match salió de InProgress (-> " .. newState .. ")")
	end
end

-- Ver nota de cabecera: cubre el caso límite en el que MatchService
-- remueve una Match directamente (Party vacía/destruida) sin pasar
-- por una transición de GameState.
local function onPartyChanged(partyId: string, partyState: Types.PartyState?)
	if partyState ~= nil then
		return
	end
	if roundsByParty[partyId] then
		stopRounds(partyId, "Party vacía/destruida")
	end
end

local function onZombieRemoved(zombieId: Types.ZombieId)
	local partyId = zombieOwner[zombieId]
	if not partyId then
		return
	end
	zombieOwner[zombieId] = nil

	local record = roundsByParty[partyId]
	if not record then
		return
	end

	record.ActiveZombieIds[zombieId] = nil
	checkWaveCompletion(record)
end

-- ============================================================
-- API pública
-- ============================================================

function WaveService.GetRoundState(partyId: string): Types.RoundState?
	local record = roundsByParty[partyId]
	if not record then
		return nil
	end
	return buildRoundState(record)
end

WaveService.RoundStateChanged = RoundStateChanged

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function WaveService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	zombieRef = registry.ZombieService
	matchRef = registry.MatchService
	partyRef = registry.PartyService
end

function WaveService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	globalTrove:Add(matchRef.StateChanged:Connect(onMatchStateChanged))
	globalTrove:Add(partyRef.PartyChanged:Connect(onPartyChanged))
	globalTrove:Add(zombieRef.ZombieRemoved:Connect(onZombieRemoved))

	log("WaveService listo.")
end

return WaveService
