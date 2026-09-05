--!strict
--[[
	ZombieAIService.lua

	Responsabilidad: inteligencia artificial y pathfinding de cada
	zombie vivo. Fase 8 del proyecto.

	No conoce nada sobre spawns, rondas ni límites concurrentes --
	solo reacciona a `ZombieService.ZombieSpawned`/`ZombieRemoved`
	(un zombie a la vez, sin importar quién ni por qué lo spawneó) y
	administra un hilo de IA propio por zombie hasta que muere o se
	despawnea.

	Estados (Shared/Enums/ZombieAIState.lua), una `StateMachine`
	(Shared/Utils/StateMachine.lua) por zombie, mismo patrón que
	`MatchService` usa una por Match:
		Idle -> Searching -> Chasing -> Attacking -> (vuelta a
		Chasing/Searching según se mantenga o se pierda el objetivo)
		-> Dead (terminal, sin salida).

	Pathfinding con intervalos controlados (pedido explícito de la
	Fase 8, "evitar cálculos pesados en cada frame"):
	- Cada zombie corre en su PROPIO hilo (`task.spawn`), nunca en un
	  `RunService.Heartbeat` compartido -- el costo de decidir/mover
	  un zombie nunca escala con el framerate del servidor.
	- `PathfindingService:CreatePath` + `ComputeAsync` solo se llama
	  cuando hace falta un path nuevo: al entrar en Chasing por
	  primera vez, si el target se movió más de
	  `REPATH_DISTANCE_THRESHOLD` studs desde el último cálculo, o si
	  el path anterior falló/se agotó -- nunca una vez por iteración
	  del loop ni una vez por frame.
	- Rutas fallidas o atascos: `moveToAndWait` espera
	  `Humanoid.MoveToFinished` con un timeout (`STUCK_TIMEOUT_SECONDS`).
	  Si no llega a tiempo (atascado) o el `Path:ComputeAsync` no da
	  `Enum.PathStatus.Success`, el zombie NO reintenta en el
	  siguiente frame: espera `REPATH_RETRY_SECONDS` y deja que la
	  vuelta normal del loop reevalúe distancia/target antes de
	  recalcular.

	Ataque zombie -> jugador (dirección inversa a CombatService, que
	solo valida jugador -> objetivo `Combatable`): este archivo aplica
	`Humanoid:TakeDamage` directo sobre el jugador, con su propio
	cooldown por zombie (`ZombieConfig.Types[type].AttackCooldownSeconds`).
	No pasa por CombatService a propósito -- CombatService es
	específicamente el punto de validación de ACCIONES DEL JUGADOR
	(arma equipada, munición, cooldown de arma); un zombie no tiene
	arma ni munición, así que reutilizarlo forzaría un objetivo/slot
	de arma falso sin necesidad real.

	Comportamientos exclusivos (ver ZombieConfig.lua):
	- Explosive: al conectar un golpe, además del daño de contacto,
	  hace daño en área a TODOS los jugadores dentro de
	  `ExplosionRadius` (no solo al target) y se autodestruye
	  (`ZombieService.KillZombie`) -- una sola explosión por Explosive,
	  nunca vuelve a atacar.
	- Toxic: al conectar un golpe, además del daño de contacto, aplica
	  una quemadura de veneno (daño periódico) sobre el target por
	  `PoisonDurationSeconds`. Reaplicar antes de que termine
	  REFRESCA la duración en vez de acumular stacks (ver
	  `applyPoison`) -- decisión explícita para no tener que diseñar
	  un sistema de stacks que nadie pidió todavía.
]]

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local ZombieAIState = require(ReplicatedStorage.Shared.Enums.ZombieAIState)
local StateMachine = require(ReplicatedStorage.Shared.Utils.StateMachine)
local Trove = require(ReplicatedStorage.Shared.Utils.Trove)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local ZombieAIService = {}
ZombieAIService.Name = "ZombieAIService" :: string

local ALLOWED_AI_TRANSITIONS = {
	[ZombieAIState.Idle] = { ZombieAIState.Searching, ZombieAIState.Dead },
	[ZombieAIState.Searching] = { ZombieAIState.Idle, ZombieAIState.Chasing, ZombieAIState.Dead },
	[ZombieAIState.Chasing] = { ZombieAIState.Attacking, ZombieAIState.Searching, ZombieAIState.Dead },
	[ZombieAIState.Attacking] = { ZombieAIState.Chasing, ZombieAIState.Searching, ZombieAIState.Dead },
	[ZombieAIState.Dead] = {},
}

-- Intervalo de "pensamiento" mientras no hay target (Idle/Searching)
-- y también el descanso entre golpes mientras se está Attacking.
local THINK_INTERVAL_SECONDS = 0.5
-- Mínimo de segundos entre dos ComputeAsync consecutivos para el
-- MISMO zombie, aunque el target se siga moviendo.
local MIN_REPATH_INTERVAL_SECONDS = 1.5
-- Si el target se movió más que esto desde el último path calculado,
-- se fuerza un recálculo aunque no haya pasado MIN_REPATH_INTERVAL_SECONDS.
local REPATH_DISTANCE_THRESHOLD_STUDS = 6
-- Cuánto esperar un MoveToFinished antes de considerar "atascado".
local STUCK_TIMEOUT_SECONDS = 4
-- Espera antes de reintentar tras un path fallido o un atasco, para
-- no martillar PathfindingService contra un path imposible.
local REPATH_RETRY_SECONDS = 1
-- Un target más allá de DetectionRange * este multiplicador se
-- abandona (el zombie "pierde interés"), aunque ya lo tuviera
-- trabado como objetivo -- evita persecuciones infinitas a través de
-- todo el mapa si el jugador escapa lo suficiente.
local LEASH_RANGE_MULTIPLIER = 1.5

type AIRecord = {
	Trove: Trove.Trove,
}

local aiByZombie: { [Types.ZombieId]: AIRecord } = {}
-- Player -> thread de veneno activo. Ver applyPoison/clearPoison:
-- reaplicar antes de que termine cancela el anterior y arranca de
-- cero (refresca duración, no acumula stacks).
local poisonThreads: { [Player]: thread } = {}

local debugRef: any = nil
local cleanupRef: any = nil
local zombieRef: any = nil

local function log(message: string)
	if debugRef then
		debugRef:Info("ZombieAIService", message)
	end
end

-- ============================================================
-- Helpers de jugador/objetivo
-- ============================================================

local function getCharacterRootAndHumanoid(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not (root :: Instance):IsA("BasePart") then
		return nil, nil
	end
	return root :: BasePart, humanoid
end

-- Jugador vivo más cercano a `fromPosition` dentro de `maxDistance`,
-- o nil si ninguno califica. No prioriza por nada más que distancia
-- (sin percepción de línea de visión en esta fase -- ver
-- WORLD_MAP_DESIGN.md sección 10, que ya deja la responsabilidad de
-- "nunca aparecer sobre el jugador" en la UBICACIÓN de los spawn
-- points, no en la lógica de detección de la IA).
local function findNearestPlayer(fromPosition: Vector3, maxDistance: number): (Player?, BasePart?)
	local closestPlayer: Player? = nil
	local closestRoot: BasePart? = nil
	local closestDistance = maxDistance

	for _, player in ipairs(Players:GetPlayers()) do
		local root = getCharacterRootAndHumanoid(player)
		if root then
			local distance = (root.Position - fromPosition).Magnitude
			if distance <= closestDistance then
				closestDistance = distance
				closestPlayer = player
				closestRoot = root
			end
		end
	end

	return closestPlayer, closestRoot
end

-- ============================================================
-- Comportamientos especiales de ataque
-- ============================================================

local function clearPoison(player: Player)
	local thread = poisonThreads[player]
	if thread then
		task.cancel(thread)
		poisonThreads[player] = nil
	end
end

local function applyPoison(target: Player, config: any)
	clearPoison(target)

	local totalTicks = math.max(1, math.floor(config.PoisonDurationSeconds / config.PoisonTickIntervalSeconds))

	local function tick(remaining: number)
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(config.PoisonDamagePerTick)
		end

		if remaining <= 1 then
			poisonThreads[target] = nil
			return
		end

		poisonThreads[target] = task.delay(config.PoisonTickIntervalSeconds, function()
			tick(remaining - 1)
		end)
	end

	poisonThreads[target] = task.delay(config.PoisonTickIntervalSeconds, function()
		tick(totalTicks)
	end)
end

-- Daño en área a todos los jugadores dentro de ExplosionRadius desde
-- `originPosition` -- no solo al target que recibió el golpe que
-- disparó la explosión.
local function triggerExplosion(originPosition: Vector3, config: any)
	for _, player in ipairs(Players:GetPlayers()) do
		local root, humanoid = getCharacterRootAndHumanoid(player)
		if root and humanoid then
			local distance = (root.Position - originPosition).Magnitude
			if distance <= config.ExplosionRadius then
				humanoid:TakeDamage(config.ExplosionDamage)
			end
		end
	end
end

-- Resuelve un golpe válido: aplica daño de contacto + el
-- comportamiento exclusivo del tipo (veneno/explosión), respetando
-- el cooldown de ataque. Devuelve el nuevo `lastAttackAt` (sin
-- cambios si todavía estaba en cooldown o el target ya no es
-- válido).
local function tryAttack(
	zombieId: Types.ZombieId,
	rootPart: BasePart,
	config: any,
	target: Player,
	lastAttackAt: number
): number
	local now = os.clock()
	if (now - lastAttackAt) < config.AttackCooldownSeconds then
		return lastAttackAt
	end

	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return now
	end

	humanoid:TakeDamage(config.Damage)

	if config.PoisonDamagePerTick then
		applyPoison(target, config)
	end

	if config.ExplosionRadius then
		triggerExplosion(rootPart.Position, config)
		-- Autodestrucción: una sola explosión por Explosive. KillZombie
		-- pone Health = 0, que dispara Humanoid.Died -> ZombieService
		-- limpia todo por su cuenta (ver removeZombie en ZombieService).
		zombieRef.KillZombie(zombieId)
	end

	return now
end

-- ============================================================
-- Pathfinding
-- ============================================================

local function computeWaypoints(config: any, fromPosition: Vector3, toPosition: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({
		AgentRadius = config.AgentRadius,
		AgentHeight = config.AgentHeight,
		AgentCanJump = true,
	})

	local ok = pcall(function()
		path:ComputeAsync(fromPosition, toPosition)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path:GetWaypoints()
end

-- Espera Humanoid.MoveToFinished con un timeout manual (polling
-- liviano cada 0.1s, solo mientras ESTE zombie se está moviendo a
-- ESTE waypoint puntual -- no es un Heartbeat global). Devuelve
-- false tanto si el timeout se cumplió (atascado) como si
-- MoveToFinished disparó con `reached = false`.
local function moveToAndWait(humanoid: Humanoid, position: Vector3, timeoutSeconds: number): boolean
	local finished = false
	local reachedGoal = false

	local connection: RBXScriptConnection
	connection = humanoid.MoveToFinished:Connect(function(reached: boolean)
		finished = true
		reachedGoal = reached
	end)

	humanoid:MoveTo(position)

	local elapsed = 0
	local pollInterval = 0.1
	while not finished and elapsed < timeoutSeconds and humanoid.Health > 0 do
		task.wait(pollInterval)
		elapsed += pollInterval
	end

	connection:Disconnect()
	return finished and reachedGoal
end

-- Recorre los waypoints de a uno. `isAborted` se re-chequea entre
-- cada waypoint (el zombie puede morir o el jugador desconectarse a
-- mitad de un desplazamiento largo). Devuelve true solo si llegó al
-- final del path completo sin atascarse ni abortar.
local function followWaypoints(humanoid: Humanoid, waypoints: { PathWaypoint }, isAborted: () -> boolean): boolean
	for _, waypoint in ipairs(waypoints) do
		if isAborted() then
			return false
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		local reached = moveToAndWait(humanoid, waypoint.Position, STUCK_TIMEOUT_SECONDS)
		if not reached then
			return false
		end
	end

	return true
end

-- ============================================================
-- Loop de IA por zombie
-- ============================================================

local function runAI(zombieId: Types.ZombieId, model: Model, humanoid: Humanoid, rootPart: BasePart, config: any, sm: StateMachine.StateMachine)
	local lastAttackAt = 0
	local lastPathComputedAt = 0
	local lastPathTargetPosition: Vector3? = nil

	local function isAlive(): boolean
		return humanoid.Health > 0 and model.Parent ~= nil
	end

	-- El loop reevalúa el mismo estado en cada vuelta (ej. sigue
	-- Chasing muchas iteraciones seguidas mientras persigue), pero
	-- `ALLOWED_AI_TRANSITIONS` no declara self-transiciones (Chasing
	-- -> Chasing, etc.) -- serían "transiciones" sin cambio real de
	-- estado. `transitionIfNeeded` evita pedirle a la StateMachine
	-- una transición inválida (y su warning) cuando el estado ya es
	-- el mismo.
	local function transitionIfNeeded(newState: string)
		if sm:GetState() ~= newState then
			sm:TransitionTo(newState)
		end
	end

	while isAlive() do
		transitionIfNeeded(ZombieAIState.Searching)

		local target, targetRoot = findNearestPlayer(rootPart.Position, config.DetectionRange)
		if not target or not targetRoot then
			transitionIfNeeded(ZombieAIState.Idle)
			task.wait(THINK_INTERVAL_SECONDS)
			continue
		end

		transitionIfNeeded(ZombieAIState.Chasing)

		-- Se mantiene la persecución mientras el target siga vivo,
		-- conectado y dentro del leash -- sin volver a escanear TODOS
		-- los jugadores en cada iteración (solo re-valida a ESTE
		-- target puntual, más barato).
		while isAlive() do
			local currentRoot, currentHumanoid = getCharacterRootAndHumanoid(target)
			if not currentRoot or not currentHumanoid then
				break -- el target murió/se desconectó: volver a buscar
			end

			local distance = (currentRoot.Position - rootPart.Position).Magnitude
			if distance > config.DetectionRange * LEASH_RANGE_MULTIPLIER then
				break -- se escapó demasiado lejos: soltar el objetivo
			end

			if distance <= config.AttackRange then
				transitionIfNeeded(ZombieAIState.Attacking)
				humanoid:MoveTo(rootPart.Position) -- deja de desplazarse mientras ataca
				lastAttackAt = tryAttack(zombieId, rootPart, config, target, lastAttackAt)

				if config.ExplosionRadius then
					-- El Explosive ya se autodestruyó dentro de
					-- tryAttack: el próximo isAlive() lo va a cortar,
					-- pero se corta el loop interno ya mismo para no
					-- esperar THINK_INTERVAL_SECONDS de más sobre un
					-- Model que puede estar destruyéndose.
					break
				end

				task.wait(THINK_INTERVAL_SECONDS)
			else
				transitionIfNeeded(ZombieAIState.Chasing)

				local needsRepath = (os.clock() - lastPathComputedAt) >= MIN_REPATH_INTERVAL_SECONDS
					or lastPathTargetPosition == nil
					or (currentRoot.Position - (lastPathTargetPosition :: Vector3)).Magnitude
						>= REPATH_DISTANCE_THRESHOLD_STUDS

				if needsRepath then
					lastPathComputedAt = os.clock()
					lastPathTargetPosition = currentRoot.Position

					local waypoints = computeWaypoints(config, rootPart.Position, currentRoot.Position)
					if not waypoints then
						task.wait(REPATH_RETRY_SECONDS)
					else
						local completed = followWaypoints(humanoid, waypoints, function()
							return not isAlive()
						end)
						if not completed then
							-- Atascado o el target se movió a mitad de
							-- camino: no recalcular en el acto, dejar
							-- que la vuelta normal del loop (con
							-- MIN_REPATH_INTERVAL_SECONDS ya vencido
							-- para la próxima iteración) decida.
							task.wait(REPATH_RETRY_SECONDS)
						end
					end
				else
					task.wait(THINK_INTERVAL_SECONDS)
				end
			end
		end
	end

	if sm:CanTransitionTo(ZombieAIState.Dead) then
		sm:TransitionTo(ZombieAIState.Dead)
	end
end

-- ============================================================
-- Reacciones a ZombieService
-- ============================================================

local function startAI(zombieId: Types.ZombieId, model: Model, zombieType: string)
	local config = ZombieConfig.Types[zombieType]
	if not config then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local rootPart = model.PrimaryPart
	if not humanoid or not rootPart then
		return
	end

	local trove = Trove.new()
	local sm = StateMachine.new(ZombieAIState.Idle, ALLOWED_AI_TRANSITIONS)
	trove:Add(function()
		sm:Destroy()
	end)

	aiByZombie[zombieId] = { Trove = trove }

	local thread = task.spawn(function()
		runAI(zombieId, model, humanoid, rootPart, config, sm)
	end)
	trove:Add(function()
		task.cancel(thread)
	end)
end

local function stopAI(zombieId: Types.ZombieId)
	local record = aiByZombie[zombieId]
	if not record then
		return
	end
	aiByZombie[zombieId] = nil
	record.Trove:Destroy()
end

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function ZombieAIService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
	zombieRef = registry.ZombieService
end

function ZombieAIService:Start()
	local globalTrove = cleanupRef.GetGlobalTrove()

	globalTrove:Add(zombieRef.ZombieSpawned:Connect(function(zombieId: Types.ZombieId, model: Model, zombieType: string)
		startAI(zombieId, model, zombieType)
	end))

	globalTrove:Add(zombieRef.ZombieRemoved:Connect(function(zombieId: Types.ZombieId)
		stopAI(zombieId)
	end))

	-- Cortar cualquier veneno activo sobre un jugador que se
	-- desconecta, para no dejar un `task.delay` recursivo colgado
	-- apuntando a un Character que ya no existe.
	globalTrove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		clearPoison(player)
	end))

	log("ZombieAIService listo.")
end

return ZombieAIService
