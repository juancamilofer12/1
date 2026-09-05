--!strict
--[[
	ZombieService.lua

	Responsabilidad: ser la única autoridad sobre la existencia de
	los zombies del servidor. Fase 8 del proyecto.

	Qué hace esta fase:
	- Escanea `Workspace.WorldMap.ZombieSpawnPoints` (Fase 4) al
	  arrancar y guarda cada punto con su Attribute `Ring`, igual
	  filosofía de escaneo que `ResourceService` con `ResourceNodes`.
	- Expone `SpawnZombie(zombieType, options)`: valida el tipo contra
	  `ZombieConfig.Types`, hace cumplir el techo defensivo
	  `ZombieConfig.MaxConcurrentZombies`, elige un spawn point
	  filtrado por `options.MaxRing`, arma un rig placeholder
	  (`Model` + `Humanoid` + Parts primitivas coloreadas por tipo,
	  ver `buildZombieRig`) y lo taguea `Combatable`
	  (`CollectionService`) para que `CombatService` (Fase 7) lo
	  reconozca como objetivo válido de inmediato, sin ningún cambio
	  en ese archivo -- exactamente la integración que la Fase 7 dejó
	  documentada como pendiente.
	- Expone `DespawnZombie`/`KillZombie` para remoción forzada
	  (limpieza de ronda/servidor) vs. muerte real (`Humanoid.Died`),
	  y el Signal unificado `ZombieRemoved` para que cualquier
	  consumidor (`ZombieAIService`, `WaveService`) reaccione a "este
	  zombie ya no existe" sin importar la causa.

	Qué NO hace esta fase (restricción explícita de la Fase 8):
	- No decide CUÁNTOS zombies ni de qué tipo aparecen en una ronda
	  puntual -- eso es `WaveConfig`/`WaveService`. Este servicio solo
	  sabe spawnear UN zombie de un tipo dado cuando alguien se lo
	  pide, y hacer cumplir el límite global de seguridad.
	- No tiene IA ni pathfinding -- eso es `ZombieAIService`, que
	  reacciona a `ZombieSpawned`/`ZombieRemoved` sin que este archivo
	  necesite saber que existe.
	- No crea remotes ni replica nada al cliente más allá de lo que
	  Roblox replica solo (posición/apariencia de los Models en
	  Workspace) -- mismo criterio que `ResourceService` en la Fase 5.

	Rig placeholder (ver `buildZombieRig`): igual filosofía que
	`ResourceNodes` en la Fase 5 -- geometría primitiva simple
	(`HumanoidRootPart` invisible + `Torso`/`Head` coloreados por
	tipo, unidos con `WeldConstraint`), sin animaciones ni asset
	externo, lista para reemplazo por un rig real de Creator Store
	(ver `WORLD_MAP_DESIGN.md` sección 13 -- ningún Free Model se
	integra automáticamente) sin que `ZombieAIService`/`WaveService`/
	`CombatService` necesiten cambiar: todos operan sobre
	`Model`+`Humanoid`, nunca sobre la forma interna del rig.
]]

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local Signal = require(ReplicatedStorage.Shared.Utils.Signal)
local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local ZombieService = {}
ZombieService.Name = "ZombieService" :: string

-- Mismo tag que CombatService.lua ya espera desde la Fase 7. Se
-- repite el literal acá a propósito (no un require cruzado a
-- CombatService, que rompería la regla de "ningún servicio requiere
-- a otro" del ServiceLoader): ambos archivos documentan por qué el
-- valor tiene que coincidir.
local COMBATABLE_TAG = "Combatable"

type SpawnPointEntry = {
	Instance: BasePart,
	Ring: number,
}

type ZombieOptions = {
	MaxRing: number?,
	HealthMultiplier: number?,
	SpeedMultiplier: number?,
}

type ZombieInternal = {
	Model: Model,
	Humanoid: Humanoid,
	ZombieType: Types.ZombieTypeId,
	DiedConnection: RBXScriptConnection?,
}

local zombies: { [Types.ZombieId]: ZombieInternal } = {}
local spawnPoints: { SpawnPointEntry } = {}
local zombiesFolder: Folder? = nil

local debugRef: any = nil
local cleanupRef: any = nil

-- Fase de hordas (esta) y cualquier consumidor futuro (loot al
-- morir, estadísticas) se suscriben a estos en vez de hacer polling.
-- Mismo patrón que ResourceService.NodeStateChanged.
local ZombieSpawned = Signal.new()
local ZombieRemoved = Signal.new()

local function log(message: string)
	if debugRef then
		debugRef:Info("ZombieService", message)
	end
end

local function logWarn(message: string)
	if debugRef then
		debugRef:Warn("ZombieService", message)
	end
end

-- ============================================================
-- Construcción del rig placeholder
-- ============================================================

-- Arma un `Model` mínimo válido para Humanoid + PathfindingService:
-- `HumanoidRootPart` (invisible, sin colisión, es el PrimaryPart y
-- el que realmente carga la física) + `Torso`/`Head` (visibles,
-- coloreados por tipo, `Massless` para no duplicar masa con el root
-- con el que están co-ubicados). No incluye brazos/piernas: no hace
-- falta ninguna pose ni animación para que Humanoid:MoveTo() y
-- PathfindingService funcionen, y agregar más Parts solo aumentaría
-- el costo de física por zombie sin ganancia de gameplay en esta fase.
local function buildZombieRig(
	zombieType: Types.ZombieTypeId,
	config: any,
	healthMultiplier: number,
	speedMultiplier: number,
	spawnPosition: Vector3
): (Model, Humanoid)
	local model = Instance.new("Model")
	model.Name = zombieType

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Anchored = false
	rootPart.CFrame = CFrame.new(spawnPosition)
	rootPart.Parent = model

	local transparency = config.Transparency or 0

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = config.Size
	torso.Color = config.Color
	torso.Material = Enum.Material.SmoothPlastic
	torso.Transparency = transparency
	torso.CanCollide = true
	torso.Massless = true
	torso.Anchored = false
	torso.CFrame = rootPart.CFrame
	torso.Parent = model

	local torsoWeld = Instance.new("WeldConstraint")
	torsoWeld.Part0 = rootPart
	torsoWeld.Part1 = torso
	torsoWeld.Parent = rootPart

	local headSize = math.max(config.Size.X, 1) * 0.8
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(headSize, headSize, headSize)
	head.Color = config.Color
	head.Material = Enum.Material.SmoothPlastic
	head.Transparency = transparency
	head.CanCollide = false
	head.Massless = true
	head.Anchored = false
	head.CFrame = rootPart.CFrame * CFrame.new(0, config.Size.Y / 2 + headSize / 2, 0)
	head.Parent = model

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = rootPart
	headWeld.Part1 = head
	headWeld.Parent = rootPart

	model.PrimaryPart = rootPart

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayName = zombieType
	humanoid.MaxHealth = config.MaxHealth * healthMultiplier
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = config.WalkSpeed * speedMultiplier
	humanoid.Parent = model

	if config.CanClimb then
		-- Exclusivo Climber. Ver nota de cabecera de ZombieConfig.lua
		-- sobre por qué esto no tiene efecto visible todavía (no hay
		-- terreno escalable en el mapa a la fecha de esta fase).
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	end

	return model, humanoid
end

-- ============================================================
-- Spawn points
-- ============================================================

local function getOrCreateZombiesFolder(): Folder
	local existing = Workspace:FindFirstChild("Zombies")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "Zombies"
	folder.Parent = Workspace
	return folder
end

local function scanSpawnPoints()
	local worldMap = Workspace:FindFirstChild("WorldMap")
	local folder = worldMap and worldMap:FindFirstChild("ZombieSpawnPoints")

	if not folder then
		logWarn("No se encontró Workspace.WorldMap.ZombieSpawnPoints. ZombieService arranca sin puntos de spawn.")
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not child:IsA("BasePart") then
			continue
		end

		local ring = child:GetAttribute("Ring")
		if type(ring) ~= "number" then
			logWarn(string.format("%s no tiene un Attribute Ring numérico, se ignora como spawn point.", child:GetFullName()))
			continue
		end

		table.insert(spawnPoints, { Instance = child, Ring = ring })
	end

	log(string.format("%d puntos de spawn de zombies registrados.", #spawnPoints))
end

-- Elige un spawn point al azar entre los de anillo <= maxRing. Si el
-- filtro no deja ningún candidato (config inconsistente, o el
-- folder está vacío para ese anillo puntual), cae de forma
-- defensiva a cualquier spawn point conocido en vez de fallar el
-- spawn completo -- un spawn en el anillo "equivocado" es preferible
-- a que la ronda entera se trabe sin poder spawnear nada.
local function pickSpawnPoint(maxRing: number): BasePart?
	local candidates: { BasePart } = {}
	for _, point in ipairs(spawnPoints) do
		if point.Ring <= maxRing then
			table.insert(candidates, point.Instance)
		end
	end

	if #candidates == 0 then
		for _, point in ipairs(spawnPoints) do
			table.insert(candidates, point.Instance)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

-- ============================================================
-- Remoción (muerte real o despawn forzado) -- único punto de salida
-- ============================================================

-- Único lugar que borra una entrada de `zombies` y destruye su
-- Model, sin importar si vino de Humanoid.Died (reason = "Died") o
-- de una remoción forzada (DespawnZombie/cierre de servidor). Evita
-- duplicar la lógica de limpieza (desconectar Died, sacar el tag,
-- destruir el Model) en dos lugares distintos.
local function removeZombie(zombieId: Types.ZombieId, reason: string)
	local record = zombies[zombieId]
	if not record then
		return
	end
	zombies[zombieId] = nil

	if record.DiedConnection then
		record.DiedConnection:Disconnect()
	end

	if record.Model.Parent then
		CollectionService:RemoveTag(record.Model, COMBATABLE_TAG)
	end

	-- Se dispara ANTES de Destroy: Signal:Fire ejecuta los listeners
	-- de forma síncrona (ver Signal.lua), así que ZombieAIService/
	-- WaveService reciben el Model todavía válido (posición,
	-- Attributes) en el mismo instante en que se marca como removido.
	ZombieRemoved:Fire(zombieId, record.Model, record.ZombieType, reason)

	if record.Model.Parent then
		record.Model:Destroy()
	end
end

-- ============================================================
-- API pública
-- ============================================================

function ZombieService.SpawnZombie(zombieType: string, options: ZombieOptions?): Types.ZombieSpawnResult
	local config = ZombieConfig.Types[zombieType]
	if not config then
		return { Ok = false, Error = "InvalidZombieType" }
	end

	local activeCount = 0
	for _ in pairs(zombies) do
		activeCount += 1
	end
	if activeCount >= ZombieConfig.MaxConcurrentZombies then
		return { Ok = false, Error = "MaxConcurrentZombiesReached" }
	end

	local opts: ZombieOptions = options or {}
	local maxRing = opts.MaxRing or 3
	local healthMultiplier = opts.HealthMultiplier or 1
	local speedMultiplier = opts.SpeedMultiplier or 1

	local spawnPointInstance = pickSpawnPoint(maxRing)
	if not spawnPointInstance then
		return { Ok = false, Error = "NoSpawnPointsAvailable" }
	end

	-- Offset vertical: el spawn point es un marcador plano (mismo
	-- criterio que PlayerSpawnPoints/PointsOfInterest en la Fase 4);
	-- levantar un poco al zombie evita que nazca enterrado a medias
	-- en el terreno placeholder antes de que la física lo asiente.
	local spawnPosition = spawnPointInstance.Position + Vector3.new(0, 3, 0)

	local model, humanoid = buildZombieRig(zombieType :: Types.ZombieTypeId, config, healthMultiplier, speedMultiplier, spawnPosition)

	local zombieId = zombieType .. "_" .. HttpService:GenerateGUID(false)
	model.Name = zombieId

	CollectionService:AddTag(model, COMBATABLE_TAG)

	local record: ZombieInternal = {
		Model = model,
		Humanoid = humanoid,
		ZombieType = zombieType :: Types.ZombieTypeId,
		DiedConnection = nil,
	}
	zombies[zombieId] = record

	model.Parent = zombiesFolder

	record.DiedConnection = humanoid.Died:Connect(function()
		removeZombie(zombieId, "Died")
	end)

	log(string.format("Zombie %s spawneado en %s (Anillo <= %d).", zombieId, spawnPointInstance:GetFullName(), maxRing))
	ZombieSpawned:Fire(zombieId, model, zombieType)

	return { Ok = true, ZombieId = zombieId, Model = model }
end

-- Remoción forzada sin pasar por Humanoid.Died (limpieza de ronda al
-- terminar una Match con zombies todavía vivos, o cierre de
-- servidor). `reason` por defecto "Despawned" para distinguirlo de
-- una muerte real en logs/estadísticas futuras.
function ZombieService.DespawnZombie(zombieId: Types.ZombieId, reason: string?): boolean
	if not zombies[zombieId] then
		return false
	end
	removeZombie(zombieId, reason or "Despawned")
	return true
end

-- Fuerza la muerte "real" de un zombie (ej. autodestrucción de un
-- Explosive al atacar, ver ZombieAIService). Deja que el propio
-- Humanoid.Died dispare la limpieza -- no se llama a removeZombie
-- directamente acá para no duplicar el camino de salida.
function ZombieService.KillZombie(zombieId: Types.ZombieId)
	local record = zombies[zombieId]
	if not record or record.Humanoid.Health <= 0 then
		return
	end
	record.Humanoid.Health = 0
end

function ZombieService.GetActiveCount(): number
	local count = 0
	for _ in pairs(zombies) do
		count += 1
	end
	return count
end

function ZombieService.GetZombieInfo(zombieId: Types.ZombieId): Types.ZombieInfo?
	local record = zombies[zombieId]
	if not record then
		return nil
	end
	return {
		ZombieId = zombieId,
		ZombieType = record.ZombieType,
		Health = record.Humanoid.Health,
		MaxHealth = record.Humanoid.MaxHealth,
	}
end

function ZombieService.GetAllActiveZombieIds(): { Types.ZombieId }
	local ids = {}
	for zombieId in pairs(zombies) do
		table.insert(ids, zombieId)
	end
	return ids
end

ZombieService.ZombieSpawned = ZombieSpawned
ZombieService.ZombieRemoved = ZombieRemoved

-- ============================================================
-- Ciclo de vida del servicio
-- ============================================================

function ZombieService:Init(registry: Types.ServiceRegistry)
	debugRef = registry.DebugService
	cleanupRef = registry.CleanupService
end

function ZombieService:Start()
	zombiesFolder = getOrCreateZombiesFolder()
	scanSpawnPoints()

	-- Al cerrar el servidor, remover prolijamente cada zombie vivo
	-- (dispara ZombieRemoved para quien esté escuchando) en vez de
	-- confiar en que Roblox destruya todo sin avisar a nadie.
	cleanupRef.GetGlobalTrove():Add(function()
		for zombieId in pairs(zombies) do
			removeZombie(zombieId, "ServerShutdown")
		end
	end)

	log("ZombieService listo.")
end

return ZombieService
