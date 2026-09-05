# ZombieSurvival

- **Fase 1 — Arquitectura base**: infraestructura del proyecto
  (ServiceLoader, remotes, cleanup, logging, datos de jugador,
  máquina de estados de partida).
- **Fase 2 — Lobby y Party System**: grupos de 1 a 4 jugadores
  administrables desde el lobby, con UI básica de prueba.
- **Fase 3 — MatchService + Countdown**: el líder de una Party puede
  iniciar una partida real; el servidor valida todo, corre un
  countdown configurable y deja la Match preparada en `Preparation`.
- **Fase 4 — Mapa principal del mundo**: estructura física y
  organizativa de "El Claro Cercado" bajo `Workspace.WorldMap`,
  representada como datos (`.model.json` de Rojo), sin scripts
  nuevos ni sistemas de gameplay.
- **Fase 5 — Recursos y nodos de recursos**: `ResourceService`
  administra 22 nodos (`TreeNode`/`RockNode`/`MetalNode`/`ScrapNode`)
  bajo `Workspace.WorldMap.ResourceNodes`, con cantidad, estado y
  regeneración controlados enteramente por el servidor.
- **Fase 6 — Herramientas y tala/minería**: `ToolService` administra
  qué herramienta (hacha/pico) tiene equipada cada jugador y valida
  server-side cada golpe (distancia, herramienta correcta, cooldown,
  disponibilidad del nodo) antes de invocar
  `ResourceService.ExtractResource` y acreditar lo recolectado en un
  inventario temporal básico (`PlayerDataService.AddResource`).
- **Fase 7 — Armas, combate e inventario**: sistema modular de armas
  cuerpo a cuerpo y de fuego (`WeaponConfig`), combate autoritativo
  server-side (`CombatService`, munición/recarga en `WeaponService`)
  y mochila/equipamiento real con slots (`InventoryService`/
  `EquipmentService`, 10 slots + 5 slots de equipamiento), que
  reemplaza el inventario temporal de la Fase 6.
- **Fase 8 — Zombies, IA, pathfinding y rondas**: `ZombieService`
  spawnea 9 tipos de zombie (`ZombieConfig`) desde los
  `ZombieSpawnPoints` de la Fase 4 y los taguea `Combatable` de
  inmediato (el combate de la Fase 7 empieza a aplicar daño real sin
  ningún cambio en `CombatService`); `ZombieAIService` les da una
  máquina de estados (Idle/Searching/Chasing/Attacking/Dead) con
  pathfinding de intervalos controlados; `WaveService` controla
  rondas de dificultad progresiva (`WaveConfig`) con fases de
  Preparación/Oleada/Intermisión, ligadas al `InProgress` de cada
  Match.

**No hay construcción de bases ni economía de tiendas todavía** — eso
llega en fases posteriores. Desde la Fase 8, una Match en progreso
genera oleadas reales de zombies que persiguen y atacan a los
jugadores (algunos con comportamientos exclusivos: explosión en área,
veneno) mientras la dificultad escala ronda a ronda, y un jugador
puede matarlos con las armas/herramientas de las Fases 6-7 sin que
esos sistemas hayan necesitado ningún cambio.

## Cómo se abre en Roblox Studio

Este proyecto usa la convención de [Rojo](https://rojo.space/). Con
Rojo instalado: `rojo serve` y conectar desde el plugin de Studio, o
`rojo build -o ZombieSurvival.rbxlx` para generar un archivo de lugar.
`default.project.json` define cómo `src/` se mapea al DataModel.

## Árbol de carpetas

```
src/
├── ServerScriptService/Server/
│   ├── init.server.lua          Bootstrap: único punto de entrada del servidor
│   ├── ServiceLoader.lua        Carga/ordena/inicializa todos los servicios
│   └── Services/
│       ├── ConfigurationService.lua  Valida la configuración al arrancar
│       ├── DebugService.lua          Logging centralizado (DEBUG/INFO/WARN/ERROR)
│       ├── CleanupService.lua        Orquesta limpieza global y por-jugador
│       ├── RemoteService.lua         Crea y expone RemoteEvents/RemoteFunctions
│       ├── PartyService.lua          Fase 2: grupos de 1-4 jugadores en el lobby
│       ├── PlayerDataService.lua     Carga/guardado autoritativo (DataStoreService)
│       ├── MatchService.lua          Fase 3: Party -> Match, countdown, fases de partida
│       ├── ResourceService.lua       Fase 5: nodos de recursos, agotamiento y respawn
│       ├── ToolService.lua           Fase 6: herramienta equipada (vía EquipmentService) y validación de golpes
│       ├── InventoryService.lua      Fase 7: mochila con slots (agregar/mover/consumir, server-authoritative)
│       ├── EquipmentService.lua      Fase 7: 5 slots de equipamiento, gatea posesión real
│       ├── WeaponService.lua         Fase 7: munición/recarga de armas de fuego equipadas
│       ├── CombatService.lua         Fase 7: validación autoritativa de golpes/disparos
│       ├── ZombieService.lua         Fase 8: ciclo de vida de zombies, rig placeholder, tag Combatable
│       ├── ZombieAIService.lua       Fase 8: máquina de estados de IA + pathfinding por zombie
│       └── WaveService.lua           Fase 8: rondas (Preparación/Oleada/Intermisión), dificultad progresiva
│
├── ReplicatedStorage/Shared/
│   ├── Types.lua                 Contratos de tipos Luau (Service, PlayerData, MatchState, Party, ResourceNodeInfo...)
│   ├── Config/
│   │   ├── GameConfig.lua        Config general (nivel de logging)
│   │   ├── MatchConfig.lua       Fase 3: duraciones/tick de countdown, cooldown de Match_Start
│   │   ├── PartyConfig.lua       Fase 2: máximo de miembros, cooldown anti-spam
│   │   ├── PlayerDataConfig.lua  Nombre de DataStore, versión de esquema, reintentos
│   │   ├── RemotesConfig.lua     Única fuente de verdad: qué remotes existen
│   │   ├── ResourceConfig.lua    Fase 5: cantidad y tiempo de respawn por tipo de recurso
│   │   ├── ToolConfig.lua        Fase 6: daño, cooldown y alcance por herramienta
│   │   ├── WeaponConfig.lua      Fase 7: daño/cadencia/cargador/reserva/recarga/alcance/retroceso/rareza/precio por arma
│   │   ├── ItemConfig.lua        Fase 7: categoría/stackeo/consumible por ItemId (armas, herramientas, recursos, curación, utilidad)
│   │   ├── InventoryConfig.lua   Fase 7: capacidad de la mochila (10 slots) y kit inicial
│   │   ├── ZombieConfig.lua      Fase 8: estadísticas por tipo de zombie (9 tipos) + techo global concurrente
│   │   └── WaveConfig.lua        Fase 8: dificultad progresiva por ronda, desbloqueo de anillos/tipos especiales
│   ├── Enums/
│   │   ├── GameState.lua         Fases de partida (Lobby/Countdown/Preparation/InProgress/Ending/GameOver)
│   │   ├── ResourceType.lua      Fase 5: Wood/Stone/Metal/Scrap
│   │   ├── ToolType.lua          Fase 6: WoodcutterAxe/Pickaxe
│   │   ├── WeaponType.lua        Fase 7: Machete/BaseballBat/Pistol/Rifle
│   │   ├── WeaponKind.lua        Fase 7: Melee/Firearm
│   │   ├── ItemRarity.lua        Fase 7: Common/Uncommon/Rare/Epic
│   │   ├── ItemCategory.lua      Fase 7: Weapon/Tool/Resource/Healing/Utility
│   │   ├── EquipmentSlot.lua     Fase 7: PrimaryWeapon/SecondaryWeapon/Tool/Utility/Healing
│   │   ├── ConsumableType.lua    Fase 7: Bandage/Medkit
│   │   ├── UtilityItemType.lua   Fase 7: Flashlight (placeholder)
│   │   ├── ZombieType.lua        Fase 8: Normal/Runner/Brute/Giant/Explosive/Toxic/Climber/Stealth/Nightmare
│   │   ├── ZombieAIState.lua     Fase 8: Idle/Searching/Chasing/Attacking/Dead
│   │   └── RoundPhase.lua        Fase 8: Preparation/Wave/Intermission
│   ├── Net/
│   │   └── NetClient.lua         Acceso seguro a remotes desde el cliente
│   └── Utils/
│       ├── Signal.lua            Pub/sub propio (sin dependencias externas)
│       ├── Trove.lua             Gestor de limpieza de conexiones/instancias/tareas
│       ├── StateMachine.lua      Máquina de estados finita genérica (una instancia por Match)
│       └── TableUtils.lua        DeepCopy / DeepFreeze
│
├── StarterPlayer/StarterPlayerScripts/Client/
│   ├── init.client.lua           Bootstrap del cliente (Ping + InventoryClient/PartyUI/ToolClient/WeaponClient)
│   ├── Party/
│   │   └── PartyUI.lua           Fase 2/3: UI básica de prueba de Party + inicio de partida
│   ├── Tools/
│   │   └── ToolClient.lua        Fase 6: arnés de prueba (equipar herramienta vía mochila + golpear nodo)
│   ├── Weapons/
│   │   └── WeaponClient.lua      Fase 7: arnés de prueba (equipar arma, golpear/disparar/recargar/curar)
│   └── Inventory/
│       └── InventoryClient.lua   Fase 7: cache de cliente de mochila/equipamiento (Inventory_GetSnapshot)
│
└── Workspace/WorldMap/           Fase 4: mapa "El Claro Cercado" (solo datos, sin scripts)
    ├── Ground.model.json         Placa base única
    ├── Zones/                    Un anillo/zona por archivo (geometría placeholder real)
    │   ├── Ring0_CampamentoCentral.model.json
    │   ├── Ring1_BosqueCercano.model.json
    │   ├── Ring1_PuebloAbandonado.model.json
    │   ├── Ring2_BosqueProfundo.model.json
    │   ├── Ring2_CarreteraYPuente.model.json
    │   ├── Ring2_Aserradero.model.json
    │   ├── Ring3_Pantano.model.json
    │   ├── Ring3_Cantera.model.json
    │   └── Ring3_InstalacionMilitar.model.json
    ├── PlayerSpawnPoints.model.json   SpawnLocation reales, Anillo 0
    ├── ZombieSpawnPoints.model.json   Marcadores en bordes de zona (Attribute Ring)
    ├── PointsOfInterest.model.json    Marcadores + metadata (Ring/Riesgo/Funcion)
    ├── BuildZones.model.json          Marcadores + metadata (AptoParaConstruir)
    ├── LootZones.model.json           Marcadores + metadata (Rareza)
    ├── EventZones.model.json          Marcadores + metadata (TipoEvento)
    ├── BossZones.model.json           Marcadores + metadata (Boss)
    └── ResourceNodes.model.json       Fase 5: 22 nodos (Wood/Stone/Metal/Scrap), Attribute ResourceType
```

## Decisiones de arquitectura

- **Sin dependencias circulares**: ningún servicio hace `require` de
  otro servicio. Todos reciben un `registry` (tabla `{ [nombre] =
  servicio }`) en `:Init(registry)` y se comunican a través de él.
  `ServiceLoader` llena el registro completo *antes* de llamar a
  `Init` en cualquiera, y llama a `Start` recién cuando *todos*
  terminaron `Init`.
- **Server-authoritative**: `PlayerDataService` guarda los datos en
  el servidor vía `DataStoreService`; el cliente nunca los escribe
  directamente. `RemoteService` es el único lugar que crea remotes,
  y cualquier `OnServerEvent/OnServerInvoke` que se conecte en el
  futuro debe validar los datos recibidos del cliente.
- **Sin script gigantesco**: cada responsabilidad vive en su propio
  módulo pequeño y con un nombre claro.
- **Cleanup correcto**: `Trove.lua` (utilidad genérica) +
  `CleanupService.lua` (orquestación) garantizan que conexiones e
  instancias se liberan al cerrarse el servidor o al irse un
  jugador, en vez de depender de que cada servicio recuerde
  desconectar todo manualmente.
- **Sin assets externos asumidos**: `Signal` y `Trove` son
  implementaciones propias en Luau puro (no se asume ningún paquete
  o modelo de Roblox preexistente). El único remote que existe hoy
  (`Ping`) es un health-check de infraestructura, no gameplay.
- **Config centralizada e inmutable**: todos los módulos de
  `Shared/Config` se congelan con `TableUtils.DeepFreeze` para que
  ningún script pueda mutarlos accidentalmente en runtime.

## Fase 2 — Party System

`PartyService` administra grupos de 1 a 4 jugadores antes de entrar
a una partida. Sigue exactamente los mismos patrones que el resto de
la Fase 1 (no introduce ninguno nuevo):

- **Server-authoritative**: toda la data (`Id`, `Leader`, `Members`)
  vive en memoria del servidor. El cliente solo recibe snapshots de
  solo lectura (`Types.PartyState`) vía el remote `Party_Updated` y
  nunca puede escribirlos directamente.
- **Remotes vía RemoteService**: `Party_Create`, `Party_Join`,
  `Party_Leave`, `Party_Kick`, `Party_TransferLeadership` (todas
  `RemoteFunction`, devuelven siempre `Types.PartyActionResult` con
  `Ok`/`Error`/`Party`) y `Party_Updated` (`RemoteEvent`, push del
  servidor al cliente). Declarados en `RemotesConfig`, igual que
  `Ping`; `PartyService` nunca crea instancias de remote por su
  cuenta.
- **Reglas server-side**: un jugador no puede estar en dos parties,
  unirse a una inexistente o llena, expulsar/transferir sin ser
  líder, ni expulsarse a sí mismo. Cada acción pasa por un rate
  limit (`PartyConfig.ActionCooldownSeconds`) para evitar spam de
  creación/join/leave.
- **Liderazgo y desconexiones**: si el líder abandona o se
  desconecta, el liderazgo pasa automáticamente al miembro más
  antiguo restante; si la party queda vacía, se destruye y se limpia
  toda referencia. `PlayerRemoving` se maneja igual que
  `MatchService` maneja su roster: conectado directamente sobre
  `CleanupService.GetGlobalTrove()`.
- **UI de prueba**: `Client/Party/PartyUI.lua` es intencionalmente
  básica (sin estética) — crear/unirse/abandonar/expulsar/transferir
  liderazgo, iniciar partida (Fase 3) y ver la lista de miembros y el
  estado de la Match en vivo.
- **Fuera de alcance de esta fase** (a propósito): listado/
  descubrimiento de parties existentes. La integración con
  `MatchService` (inicio de partida, countdown) se agregó en la
  Fase 3, ver más abajo.

## Fase 3 — MatchService + Countdown

`MatchService` conecta una Party puntual con una partida real. Una
Match nace de una Party (relación `Party -> Match`, como máximo una
Match activa por Party a la vez) cuando su líder la solicita — ya no
es un singleton de servidor que arranca solo, como en la Fase 1.

- **Server-authoritative, igual que Party**: el cliente solo pide
  iniciar partida vía el remote `Match_Start` (`RemoteFunction`,
  devuelve `Types.MatchActionResult`); nunca envía un `PartyId` ni un
  `MatchId` propio — el servidor deriva todo de la identidad del
  `Player` que invoca. Recibe el estado vía `Match_StateUpdated`
  (`RemoteEvent`, `Types.MatchState` completo en cada cambio de fase,
  o `nil` cuando la Match se cancela/termina) y `Match_CountdownUpdate`
  (`RemoteEvent`, tick liviano de `Types.MatchCountdownUpdate` cada
  `MatchConfig.CountdownTickInterval` segundos).
- **Validaciones de `Match_Start`**, en orden: el jugador existe y
  sigue conectado, pertenece a una Party, es su líder, la Party sigue
  existiendo, tiene al menos `MatchConfig.MinPlayersToStart`
  miembros, no hay ya una Match para esa Party, y todos los miembros
  siguen conectados. Además, un rate limit por jugador
  (`MatchConfig.StartMatchCooldownSeconds`) y el hecho de que el
  handler no hace ningún `yield` evitan que un doble click o un doble
  request creen dos Matches.
- **Fases** (reutilizando la `StateMachine` genérica existente, una
  instancia nueva por Match — no una máquina de estados nueva):
  `Lobby -> Countdown -> Preparation -> InProgress -> Ending ->
  GameOver`. Esta fase deja lista la transición hacia `InProgress`
  (vía `MatchService.RequestTransition`) pero no la dispara sola:
  todavía no hay gameplay real que decidir cuándo arrancar.
- **Countdown controlado por el servidor**: duración configurable en
  `MatchConfig.CountdownDuration` (nunca un número mágico dentro del
  servicio), tick en `MatchConfig.CountdownTickInterval`. Mientras
  dura, la Party queda bloqueada para nuevos miembros
  (`MatchService.IsPartyLocked`, consultado por `PartyService.JoinParty`
  — única fuente de verdad, no se duplica el estado) y no se puede
  volver a solicitar inicio (`MatchAlreadyExists`).
- **Abandonos y desconexiones**: `PartyService` expone un Signal
  (`PartyChanged`) que dispara en cada cambio o destrucción de una
  Party; `MatchService` lo escucha para reconciliar el roster de la
  Match (loguea `PlayerLeftMatch`) y cancelar/limpiar la Match entera
  si la Party queda vacía o se destruye, en cualquier fase.
- **Finalización mínima**: `MatchService.EndMatch` fuerza la
  transición a `Ending`; tras `MatchConfig.EndingDuration` segundos
  pasa sola a `GameOver`, donde se limpian conexiones/timers
  (`Trove` por-Match), se notifica a los clientes y se rompe la
  relación Party -> Match. La Party queda libre para iniciar una
  Match nueva — el equivalente práctico a "volver al Lobby" que pide
  esta fase (`GameOver -> Lobby` queda declarado en la máquina de
  estados para uso futuro, aunque esta fase no lo dispare).
- **Debug**: `MatchCreated`, `CountdownStarted`, `MatchStarted`,
  `PlayerLeftMatch`, `MatchEnded` y los cambios de fase genéricos se
  loguean vía `DebugService`.
- **Fuera de alcance de esta fase** (a propósito): zombies, armas,
  combate, inventario, construcción, recursos, economía, bosses,
  loot. `InProgress` existe como fase pero no ejecuta gameplay.

## Fase 4 — Mapa principal del mundo

Estructura física y organizativa del mapa "El Claro Cercado" bajo
`Workspace.WorldMap`, siguiendo `WORLD_MAP_DESIGN.md` (layout) y
`R6_VISUAL_DESIGN.md` (identidad visual). Ambos documentos viven en
la raíz del proyecto como referencia; ninguno crea sistemas de
gameplay por sí mismo.

- **Solo datos, sin scripts nuevos**: todo `Workspace.WorldMap` se
  define como árbol de `.model.json` mapeado vía Rojo
  (`default.project.json` → `Workspace.WorldMap` →
  `src/Workspace/WorldMap`). No hay ningún script que construya
  Parts en runtime — el layout es directamente editable en Studio y
  versionable en Git, igual que el resto del proyecto.
- **3 anillos de riesgo** (sección 1 de `WORLD_MAP_DESIGN.md`), cada
  uno como carpeta separada en `Zones/`: Anillo 0 (Campamento
  Central, zona segura), Anillo 1 (Bosque Cercano + Pueblo
  Abandonado), Anillo 2 (Bosque Profundo + Carretera/Puente +
  Aserradero), Anillo 3 (Pantano + Cantera + Instalación Militar).
  Cada zona lleva un `ZoneGround` (plate translúcida que marca su
  área) más un puñado de placeholders limpios de sus puntos de
  interés (cabaña, gasolinera, torre caída, aserradero, cantera,
  etc.) — geometría real pero mínima, nunca miles de Parts.
- **Carpetas de índice** (`PlayerSpawnPoints`, `ZombieSpawnPoints`,
  `PointsOfInterest`, `BuildZones`, `LootZones`, `EventZones`,
  `BossZones`) son *marcadores*, no una copia de la geometría de
  `Zones/`: Parts invisibles (`Transparency = 1`, `CanCollide =
  false`) posicionados sobre los lugares reales, con metadata como
  Attributes de Roblox (`Ring`, `Riesgo`, `Rareza`, `Funcion`,
  `AptoParaConstruir`, `TipoEvento`, `Boss`) en vez de nombres
  codificados a mano. `PlayerSpawnPoints` es la excepción: usa
  `SpawnLocation` reales en el Anillo 0, porque ya necesita
  comportamiento de spawn funcional.
- **Reglas de spawn de zombies** (sección 10 del documento de
  diseño) reflejadas en las posiciones de `ZombieSpawnPoints`: sin
  spawns propios en Anillo 0, densidad baja en Anillo 1 (bordes de
  bosque/pueblo, nunca en la calle principal), media en Anillo 2,
  alta en Anillo 3 — listos para que el futuro sistema de zombies
  los consuma vía `GetAttribute("Ring")`, sin necesidad de spawnear
  sobre el jugador.
- **Zonas de construcción** (`BuildZones`) marcan tanto los lugares
  buenos (Campamento Central, claros del Bosque Cercano, plataforma
  elevada del Aserradero) como los malos (Pantano, Cantera, Puente/
  Carretera, Bosque Profundo denso) con `AptoParaConstruir` como
  booleano — listo para que un futuro `BuildingService` lo consulte
  sin inventar reglas nuevas.
- **Fuera de alcance de esta fase** (a propósito, igual que Fases
  1-3): zombies, IA, pathfinding, armas, combate, inventario,
  construcción real, recursos, tala, economía, loot funcional,
  bosses, ciclo día/noche. Todo eso son sistemas futuros que se
  enganchan sobre esta estructura, no algo que esta fase implemente.
- **Fases 1-3 intactas**: ningún archivo de `ServerScriptService`,
  `ReplicatedStorage` ni `StarterPlayer` se tocó; `default.project.json`
  solo ganó la entrada `Workspace.WorldMap`.

## Fase 5 — Recursos y nodos de recursos

Sistema base de recursos recolectables del mundo, server-authoritative
de punta a punta. Sigue las ubicaciones de la sección 5 de
`WORLD_MAP_DESIGN.md`.

- **`ResourceService`** (nuevo, sumado a `ORDERED_SERVICE_MODULES`
  después de `CleanupService`): al arrancar escanea
  `Workspace.WorldMap.ResourceNodes` y registra cada `Part` con un
  Attribute `ResourceType` válido como nodo administrado. Guarda
  cantidad actual/máxima y estado (`Available`/`Depleted`)
  **solo en memoria del servidor** — el cliente nunca escribe esto.
- **`ResourceConfig`** (nuevo, `Shared/Config/ResourceConfig.lua`):
  centraliza, por tipo de recurso, cuánto rinde un nodo lleno
  (`Amount`) y cuántos segundos tarda en regenerarse
  (`RespawnSeconds`). Validado al arrancar por `ConfigurationService`
  igual que el resto de los módulos de Config.
- **`ResourceType`** (nuevo, `Shared/Enums/ResourceType.lua`): enum
  con los 4 tipos de esta fase — `Wood`, `Stone`, `Metal`, `Scrap`.
- **22 nodos físicos** en `Workspace.WorldMap.ResourceNodes.model.json`,
  visibles (no son marcadores invisibles como `LootZones`, porque acá
  el propio nodo es el objeto recolectable): 8 `TreeNode` (Bosque
  Cercano + Bosque Profundo, secundario en Cabaña de Caza/Campamento
  de Supervivientes), 6 `RockNode` (Cantera principal, Aserradero y
  colinas del Bosque Profundo secundario), 4 `MetalNode` (Aserradero
  y vehículos de la carretera principal, secundario en Instalación
  Militar), 4 `ScrapNode` (Pueblo Abandonado, Gasolinera, Instalación
  Militar, Checkpoint — ubicación no tomada literalmente de
  `WORLD_MAP_DESIGN.md` sección 5, que no distingue metal de
  chatarra; decisión de diseño de esta fase, documentada en
  `PROJECT_MANIFEST.md`).
- **Agotamiento y respawn**: `ResourceService.ExtractResource(nodeId,
  amount)` resta recursos de un nodo, nunca deja `Amount` negativo, y
  al llegar a 0 lo oculta (`Transparency = 1`, `CanCollide = false`)
  y programa su regeneración con `task.delay`. El thread de ese
  `task.delay` se registra como función de limpieza en
  `CleanupService.GetGlobalTrove()` para cancelarse con `task.cancel`
  si el servidor cierra a mitad de la espera, en vez de dejarlo
  colgado.
- **Attributes replicados por conveniencia**: cada nodo expone
  `ResourceType`, `CurrentAmount` y `State` como Attributes de
  Roblox, actualizados en cada cambio — no es la fuente de verdad
  (la tabla interna del servicio lo es), pero permite inspeccionar
  el estado en Studio y deja el terreno listo para que un futuro
  HUD los lea por replicación normal, sin necesitar un remote nuevo
  todavía.
- **`ResourceService.NodeStateChanged`** (Signal, mismo patrón que
  `PartyService.PartyChanged`): se dispara en cada extracción,
  agotamiento y respawn. Pensado para que la Fase 6 (o un HUD futuro)
  reaccione sin que `ResourceService` necesite conocer nada de
  herramientas ni UI.
- **Fuera de alcance de esta fase** (a propósito): ningún sistema
  detecta a un jugador golpeando un nodo — `ExtractResource` existe y
  está probado, pero nada lo llama todavía. Eso, junto con hacha/pico
  y el daño real a recursos, es exclusivamente Fase 6. Tampoco hay
  zombies, IA, combate, inventario completo, construcción ni
  economía.
- **Sin remotes nuevos**: esta fase no necesita que el cliente pida
  nada — el agotamiento/respawn de un nodo se ve en todos los
  clientes por replicación normal de Workspace (Transparency/
  CanCollide) y de Attributes, igual que cualquier otro cambio de
  propiedad de un Part. `RemotesConfig` queda intacto.
- **Fases 1-4 intactas**: ningún archivo existente de
  `ServerScriptService/Services` (salvo la línea nueva en
  `ServiceLoader.lua` y `ConfigurationService.lua`), `Workspace/
  WorldMap` (solo se agregó el archivo nuevo `ResourceNodes.model.
  json`) ni `StarterPlayer` se modificó de otra forma.

## Fase 6 — Herramientas y tala/minería

Sistema de herramientas (hacha, pico) que conecta por primera vez la
acción de un jugador con `ResourceService.ExtractResource` (Fase 5),
server-authoritative de punta a punta.

- **`ToolService`** (nuevo, sumado a `ORDERED_SERVICE_MODULES` al
  final: depende de `RemoteService`, `ResourceService` y
  `PlayerDataService`): administra qué `ToolId` tiene equipada cada
  jugador (en memoria, por `UserId`) y valida cada pedido de golpe
  antes de tocar `ResourceService`.
- **`ToolConfig`** (nuevo, `Shared/Config/ToolConfig.lua`):
  `MaxHarvestDistance` (alcance máximo, un único valor global) y, por
  herramienta, `Damage` (recurso extraído por golpe, se pasa tal cual
  a `ExtractResource`), `CooldownSeconds` y `EffectiveAgainst` (lista
  de `ResourceType`). Validado al arrancar por `ConfigurationService`
  igual que el resto de los módulos de Config.
- **`ToolType`** (nuevo, `Shared/Enums/ToolType.lua`): enum con las 2
  herramientas de esta fase — `WoodcutterAxe`, `Pickaxe`.
- **Sin taxonomía de nodo nueva**: el pedido de la fase habla de
  `TreeNode`/`RockNode`/`MetalNode`, pero un nodo ya se identifica por
  su Attribute `ResourceType` (`Wood`/`Stone`/`Metal`/`Scrap`) desde
  la Fase 5. En vez de introducir una segunda clasificación paralela
  que podría desincronizarse de la primera, `ToolConfig.EffectiveAgainst`
  mapea directamente contra `ResourceType`: `WoodcutterAxe` ->
  `Wood`, `Pickaxe` -> `Stone`/`Metal`. Decisión documentada también
  en el propio `ToolConfig.lua`.
- **Remotes vía RemoteService**: `Tool_Equip` y `Tool_RequestHarvest`
  (ambos `RemoteFunction`, devuelven siempre `Types.ToolEquipResult` /
  `Types.HarvestResult` con `Ok`/`Error`/detalle, mismo criterio que
  `Party`/`Match`). No hay remote de "push" nuevo: el estado de un
  nodo ya se ve por replicación normal de Attributes desde la Fase 5.
  **(Superseded en la Fase 7: `Tool_Equip`/`Types.ToolEquipResult` se
  retiraron, ver sección de Fase 7 más abajo.)**
- **Validación de `Tool_RequestHarvest`, en el orden exacto que pide
  la fase**: (1) distancia entre el `HumanoidRootPart` del jugador y
  el nodo (`ToolConfig.MaxHarvestDistance`, la posición del nodo se
  lee directamente del `BasePart` en `Workspace.WorldMap.ResourceNodes`,
  sin que `ResourceService` necesite exponer un getter nuevo); (2) que
  la herramienta equipada esté en el `EffectiveAgainst` del
  `ResourceType` del nodo; (3) cooldown de la herramienta (rate limit
  por jugador — no por nodo — mismo patrón que
  `PartyService.checkRateLimit`, así que cambiar de herramienta nunca
  es una forma de saltarse el cooldown de la anterior); (4) que el
  nodo siga `Available` (`ResourceService.GetNode`). Recién si las
  cuatro pasan se llama a `ResourceService.ExtractResource(nodeId,
  toolConfig.Damage)`.
- **Equipar sin restricción de posesión todavía**: `Tool_Equip` deja
  que cualquier jugador equipe cualquier `ToolId` válido de
  `ToolConfig.Tools` — no hay inventario/mochila real que gatee qué
  herramientas "tiene" un jugador. Eso llega junto con el sistema de
  inventario completo de una fase posterior; documentado como
  decisión explícita en `ToolService.lua`.
  **(Superseded en la Fase 7: ahora sí gatea posesión real, ver más
  abajo.)**
- **Inventario temporal y básico** (`Types.PlayerData.Inventory`,
  `ResourceType -> cantidad`): `PlayerDataConfig.DefaultTemplate` y
  `Types.PlayerData` ganaron el campo `Inventory`;
  `PlayerDataService.AddResource(player, resourceType, amount)` es la
  única forma de escribirlo. `PlayerDataService.loadData` migra en
  caliente datos guardados antes de esta fase (sin `Inventory`) para
  que nunca llegue un `nil`. Explícitamente NO es el sistema de
  inventario/mochila completo (sin slots, sin peso, sin UI) que pide
  una fase posterior — es el mínimo indispensable para que
  `ExtractResource` tenga un destino server-authoritative mientras
  ese sistema no existe.
  **(Superseded en la Fase 7: `Inventory`/`AddResource` se retiraron,
  reemplazados por `InventorySlots`/`InventoryService.AddItem`, con
  migración automática de los datos viejos — ver más abajo.)**
- **`ToolService.HarvestPerformed`** (Signal, mismo patrón que
  `ResourceService.NodeStateChanged`/`PartyService.PartyChanged`): se
  dispara en cada golpe exitoso (`player`, `nodeId`, `resourceType`,
  `extracted`). Pensado para que un futuro HUD reaccione sin que
  `ToolService` necesite conocer nada de UI.
- **Arnés de prueba en el cliente** (`Client/Tools/ToolClient.lua`,
  mismo espíritu que `PartyUI`): teclas `1`/`2` equipan hacha/pico
  (`Tool_Equip`), `F` golpea el nodo `Available` más cercano dentro de
  rango (`Tool_RequestHarvest`). Sin UI visual, solo `print`/`warn`
  del resultado — el servidor sigue siendo la única autoridad sobre
  si el golpe es válido.
- **Fuera de alcance de esta fase** (a propósito): inventario/mochila
  general con UI avanzada (slots, peso, arrastrar-soltar) — el
  `Inventory` de esta fase es un mínimo temporal, no ese sistema.
  Tampoco zombies, combate contra entidades, construcción ni economía
  de tiendas.
- **Fases 1-5 intactas**: ningún archivo existente de
  `ServerScriptService/Services`, `Workspace/WorldMap` ni
  `Client/Party` se modificó de otra forma; los únicos archivos
  existentes tocados fueron `ServiceLoader.lua` (nueva entrada),
  `ConfigurationService.lua` (valida `ToolConfig`), `RemotesConfig.lua`
  (2 remotes nuevos), `Types.lua` (tipos nuevos + `PlayerData.Inventory`),
  `PlayerDataConfig.lua`/`PlayerDataService.lua` (`Inventory` +
  `AddResource` + migración) e `init.client.lua` (inicializa
  `ToolClient`).

## Fase 7 — Armas, combate e inventario

Sistema modular de armas (cuerpo a cuerpo y de fuego), combate
server-authoritative de punta a punta, y mochila/equipamiento real
con slots — reemplazando el inventario temporal y el equipar-sin-
gatear de la Fase 6.

- **`WeaponConfig`** (nuevo, `Shared/Config/WeaponConfig.lua`):
  centraliza `Damage`, `CooldownSeconds` (cadencia), `Range`,
  `Rarity`, `Price` para toda arma, y además `MagazineSize`,
  `StartingReserveAmmo`, `MaxReserveAmmo`, `ReloadSeconds`, `Recoil`
  para armas de fuego (`WeaponKind.Firearm`) — quedan `nil`, no `0`,
  en armas Melee para que un chequeo accidental falle ruidoso.
  `Recoil` es puramente un campo de datos: esta fase no simula
  precisión/dispersión de disparo. 4 armas: `Machete`/`BaseballBat`
  (Melee), `Pistol`/`Rifle` (Firearm). Validado al arrancar por
  `ConfigurationService`.
- **`ItemConfig`** (nuevo, `Shared/Config/ItemConfig.lua`): catálogo
  único de todo `ItemId` que la mochila sabe manejar (`Category`,
  `Stackable`, `MaxStack`, y `Consumable`/`HealAmount` para objetos de
  curación). Los `ItemId` de armas/herramientas/recursos son los
  mismos strings que `WeaponType`/`ToolType`/`ResourceType` ya
  definen — sin taxonomía nueva, mismo criterio que
  `ToolConfig.EffectiveAgainst` en la Fase 6.
- **`InventoryConfig`** (nuevo, `Shared/Config/InventoryConfig.lua`):
  `SlotCount = 10` y `StarterItems` (un `Machete` + 2 `Bandage`, para
  que un jugador nuevo tenga algo que probar sin economía/crafting).
- **`InventoryService`** (nuevo, depende de `PlayerDataService`):
  única autoridad sobre `PlayerData.InventorySlots`. `AddItem`
  (interno, no remote — lo llaman otros servicios del servidor, nunca
  el cliente directamente), `Inventory_Move` (mover/apilar/swap entre
  slots) e `Inventory_Consume` (objetos `Consumable`, cura
  `Humanoid.Health` topado en `MaxHealth`) como remotes.
  `RemoveFromSlot`/`PlaceInFirstEmptySlot` son API interna para
  `EquipmentService`.
- **`EquipmentService`** (nuevo, depende de `InventoryService`):
  única autoridad sobre `PlayerData.Equipment` (5 slots:
  `PrimaryWeapon`/`SecondaryWeapon`/`Tool`/`Utility`/`Healing`).
  `SLOT_ACCEPTS` mapea cada slot a la `ItemCategory` que acepta.
  `Inventory_Equip`/`Inventory_Unequip` (remotes) mueven un objeto
  entre mochila y equipamiento, con swap si el slot ya tenía algo.
  **Gatea posesión real**: no se puede equipar lo que no está en la
  mochila — cierra el pendiente que la Fase 6 dejó abierto a
  propósito. `GetEquippedItemId` es la lectura de solo-consulta que
  usan `ToolService`/`WeaponService`/`CombatService`.
- **`WeaponService`** (nuevo, depende de `EquipmentService`): estado
  de munición (cargador + reserva + recargando) por
  `(UserId, EquipmentSlotName)`, en memoria (no persistido —
  documentado el porqué: el inventario apila armas por `ItemId` sin
  instancia única, así que no hay dónde guardar munición por copia
  física de arma). Se re-arma solo con cargador lleno la primera vez
  que se consulta un slot, o si el arma equipada ahí cambió.
  `Weapon_RequestReload` (remote) recarga y marca un cooldown de
  `ReloadSeconds` durante el cual disparar/recargar de nuevo se
  rechaza.
- **`CombatService`** (nuevo, depende de `EquipmentService` y
  `WeaponService`): valida `Combat_MeleeAttack`/`Combat_RangedAttack`
  en el orden exacto que pide la fase — cooldown (por slot, no por
  arma ni global), munición disponible (solo ranged; se consume tanto
  si acierta como si erra, como un arma real), distancia máxima
  (`Range` del arma), validez del objetivo. Un objetivo válido es un
  `Model` con `Humanoid` vivo, distinto del propio personaje, y
  tagueado `Combatable` (`CollectionService`) — **ningún Instance del
  proyecto tiene ese tag todavía** (no hay zombies ni PvP habilitado),
  así que todo golpe/disparo hoy termina en `TargetNotCombatable`,
  mismo patrón que `ResourceService.ExtractResource` quedó listo en la
  Fase 5 sin que nada lo invocara hasta la Fase 6. La fase de hordas
  solo necesita `CollectionService:AddTag(zombieModel, "Combatable")`
  para que este pipeline empiece a aplicar daño real sin tocar este
  archivo.
- **`ToolService` se integra con el inventario real**: ya no mantiene
  su propia tabla `equippedTool` ni el remote `Tool_Equip` (retirado)
  — consulta `EquipmentService.GetEquippedItemId(player,
  EquipmentSlot.Tool)`, y acredita lo extraído con
  `InventoryService.AddItem` en vez del `PlayerDataService.AddResource`
  retirado.
- **Migración automática**: `PlayerDataService.loadData` detecta
  saves de antes de esta fase (sin `InventorySlots`) y migra el
  `Inventory` viejo (Fase 6) a la mochila real, repartiendo cada
  `ResourceType` en tantos slots como haga falta según su `MaxStack`;
  si la mochila se llena a mitad de camino, el resto se descarta y se
  loguea.
- **Remote de solo-lectura `Inventory_GetSnapshot`**: única excepción
  al criterio "cada acción devuelve su propio snapshot" — el cliente
  lo pide una vez al conectar (`InventoryClient.Init`) para saber qué
  tiene antes de poder pedir un `Equip`/`Move`/`Consume` con sentido.
- **Arnés de prueba en el cliente**: `InventoryClient.lua` (cache de
  mochila/equipamiento + helpers `Equip`/`Unequip`/`ConsumeFirst`),
  `WeaponClient.lua` (`3`/`4`/`5` equipan Machete/Pistol/Rifle, `E`
  golpea, `G` dispara, `R` recarga, `U` desequipa, `C` consume un
  vendaje — todo contra el jugador más cercano, ver nota sobre
  `TargetNotCombatable` arriba). `ToolClient.lua` se actualizó para
  equipar vía `InventoryClient.Equip` en vez de `Tool_Equip`.
- **Fuera de alcance de esta fase** (a propósito): spawns de zombies,
  IA, pathfinding (fase de hordas); construcción de bases y economía
  de tiendas externas.
- **Fases 1-6 intactas salvo lo documentado arriba**: los archivos
  existentes tocados fueron `ServiceLoader.lua` (4 entradas nuevas),
  `ConfigurationService.lua` (valida `WeaponConfig`/`ItemConfig`/
  `InventoryConfig`), `RemotesConfig.lua` (retira `Tool_Equip`, agrega
  8 remotes nuevos), `Types.lua` (tipos nuevos + `PlayerData.
  InventorySlots`/`Equipment` reemplazando `Inventory`),
  `PlayerDataConfig.lua`/`PlayerDataService.lua` (plantilla + kit
  inicial + migración), `ToolService.lua` (equipar vía
  `EquipmentService`, acreditar vía `InventoryService`),
  `ToolClient.lua`/`init.client.lua` (integración con
  `InventoryClient`/`WeaponClient`).

## Fase 8 — Zombies, IA, pathfinding y rondas

Tres servicios nuevos (`ServerScriptService/Server/Services/`,
sumados a `ORDERED_SERVICE_MODULES`: `ZombieService` junto a
`ResourceService` al principio; `ZombieAIService`/`WaveService` al
final, después de `CombatService`):

- **`ZombieService`** — única autoridad sobre la existencia de los
  zombies. Escanea `Workspace.WorldMap.ZombieSpawnPoints` (Fase 4) al
  arrancar. `SpawnZombie(zombieType, options)` valida el tipo contra
  `ZombieConfig.Types`, hace cumplir el techo defensivo
  `ZombieConfig.MaxConcurrentZombies` (60, independiente de cuántos
  zombies pida una ronda puntual), elige un spawn point filtrado por
  `options.MaxRing`, arma un rig placeholder (`Model` + `Humanoid` +
  `HumanoidRootPart` invisible + `Torso`/`Head` coloreados por tipo,
  unidos con `WeldConstraint` — misma filosofía que `ResourceNodes`
  en la Fase 5: geometría primitiva simple, lista para reemplazo por
  un rig real de Creator Store sin que ningún otro sistema cambie) y
  lo taguea `Combatable` (`CollectionService`) de inmediato — **el
  pipeline de combate de la Fase 7 empieza a aplicar daño real sin
  ningún cambio en `CombatService.lua`**, exactamente la integración
  que esa fase dejó documentada como pendiente. `DespawnZombie`/
  `KillZombie` cubren remoción forzada vs. muerte real; el Signal
  unificado `ZombieRemoved(zombieId, model, zombieType, reason)`
  avisa a cualquier consumidor sin importar la causa.
- **`ZombieAIService`** (depende de `ZombieService`) — máquina de
  estados de IA por zombie (`Idle`/`Searching`/`Chasing`/`Attacking`/
  `Dead`, una `StateMachine` por zombie igual que `MatchService` usa
  una por Match), reaccionando a `ZombieSpawned`/`ZombieRemoved` sin
  que `ZombieService` sepa que este servicio existe. Cada zombie
  corre en su propio hilo (`task.spawn`), nunca en un
  `RunService.Heartbeat` compartido. Pathfinding con intervalos
  controlados: `PathfindingService:CreatePath`+`ComputeAsync` solo se
  recalcula al entrar en `Chasing`, si el target se movió más de 6
  studs desde el último cálculo, o si el path anterior falló/se
  agotó — nunca una vez por frame. Atascos: espera
  `Humanoid.MoveToFinished` con timeout (4s); si no llega o el path
  falla, espera 1s antes de reintentar en vez de martillar
  `PathfindingService`. El ataque zombie -> jugador es directo
  (`Humanoid:TakeDamage`, cooldown propio por `ZombieConfig`) y NO
  pasa por `CombatService` (ese archivo valida acciones DEL JUGADOR —
  arma/munición/cooldown de arma — que un zombie no tiene).
  Comportamientos exclusivos: **Explosive** hace daño en área a todos
  los jugadores dentro de `ExplosionRadius` al golpear y se
  autodestruye (`ZombieService.KillZombie`); **Toxic** aplica una
  quemadura de veneno (daño periódico) que se REFRESCA si se reaplica
  antes de terminar, en vez de acumular stacks.
- **`WaveService`** (depende de `ZombieService`, `MatchService`,
  `PartyService`) — sub-ciclo de rondas (`RoundPhase`:
  Preparación -> Oleada -> Intermisión -> ronda siguiente) por
  `PartyId`, que arranca/frena escuchando
  `MatchService.StateChanged` (entra/sale de `GameState.InProgress`)
  y también `PartyService.PartyChanged` directamente, para cubrir el
  caso límite en el que `MatchService` remueve una Match sin pasar
  por una transición de fase (Party destruida a mitad de partida).
  `WaveConfig.GetDifficultyForRound(ronda, techo)` calcula cantidad
  de zombies + multiplicadores de salud/velocidad + anillo máximo de
  spawn para CUALQUIER ronda (sin techo de rondas); el tipo de cada
  zombie sale de un sorteo ponderado
  (`WaveConfig.GetAvailableZombieTypes`) sobre los tipos ya
  desbloqueados (`SpecialTypeUnlocks`: Normal/Runner desde la ronda
  1, el resto se va sumando hasta Nightmare en la ronda 10+). Los
  zombies de una oleada se spawnean de forma escalonada (
  `WaveConfig.SpawnIntervalSeconds`) en vez de todos en el mismo
  frame. El Signal `RoundStateChanged` (mismo criterio que
  `ResourceService.NodeStateChanged` en la Fase 5) queda listo para
  una futura UI/HUD, sin remote todavía.
- **Nuevos Enums/Config**: `ZombieType` (9 tipos), `ZombieAIState`,
  `RoundPhase`; `ZombieConfig` (estadísticas por tipo + techo global)
  y `WaveConfig` (dificultad progresiva, desbloqueo de anillos/tipos)
  — ambos validados por `ConfigurationService` igual que el resto de
  `Shared/Config`.
- **Fuera de alcance de esta fase** (a propósito): construcción de
  bases/barricadas/defensas, tiendas del lobby y economía avanzada.
- **Fases 1-7 intactas salvo lo documentado arriba**: los archivos
  existentes tocados fueron `ServiceLoader.lua` (3 entradas nuevas),
  `ConfigurationService.lua` (valida `ZombieConfig`/`WaveConfig`),
  `Types.lua` (tipos nuevos de la Fase 8, ninguno reemplaza algo
  existente). `CombatService.lua` **no se tocó** — el tag
  `Combatable` que `ZombieService` aplica es el mismo que esa fase ya
  esperaba.

## Cómo integrar una fase futura (ej. construcción de bases)

1. Si necesita estado de servidor propio, agregar un nuevo servicio
   en `Services/` y sumarlo a `ORDERED_SERVICE_MODULES` en
   `ServiceLoader.lua` (después de sus dependencias).
2. Si necesita comunicación cliente-servidor, agregar la definición
   en `RemotesConfig.Definitions` — `RemoteService` lo crea solo.
3. Si necesita reaccionar a cambios de fase de partida, escuchar
   `MatchService.StateChanged` (incluye `PartyId`) en vez de duplicar
   lógica de estado; para avanzar de fase, usar
   `MatchService.RequestTransition(partyId, nuevaFase)` en vez de
   tocar la `StateMachine` de la Match directamente.
4. Cualquier recurso por-jugador (conexiones, instancias en
   Workspace) debe registrarse en
   `CleanupService.GetPlayerTrove(player)` para limpiarse solo.

