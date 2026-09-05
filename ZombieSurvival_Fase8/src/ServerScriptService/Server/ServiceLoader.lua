--!strict
--[[
	ServiceLoader.lua

	Carga e inicializa todos los servicios del servidor, en un orden
	de dependencia EXPLÍCITO (no se auto-descubren carpetas mágicamente,
	para que el orden sea siempre predecible y fácil de razonar).

	Cómo evita dependencias circulares:
	  Ningún módulo de Services/ hace `require` de otro servicio
	  directamente. En su lugar, cada servicio recibe un `registry`
	  (tabla { [nombre] = servicio }) en su método :Init(registry),
	  y accede a otros servicios vía registry.NombreDelServicio.
	  Como el registry se llena ANTES de llamar a :Init() en nadie,
	  cualquier servicio puede referenciar a cualquier otro sin
	  importar el orden de carga real de los `require`.

	Ciclo de carga:
	  1. Se hace `require` de todos los módulos de servicio (orden
	     de la lista ORDERED_SERVICES).
	  2. Se registran todos en `registry` ANTES de inicializar a
	     ninguno.
	  3. Se llama :Init(registry) a cada uno, en orden.
	  4. Se llama :Start() a cada uno, en orden, recién cuando TODOS
	     terminaron Init.
]]

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

local Services = script.Parent.Services

-- Orden de inicialización. Los servicios más "básicos" (config,
-- logging) van primero para que el resto pueda loguear/leer config
-- desde su propio :Init().
local ORDERED_SERVICE_MODULES = {
	Services.ConfigurationService,
	Services.DebugService,
	Services.CleanupService,
	-- Fase 5: no depende de RemoteService (no crea remotes todavía),
	-- pero sí de CleanupService (respawn de nodos vía Trove global).
	-- Se carga acá, junto al resto de infraestructura de mundo/datos.
	Services.ResourceService,
	-- Fase 8: mismo motivo que ResourceService -- escanea una carpeta
	-- de Workspace.WorldMap (ZombieSpawnPoints) al arrancar y solo
	-- depende de CleanupService (limpieza global de zombies vivos al
	-- cerrar el servidor). No depende de RemoteService: no crea
	-- remotes esta fase.
	Services.ZombieService,
	Services.RemoteService,
	Services.PartyService,
	Services.PlayerDataService,
	-- Fase 7: InventoryService depende de PlayerDataService (opera
	-- sobre PlayerData.InventorySlots); EquipmentService depende de
	-- InventoryService (mueve objetos hacia/desde la mochila) y de
	-- PlayerDataService (PlayerData.Equipment); WeaponService depende
	-- de EquipmentService (necesita saber qué arma está equipada en
	-- cada slot para llevar su munición). Se cargan en ese orden,
	-- antes de ToolService/CombatService, que son quienes las
	-- consumen.
	Services.InventoryService,
	Services.EquipmentService,
	Services.WeaponService,
	Services.MatchService,
	-- Fase 6: depende de RemoteService (crea sus remotes),
	-- ResourceService (ExtractResource), InventoryService (AddItem,
	-- Fase 7 reemplaza a PlayerDataService.AddResource) y
	-- EquipmentService (Fase 7: qué herramienta está equipada) — se
	-- carga después de las cuatro.
	Services.ToolService,
	-- Fase 7: depende de RemoteService, EquipmentService (qué arma
	-- está equipada en cada slot) y WeaponService (munición/recarga)
	-- — se carga al final porque es quien consume a las tres.
	Services.CombatService,
	-- Fase 8: ZombieAIService depende de ZombieService (se suscribe a
	-- ZombieSpawned/ZombieRemoved) y CleanupService. WaveService
	-- depende de ZombieService (SpawnZombie/DespawnZombie),
	-- MatchService (StateChanged: cuándo arrancar/frenar rondas) y
	-- PartyService (PartyChanged: frenar rondas si la Party se
	-- destruye a mitad de InProgress, ver nota de cabecera de
	-- WaveService.lua). Se cargan al final porque son quienes
	-- consumen al resto, no porque el ServiceLoader lo requiera
	-- funcionalmente (el registry ya está completo para cuando
	-- corre CUALQUIER :Init()).
	Services.ZombieAIService,
	Services.WaveService,
}

local ServiceLoader = {}

function ServiceLoader.LoadAll(): Types.ServiceRegistry
	local registry: Types.ServiceRegistry = {}

	-- Paso 1 y 2: require + registro, sin ejecutar lógica todavía.
	local orderedServices: { Types.Service } = {}
	for _, moduleScript in ipairs(ORDERED_SERVICE_MODULES) do
		local ok, serviceOrError = pcall(require, moduleScript)
		if not ok then
			error(string.format("[ServiceLoader] Falló require de %s: %s", moduleScript.Name, tostring(serviceOrError)))
		end

		local service = serviceOrError :: Types.Service
		if registry[service.Name] then
			error("[ServiceLoader] Nombre de servicio duplicado: " .. service.Name)
		end

		registry[service.Name] = service
		table.insert(orderedServices, service)
	end

	-- Paso 3: Init en orden.
	for _, service in ipairs(orderedServices) do
		local ok, err = pcall(function()
			service:Init(registry)
		end)
		if not ok then
			error(string.format("[ServiceLoader] Falló Init de %s: %s", service.Name, tostring(err)))
		end
	end

	-- Paso 4: Start en orden, recién con todos ya inicializados.
	for _, service in ipairs(orderedServices) do
		local ok, err = pcall(function()
			service:Start()
		end)
		if not ok then
			error(string.format("[ServiceLoader] Falló Start de %s: %s", service.Name, tostring(err)))
		end
	end

	return registry
end

return ServiceLoader
