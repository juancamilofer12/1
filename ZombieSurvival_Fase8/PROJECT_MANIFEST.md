# PROJECT_MANIFEST — ZombieSurvival

> Índice compacto del estado del proyecto. Sin código, sin
> descripciones largas — para eso está `README.md` y los propios
> archivos. Actualizar en cada fase, no reescribir desde cero.

## Fases completadas

- [x] Fase 1 — Arquitectura base (ServiceLoader, remotes, cleanup, logging, datos de jugador, máquina de estados).
- [x] Fase 2 — Lobby y Party System (`PartyService`).
- [x] Fase 3 — MatchService + Countdown (`Party -> Match`, fases de partida).
- [x] Fase 4 — Mapa principal del mundo ("El Claro Cercado").
- [x] Fase 5 — Recursos y nodos de recursos (`ResourceService`).
- [x] Fase 6 — Herramientas y tala/minería (`ToolService`).
- [x] Fase 7 — Armas, combate e inventario (`WeaponService`, `CombatService`, `InventoryService`, `EquipmentService`).
- [x] Fase 8 — Zombies, IA, pathfinding y rondas (`ZombieService`, `ZombieAIService`, `WaveService`).

## Fase 4 — resumen

**Estructura del mapa** (`Workspace.WorldMap`, datos vía `.model.json` + Rojo, sin scripts nuevos):

- `Ground` — placa base única.
- `Zones/` — geometría placeholder real, un anillo/zona por archivo:
  `Ring0_CampamentoCentral`, `Ring1_BosqueCercano`, `Ring1_PuebloAbandonado`,
  `Ring2_BosqueProfundo`, `Ring2_CarreteraYPuente`, `Ring2_Aserradero`,
  `Ring3_Pantano`, `Ring3_Cantera`, `Ring3_InstalacionMilitar`.
- Carpetas de índice (marcadores, sin duplicar geometría de `Zones/`):
  `PlayerSpawnPoints`, `ZombieSpawnPoints`, `PointsOfInterest`,
  `BuildZones`, `LootZones`, `EventZones`, `BossZones`.

**Zonas principales preparadas:** Campamento Central (Anillo 0);
Bosque Cercano, Pueblo Abandonado, Cabaña de Caza, Campamento de
Supervivientes, Gasolinera (Anillo 1); Bosque Profundo, Carretera,
Puente, Aserradero, Torre de observación caída (Anillo 2); Pantano,
Cantera, Instalación Militar en Ruinas (Anillo 3).

**Archivos nuevos:** `src/Workspace/WorldMap/**` (17 archivos
`.model.json`, ver `README.md` para el árbol completo). `WORLD_MAP_DESIGN.md`
y `R6_VISUAL_DESIGN.md` incorporados en la raíz del proyecto como
referencia de diseño.

**Decisiones importantes:**

- El mapa se representa como datos (`.model.json` de Rojo), no como
  un script que construye Parts en runtime — cumple "no scripts
  innecesarios" y hace el layout directamente editable/versionable.
- Las carpetas de índice son *marcadores* (`Part` invisible,
  `CanCollide = false`) posicionados sobre la geometría real de
  `Zones/`, no una copia de ella — evita duplicar Parts entre
  carpetas. `PlayerSpawnPoints` es la única excepción funcional: usa
  `SpawnLocation` reales (clase nativa de Roblox) en vez de marcadores
  inertes, porque necesita comportamiento real de spawn desde ya.
- `PointsOfInterest`, `LootZones`, `BuildZones`, `ZombieSpawnPoints`,
  `EventZones` y `BossZones` llevan metadata (`Ring`, `Riesgo`,
  `Rareza`, `Funcion`, `AptoParaConstruir`, etc.) como Attributes de
  Roblox, consultable con `GetAttribute` en vez de parsear nombres.
- ~121 instancias totales bajo `Workspace.WorldMap` (17 archivos
  `.model.json`, contados con Ground + Zones + marcadores) — sin
  bosque procedural, sin miles de Parts; pensado para reemplazo
  progresivo por assets del Creator Store (ver `WORLD_MAP_DESIGN.md`
  sección 13).
- El layout en el espacio (posiciones/distancias) respeta la
  estructura de 3 anillos concéntricos de `WORLD_MAP_DESIGN.md`
  sección 1 y las direcciones cardinales sugeridas en la sección 2
  (Bosque Cercano norte/oeste, Pueblo este, Bosque Profundo norte,
  Aserradero sur, Pantano sureste, Cantera oeste, Instalación Militar
  norte-lejano) — son coordenadas de placeholder, no medidas finales.
- No se implementó ningún sistema de gameplay (zombies, IA,
  pathfinding, rondas, combate, construcción, economía, loot,
  bosses, día/noche): solo la estructura y los lugares donde esos
  sistemas futuros van a enganchar.
- Fases 1–3 verificadas intactas: ningún archivo existente de
  `ServerScriptService`, `ReplicatedStorage` o `StarterPlayer` se
  modificó; `default.project.json` solo ganó la entrada nueva
  `Workspace.WorldMap`.

## Fase 5 — resumen

**`ResourceService`** (nuevo, `ServerScriptService/Server/Services/`):
autoridad de servidor sobre los nodos de recursos. Escanea
`Workspace.WorldMap.ResourceNodes` al arrancar, guarda cantidad/
estado en memoria, y expone `ExtractResource(nodeId, amount)`,
`GetNode(nodeId)`, `GetAllNodes()`, `GetNodesByType(resourceType)` y
la Signal `NodeStateChanged`. Sumado a `ORDERED_SERVICE_MODULES`
después de `CleanupService` (no depende de `RemoteService`: esta
fase no crea remotes).

**Archivos nuevos:**
- `src/ReplicatedStorage/Shared/Enums/ResourceType.lua` — enum
  `Wood`/`Stone`/`Metal`/`Scrap`.
- `src/ReplicatedStorage/Shared/Config/ResourceConfig.lua` —
  `Amount`/`RespawnSeconds` por tipo, congelado con
  `TableUtils.DeepFreeze`, validado por `ConfigurationService`.
- `src/ServerScriptService/Server/Services/ResourceService.lua`.
- `src/Workspace/WorldMap/ResourceNodes.model.json` — 22 nodos
  (8 `TreeNode`, 6 `RockNode`, 4 `MetalNode`, 4 `ScrapNode`), cada
  uno un `Part` visible con Attribute `ResourceType`.

**Archivos modificados:** `ServiceLoader.lua` (nueva entrada en
`ORDERED_SERVICE_MODULES`), `ConfigurationService.lua` (valida
`ResourceConfig.Nodes` y lo expone en `.Get()`), `Types.lua`
(`ResourceType`, `ResourceNodeState`, `ResourceNodeInfo`,
`ResourceExtractionResult`), `README.md`.

**Decisiones importantes:**

- **Ubicación de nodos siguiendo `WORLD_MAP_DESIGN.md` sección 5**:
  madera en Bosque Cercano/Profundo (+ Cabaña de Caza/Campamento de
  Supervivientes), piedra en Cantera (+ Aserradero/colinas del
  Bosque Profundo), metal en Aserradero/vehículos de carretera
  (+ Instalación Militar). **Chatarra (`ScrapNode`) es la excepción**:
  la sección 5 no distingue metal de chatarra como recursos
  separados, así que se ubicó por criterio propio en vehículos/ruinas
  abandonadas (Pueblo Abandonado, Gasolinera, Instalación Militar,
  Checkpoint) — coherente con la ambientación pero no una lectura
  literal del documento de diseño.
- **Nodos visibles, no marcadores invisibles**: a diferencia de
  `LootZones`/`PointsOfInterest` (Fase 4, marcadores abstractos con
  `Transparency = 1`), los nodos de recursos son el objeto
  recolectable en sí, así que se representan como `Part` visibles
  con color/material distintivo por tipo (placeholder simple, listo
  para reemplazo por assets del Creator Store según la guía de la
  sección 13 de `WORLD_MAP_DESIGN.md`). `CanCollide = false` en todos
  para no generar obstáculos de placeholder en un mapa todavía sin
  sistema de movimiento/colisión de gameplay real.
- **Sin remotes nuevos**: el agotamiento/respawn de un nodo se ve en
  todos los clientes por replicación normal de Workspace
  (Transparency/CanCollide) y de Attributes (`ResourceType`,
  `CurrentAmount`, `State`). No hizo falta tocar `RemoteService` ni
  `RemotesConfig` para esta fase.
- **Respawn con `task.delay` + `CleanupService`**: cada nodo agotado
  programa su regreso con `task.delay(RespawnSeconds, ...)`; el
  thread devuelto se cancela vía `task.cancel` registrado como
  función de limpieza en `CleanupService.GetGlobalTrove()`, para que
  un cierre de servidor a mitad de la espera no deje temporizadores
  colgados.
- **`ExtractResource` existe pero nada la llama todavía**: es la
  única forma en que un nodo pierde recursos, pensada explícitamente
  para que la Fase 6 (herramientas: hacha, pico, daño a recursos) la
  invoque directo. Esta fase la implementa y la deja lista, pero no
  conecta ningún input de jugador — cumple la restricción explícita
  de no tocar herramientas/golpes en la Fase 5.
- **Balanceo (`Amount`/`RespawnSeconds` en `ResourceConfig`) es
  placeholder**: no tiene sentido afinarlo sin la Fase 6 (cuánto
  extrae un golpe) ni el sistema de construcción/economía (cuánto se
  necesita), así que se dejaron valores razonables pero no
  definitivos, documentados como tales en el propio archivo.
- Fases 1–4 verificadas intactas salvo los dos cambios puntuales y
  documentados arriba (`ServiceLoader.lua`, `ConfigurationService.lua`);
  ningún otro archivo de `ServerScriptService`, `ReplicatedStorage`,
  `StarterPlayer` ni `Workspace/WorldMap` (fuera del archivo nuevo)
  se tocó.

## Próxima fase sugerida

Fase 6 — sistema de herramientas: hacha/pico, detección de golpe
sobre un `ResourceNode` (vía `Raycast` o `Touched` server-side) y
conexión real a `ResourceService.ExtractResource`. Alternativamente,
sistema de zombies básico (spawns reales desde `ZombieSpawnPoints`,
sin IA/combate todavía) si se prefiere avanzar por ese lado primero.
A decidir al arrancar la Fase 6.

## Fase 6 — resumen

**`ToolService`** (nuevo, `ServerScriptService/Server/Services/`,
sumado a `ORDERED_SERVICE_MODULES` al final): autoridad de servidor
sobre qué herramienta tiene equipada cada jugador (`UserId -> ToolId`,
en memoria) y sobre la validación de cada golpe contra un nodo.
Expone `EquipTool(player, toolId)`, `GetEquippedTool(player)`,
`RequestHarvest(player, nodeId)` y la Signal `HarvestPerformed`.

**Archivos nuevos:**
- `src/ReplicatedStorage/Shared/Enums/ToolType.lua` — enum
  `WoodcutterAxe`/`Pickaxe`.
- `src/ReplicatedStorage/Shared/Config/ToolConfig.lua` —
  `MaxHarvestDistance` global + `Damage`/`CooldownSeconds`/
  `EffectiveAgainst` por herramienta, congelado con
  `TableUtils.DeepFreeze`, validado por `ConfigurationService`.
- `src/ServerScriptService/Server/Services/ToolService.lua`.
- `src/StarterPlayer/StarterPlayerScripts/Client/Tools/ToolClient.lua`
  — arnés de prueba (teclas 1/2 equipar, F golpear el nodo `Available`
  más cercano en rango), mismo espíritu que `PartyUI`: sin estética,
  solo `print`/`warn` del resultado que devuelve el servidor.

**Archivos modificados:** `ServiceLoader.lua` (nueva entrada al
final, depende de `RemoteService`/`ResourceService`/
`PlayerDataService`), `ConfigurationService.lua` (valida `ToolConfig`
y lo expone en `.Get()`), `RemotesConfig.lua` (`Tool_Equip`,
`Tool_RequestHarvest`, ambas `RemoteFunction`), `Types.lua` (`ToolId`,
`ToolEquipResult`, `HarvestResult`, `PlayerData.Inventory`),
`PlayerDataConfig.lua` (`DefaultTemplate.Inventory = {}`),
`PlayerDataService.lua` (nueva función `AddResource`, y migración en
`loadData` para datos guardados antes de esta fase sin `Inventory`),
`init.client.lua` (inicializa `ToolClient`), `README.md`.

**Decisiones importantes:**

- **Sin taxonomía de nodo nueva**: el pedido de la fase nombra las
  herramientas como efectivas contra `TreeNode`/`RockNode`/`MetalNode`,
  pero esos nombres no existen en el proyecto — un nodo ya se
  identifica por su Attribute `ResourceType` (`Wood`/`Stone`/`Metal`/
  `Scrap`) desde la Fase 5, y los propios nodos en
  `ResourceNodes.model.json` se nombran `Tree_*`/etc. solo como
  convención de `Instance.Name` (=`NodeId`), no como un tipo
  clasificable aparte. En vez de introducir una segunda taxonomía de
  "tipo de nodo" que podría desincronizarse de `ResourceType`,
  `ToolConfig.EffectiveAgainst` mapea directamente contra
  `ResourceType`: `WoodcutterAxe` -> `Wood`, `Pickaxe` ->
  `Stone`/`Metal` (cubre tanto "RockNode" como "MetalNode" del pedido
  original con una sola herramienta, que es lo que la sección 5 de
  `WORLD_MAP_DESIGN.md` sugiere al no separar piedra/metal como
  actividades distintas — solo como recursos distintos).
- **Posición del nodo leída directamente de Workspace, no de un
  getter nuevo en `ResourceService`**: como el nodo ya es un `BasePart`
  público en `Workspace.WorldMap.ResourceNodes` nombrado por su
  `NodeId` (`ResourceService.registerNode` usa `instance.Name` como
  clave), `ToolService` lo busca ahí para la validación de distancia
  en vez de pedirle a `ResourceService` que exponga su posición. Deja
  a `ResourceService` sin cambios de esta fase (fuera de que
  `ExtractResource`, ya preparado desde la Fase 5, ahora sí tiene
  quién lo invoque).
- **Cooldown por jugador, no por nodo ni por herramienta**: un solo
  timestamp por `UserId` (`lastHarvestAt`), igual criterio que
  `PartyService.checkRateLimit`. Evita que cambiar de herramienta a
  mitad de golpe sea una forma de saltarse el cooldown de la anterior,
  y es la lectura más simple de "cooldown de uso de la herramienta"
  que pide la fase sin inventar un sistema de combos/stamina que nadie
  pidió todavía.
- **Equipar sin restricción de posesión**: `Tool_Equip` acepta
  cualquier `ToolId` válido de `ToolConfig.Tools` sin verificar que el
  jugador "tenga" esa herramienta — no existe todavía el concepto de
  poseer/desbloquear una herramienta (eso depende del inventario
  completo y, probablemente, de una futura economía/crafting). Se
  documenta como decisión explícita para que la fase que agregue
  inventario real sepa que tiene que venir a gatear esto.
- **Inventario temporal en `PlayerData`, no una estructura aparte**:
  se eligió extender `Types.PlayerData` con `Inventory: {[string]:
  number}` (ya persistido por el flujo existente de
  `PlayerDataService`) en vez de crear un servicio de inventario
  nuevo — la Fase 6 explícitamente prohíbe implementar el sistema de
  inventario/mochila completo, y una estructura en memoria aparte
  (no persistida) habría perdido los recursos recolectados en cada
  reinicio de servidor sin necesidad. `PlayerDataService.loadData`
  migra en caliente los datos guardados antes de esta fase (sin
  `Inventory`) rellenando `{}`, en vez de forzar un borrado de saves
  viejos.
- **Sin remote de "push" nuevo**: a diferencia de Party/Match, el
  estado de un nodo (agotado/disponible) ya se ve en todos los
  clientes por replicación normal de Attributes desde la Fase 5, así
  que `Tool_RequestHarvest` (RemoteFunction) es suficiente — el
  cliente ya sabe si un nodo sigue disponible mirando sus propios
  Attributes antes de pedir el golpe (ver `ToolClient.findNearestAvailableNode`),
  aunque el servidor igual vuelve a validarlo todo de forma
  independiente.
- **Orden de validación server-side sigue exactamente el pedido de la
  fase**: distancia -> herramienta correcta -> cooldown ->
  disponibilidad del nodo, en ese orden, antes de tocar
  `ResourceService.ExtractResource`. La búsqueda del nodo
  (`ResourceService.GetNode`) ocurre antes de las cuatro porque
  distancia y herramienta correcta dependen de sus datos
  (posición/`ResourceType`), pero no cuenta como un paso de validación
  de gameplay en sí.
- **`ToolClient` es arnés de prueba, no UI final**: sin estética, sin
  hotbar visual — teclado + `print`/`warn`, mismo criterio que
  `PartyUI` en la Fase 2. La elección de "nodo más cercano" es
  conveniencia de cliente (lee Attributes ya replicados); nunca
  reemplaza la validación server-side.
- Fases 1-5 verificadas intactas salvo los cambios puntuales y
  documentados arriba (`ServiceLoader.lua`, `ConfigurationService.lua`,
  `RemotesConfig.lua`, `Types.lua`, `PlayerDataConfig.lua`,
  `PlayerDataService.lua`, `init.client.lua`); ningún otro archivo de
  `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer` ni
  `Workspace/WorldMap` se tocó.

## Próxima fase sugerida

Fase 7 — sistema de inventario/mochila completo (slots, peso, UI de
arrastrar-soltar) que reemplace el `Inventory` temporal de la Fase 6
por el sistema real, y/o sistema de zombies básico (spawns reales
desde `ZombieSpawnPoints`, sin IA/combate todavía). También queda
pendiente decidir si `Tool_Equip` debería empezar a gatear qué
herramientas "tiene" un jugador una vez exista inventario real. A
decidir al arrancar la Fase 7.

## Fase 7 — resumen

**Servicios nuevos** (`ServerScriptService/Server/Services/`, sumados
a `ORDERED_SERVICE_MODULES` en orden de dependencia: `InventoryService`
-> `EquipmentService` -> `WeaponService` -> ... -> `ToolService` ->
`CombatService`):
- `InventoryService` — autoridad sobre `PlayerData.InventorySlots`
  (10 slots). `AddItem` (interno), `MoveItem`/`Inventory_Move`,
  `ConsumeItem`/`Inventory_Consume`, y `RemoveFromSlot`/
  `PlaceInFirstEmptySlot` (API interna para `EquipmentService`).
- `EquipmentService` — autoridad sobre `PlayerData.Equipment` (5
  slots: `PrimaryWeapon`/`SecondaryWeapon`/`Tool`/`Utility`/
  `Healing`). `EquipFromInventorySlot`/`Inventory_Equip`,
  `UnequipToInventory`/`Inventory_Unequip`, `GetEquippedItemId`
  (lectura interna). `SLOT_ACCEPTS` mapea slot -> `ItemCategory`.
- `WeaponService` — munición (cargador/reserva/recargando) por
  `(UserId, EquipmentSlotName)`, en memoria (no persistido, decisión
  documentada: sin instancias únicas de arma en el inventario de esta
  fase, no hay dónde guardar munición por copia física). Se re-arma
  sola con cargador lleno al primer uso o al cambiar de arma en el
  slot. `RequestReload`/`Weapon_RequestReload`.
- `CombatService` — valida `Combat_MeleeAttack`/`Combat_RangedAttack`:
  cooldown (por slot) -> munición (solo ranged, se consume acierte o
  no) -> distancia máxima -> validez de objetivo (`Model`+`Humanoid`
  vivo + tag `Combatable` de `CollectionService`, ningún Instance lo
  tiene todavía — pipeline listo para que la fase de hordas solo
  taguee sus zombies).

**Archivos nuevos:**
- `Shared/Enums/`: `WeaponType.lua` (`Machete`/`BaseballBat`/`Pistol`/
  `Rifle`), `WeaponKind.lua` (`Melee`/`Firearm`), `ItemRarity.lua`
  (`Common`/`Uncommon`/`Rare`/`Epic`), `ItemCategory.lua`
  (`Weapon`/`Tool`/`Resource`/`Healing`/`Utility`), `EquipmentSlot.lua`
  (`PrimaryWeapon`/`SecondaryWeapon`/`Tool`/`Utility`/`Healing`),
  `ConsumableType.lua` (`Bandage`/`Medkit`), `UtilityItemType.lua`
  (`Flashlight`, placeholder sin lógica propia).
- `Shared/Config/`: `WeaponConfig.lua` (daño/cadencia/cargador/
  reserva/recarga/alcance/retroceso/rareza/precio, congelado y
  validado por `ConfigurationService`), `ItemConfig.lua` (categoría/
  stackeo/consumible por `ItemId`, reutiliza los `ItemId` de
  `WeaponType`/`ToolType`/`ResourceType` sin taxonomía nueva),
  `InventoryConfig.lua` (`SlotCount = 10`, `StarterItems`: 1 `Machete`
  + 2 `Bandage`).
- `ServerScriptService/Server/Services/`: `InventoryService.lua`,
  `EquipmentService.lua`, `WeaponService.lua`, `CombatService.lua`.
- `StarterPlayer/.../Client/Inventory/InventoryClient.lua` — cache de
  cliente de mochila/equipamiento (pide `Inventory_GetSnapshot` una
  vez al conectar) + helpers `Equip`/`Unequip`/`ConsumeFirst`.
- `StarterPlayer/.../Client/Weapons/WeaponClient.lua` — arnés de
  prueba (`3`/`4`/`5` equipar, `E` golpe, `G` disparo, `R` recarga,
  `U` desequipar, `C` consumir vendaje).

**Archivos modificados:**
- `ServiceLoader.lua` — 4 entradas nuevas en el orden de dependencia
  correcto (ver arriba).
- `ConfigurationService.lua` — valida `WeaponConfig` (incluyendo que
  Melee no tenga campos de munición y Firearm sí los tenga todos),
  `ItemConfig` (`MaxStack`, `Consumable`+`HealAmount`, y que toda
  arma/herramienta tenga su entrada), `InventoryConfig` (`SlotCount`,
  `StarterItems` válidos y que entren en la capacidad).
- `RemotesConfig.lua` — retira `Tool_Equip`; agrega
  `Inventory_GetSnapshot`, `Inventory_Move`, `Inventory_Consume`,
  `Inventory_Equip`, `Inventory_Unequip`, `Weapon_RequestReload`,
  `Combat_MeleeAttack`, `Combat_RangedAttack` (todas `RemoteFunction`).
- `Types.lua` — retira `ToolEquipResult`; agrega `ItemStack`,
  `EquipmentSlotName`, `WeaponId`, `WeaponKind`, `InventorySnapshot`,
  `EquipmentSnapshot`, `InventoryActionResult`, `ConsumeItemResult`,
  `EquipmentActionResult`, `InventoryStateSnapshot`,
  `WeaponAmmoState`, `ReloadResult`, `CombatActionResult`;
  `PlayerData.Inventory` -> `InventorySlots`/`Equipment`.
- `PlayerDataConfig.lua` — `DefaultTemplate` cambia `Inventory = {}`
  por `InventorySlots = {}`/`Equipment = {}`.
- `PlayerDataService.lua` — `buildDefaultData` arma la mochila inicial
  con el kit de `InventoryConfig`; `loadData` migra saves de antes de
  esta fase (`Inventory` viejo -> `InventorySlots`, repartiendo por
  `MaxStack`, descartando y logueando lo que no entra); se retira
  `AddResource` (reemplazado por `InventoryService.AddItem`).
- `ToolService.lua` — retira la tabla `equippedTool` y `EquipTool`;
  `RequestHarvest` consulta `EquipmentService.GetEquippedItemId` y
  acredita vía `InventoryService.AddItem`.
- `ToolClient.lua` — equipar ahora usa `InventoryClient.Equip` en vez
  de invocar `Tool_Equip` directo.
- `init.client.lua` — inicializa `InventoryClient` (antes que
  `ToolClient`/`WeaponClient`, que dependen de su cache) y
  `WeaponClient`.

**Decisiones importantes:**

- **Munición no persistida, por diseño**: el inventario de esta fase
  apila armas por `ItemId` sin instancias únicas — no hay dónde
  guardar "cuánta munición le queda a ESTA copia en particular" de un
  arma. `WeaponService` prioriza simplicidad: re-arma cargador+reserva
  completos la primera vez que se usa un arma en un slot (o al
  cambiar de arma ahí). Documentado para que una futura fase de armas
  únicas/desgaste sepa que tiene que rediseñar esto.
- **Recarga simplificada pero autoritativa**: no hay animación/canal
  que el servidor deba esperar (no hay humanoides de zombie con los
  que interrumpir una recarga todavía), así que `RequestReload` aplica
  la munición de inmediato pero marca un cooldown de `ReloadSeconds`
  que bloquea disparos/recargas siguientes — el cliente sigue
  mostrando su animación local por esa duración.
- **Munición se consume acierte o no el disparo**: igual que un arma
  real. La validación de distancia/objetivo solo decide si, además de
  gastar la bala, también hay daño.
- **`Combatable` como tag de `CollectionService`, no una lista
  hardcodeada**: para que el combate quede listo sin cambios cuando
  lleguen los zombies, sin acoplarse a ninguna clase de enemigo
  específica. Documentado explícitamente que hoy no hay ningún
  Instance tagueado, así que todo golpe/disparo termina en
  `TargetNotCombatable` — mismo patrón que `ResourceService.
  ExtractResource` en la Fase 5 quedó listo sin nada que lo invocara
  hasta la Fase 6.
- **Cooldown de combate por `(UserId, EquipmentSlotName)`, no por
  arma ni global**: dos armas en Primaria/Secundaria pueden atacar en
  paralelo sin compartir cadencia; cambiar de arma en el MISMO slot
  no resetea su cooldown, mismo criterio que
  `ToolService.checkCooldown` en la Fase 6.
- **`Tool_Equip` se retira, no se deprecia en silencio**: la Fase 6
  dejó pendiente, a propósito, decidir si equipar una herramienta
  debía empezar a gatear posesión una vez existiera inventario real.
  Esta fase decide que sí: equipar una herramienta es ahora un caso
  más de `Inventory_Equip`, así que el remote/tipo viejo se retiran en
  vez de mantenerse en paralelo.
- **`ItemConfig` reutiliza los `ItemId` existentes, sin taxonomía
  nueva**: un `ResourceType.Wood` es el mismo string tanto en
  `ResourceConfig` como en `ItemConfig.Items` — mismo criterio que
  `ToolConfig.EffectiveAgainst` en la Fase 6.
- **`Inventory_GetSnapshot` como única excepción de solo-lectura**: a
  diferencia del resto de remotes de esta fase (que devuelven su
  propio snapshot actualizado), este existe porque el cliente
  necesita el estado inicial de su mochila/equipo al conectar, antes
  de que cualquier acción le devuelva uno.
- **Tablas de slots son sparse — nunca `ipairs`/`#` sobre ellas**: un
  slot vacío es una clave ausente de la tabla, no un valor `nil`
  "puesto" ahí (asignar `nil` a una clave que no existe es un no-op
  en Lua). Tanto `InventoryService` como `PlayerDataService`
  (`buildDefaultData`/migración) e `InventoryClient` (cliente)
  recorren siempre por rango explícito (`InventoryConfig.SlotCount`/
  `Capacity`), nunca por `ipairs`/`#`.
- Fases 1-6 verificadas intactas salvo los cambios puntuales y
  documentados arriba; ningún otro archivo de `ServerScriptService`,
  `ReplicatedStorage`, `StarterPlayer` ni `Workspace/WorldMap` se
  tocó.

## Fase 8 — resumen

**Servicios nuevos** (`ServerScriptService/Server/Services/`, sumados
a `ORDERED_SERVICE_MODULES`: `ZombieService` junto a `ResourceService`
al principio -- mismo motivo, escanea una carpeta de
`Workspace.WorldMap` al arrancar y solo depende de `CleanupService`;
`ZombieAIService`/`WaveService` al final, después de `CombatService`):

- `ZombieService` — única autoridad sobre la existencia de los
  zombies. Escanea `ZombieSpawnPoints` (Fase 4) al arrancar.
  `SpawnZombie(zombieType, options)` valida contra `ZombieConfig.
  Types`, hace cumplir `ZombieConfig.MaxConcurrentZombies` (techo
  defensivo de rendimiento, 60, independiente de cuántos pida una
  ronda puntual), elige spawn point filtrado por `options.MaxRing`,
  arma un rig placeholder (`buildZombieRig`) y lo taguea `Combatable`
  de inmediato. `DespawnZombie`/`KillZombie` (remoción forzada vs.
  muerte real) y el Signal unificado `ZombieRemoved(zombieId, model,
  zombieType, reason)`.
- `ZombieAIService` — `StateMachine` por zombie (Idle/Searching/
  Chasing/Attacking/Dead), un hilo `task.spawn` propio por zombie
  (nunca `RunService.Heartbeat` compartido), reaccionando a
  `ZombieSpawned`/`ZombieRemoved`. Pathfinding con intervalos
  controlados y manejo de atascos (ver decisiones abajo). Ataque
  zombie -> jugador directo (`Humanoid:TakeDamage`), NO vía
  `CombatService`. Comportamientos exclusivos Explosive (daño en
  área + autodestrucción) y Toxic (veneno que refresca duración).
- `WaveService` — sub-ciclo de rondas (`RoundPhase`: Preparación ->
  Oleada -> Intermisión) por `PartyId`, atado a
  `MatchService.StateChanged` (entra/sale de `GameState.InProgress`)
  y `PartyService.PartyChanged` (caso límite de Match removida sin
  transición de fase). `WaveConfig.GetDifficultyForRound` calcula
  cantidad/multiplicadores/anillo máximo para cualquier ronda; tipo
  de cada zombie por sorteo ponderado sobre tipos desbloqueados.
  Spawn escalonado (`SpawnIntervalSeconds`), no todos en el mismo
  frame. Signal `RoundStateChanged` listo para una futura UI/HUD.

**Archivos nuevos:**
- `Shared/Enums/`: `ZombieType.lua` (9 tipos), `ZombieAIState.lua`
  (5 estados), `RoundPhase.lua` (3 fases).
- `Shared/Config/`: `ZombieConfig.lua` (estadísticas por tipo +
  techo global concurrente, congelado y validado por
  `ConfigurationService`), `WaveConfig.lua` (dificultad progresiva —
  a diferencia del resto de `Shared/Config`, expone además funciones
  puras `GetDifficultyForRound`/`GetMaxRingForRound`/
  `GetAvailableZombieTypes` porque "ronda" no tiene techo, no se
  puede precargar en una tabla fija).
- `ServerScriptService/Server/Services/`: `ZombieService.lua`,
  `ZombieAIService.lua`, `WaveService.lua`.

**Archivos modificados:**
- `ServiceLoader.lua` — 3 entradas nuevas (`ZombieService` cerca de
  `ResourceService`; `ZombieAIService`/`WaveService` al final).
- `ConfigurationService.lua` — valida `ZombieConfig` (techo > 0, cada
  tipo con sus campos comunes, exclusivos de Explosive/Toxic solo si
  están presentes) y `WaveConfig` (duraciones/tasas positivas,
  anillos 1-3, `SpecialTypeUnlocks` referencia tipos reales de
  `ZombieConfig`), y expone ambos en `.Get()`.
- `Types.lua` — tipos nuevos de la Fase 8 (`ZombieTypeId`,
  `ZombieAIStateId`, `RoundPhaseId`, `ZombieId`, `ZombieInfo`,
  `ZombieSpawnResult`, `RoundState`); no reemplaza ni toca ningún
  tipo existente.
- `CombatService.lua` **NO se tocó**: el tag `Combatable` que
  `ZombieService` aplica es el mismo string que esa fase ya
  documentó y esperaba desde la Fase 7 — la integración completa fue
  agregar la línea `CollectionService:AddTag(model, "Combatable")` en
  el archivo nuevo, sin modificar el archivo viejo.

**Decisiones importantes:**

- **Rig placeholder, no asset de Creator Store**: mismo criterio que
  `ResourceNodes` en la Fase 5 -- `Model` con `HumanoidRootPart`
  invisible (PrimaryPart, carga la física) + `Torso`/`Head` visibles
  coloreados por tipo, unidos con `WeldConstraint`, sin animaciones.
  `WORLD_MAP_DESIGN.md` sección 13 exige revisión manual de todo Free
  Model antes de integrarlo -- no se asume ningún rig externo. El
  reemplazo futuro por un rig real no requiere tocar
  `ZombieAIService`/`WaveService`/`CombatService`: todos operan sobre
  `Model`+`Humanoid`, nunca sobre la forma interna del rig.
- **`COMBATABLE_TAG` repetido como literal, no un require cruzado a
  `CombatService`**: el `ServiceLoader` prohíbe que un servicio
  requiera a otro directamente (todos se comunican vía `registry`);
  repetir el string `"Combatable"` en ambos archivos, documentado en
  los dos, es preferible a violar esa regla por un solo literal.
- **Ataque zombie -> jugador no pasa por `CombatService`**:
  `CombatService` valida específicamente acciones DEL JUGADOR (arma
  equipada, munición, cooldown de arma); un zombie no tiene ninguna
  de esas tres cosas. `ZombieAIService` aplica `Humanoid:TakeDamage`
  directo con su propio cooldown por `ZombieConfig`, evitando forzar
  un slot/arma falsos en el jugador solo para reusar un pipeline que
  no encaja en la dirección inversa.
- **Pathfinding con intervalos controlados, nunca por frame**: cada
  zombie corre en su propio `task.spawn` (nunca
  `RunService.Heartbeat` compartido); `ComputeAsync` solo se llama al
  entrar en Chasing, si el target se movió > 6 studs desde el último
  cálculo, o tras un path fallido/atasco -- nunca una vez por
  iteración. Atascos: `Humanoid.MoveToFinished` con timeout de 4s
  (polling liviano de 0.1s SOLO mientras ese zombie se mueve a ese
  waypoint puntual); si no llega o el path falla, se espera 1s antes
  de reintentar en vez de martillar `PathfindingService` contra un
  path imposible.
- **`StateMachine` reutilizada tal cual, una instancia por zombie**:
  mismo criterio que `MatchService` (una por Match). Se agregó un
  guard `transitionIfNeeded` porque el loop de IA reevalúa el mismo
  estado en cada vuelta (ej. sigue "Chasing" muchas iteraciones
  seguidas) y `ALLOWED_AI_TRANSITIONS` no declara self-transiciones a
  propósito -- pedir una transición al mismo estado sin este guard
  dispararía el warning de "transición inválida" de
  `StateMachine.lua` en cada iteración del loop.
- **Explosive se autodestruye con `ZombieService.KillZombie`, no con
  `Model:Destroy()` directo**: fuerza `Humanoid.Health = 0`, que
  dispara el mismo `Humanoid.Died` -> `removeZombie` que cualquier
  otra muerte -- un solo camino de salida para "este zombie murió",
  sin un segundo código de limpieza paralelo para el caso Explosive.
- **Veneno de Toxic refresca duración, no acumula stacks**: decisión
  explícita para no diseñar un sistema de stacks que la Fase 8 no
  pidió. Se cancela y reinicia (`task.cancel` + nueva cadena de
  `task.delay`) en vez de sumar un segundo temporizador en paralelo.
- **`WaveConfig` expone funciones además de datos**: a diferencia del
  resto de `Shared/Config` (tablas puras), "ronda" es un número sin
  techo -- la dificultad tiene que poder calcularse para cualquier
  ronda futura, no solo para las que alguien precargó en una tabla
  fija. `TableUtils.DeepFreeze` sigue congelando las tablas de datos;
  las funciones no son tablas, así que no hay nada que congelar en
  ellas y siguen siendo invocables con normalidad.
- **`WaveService` escucha `PartyService.PartyChanged` además de
  `MatchService.StateChanged`**: `MatchService.onPartyChanged` puede
  remover una Match directamente (Party vacía/destruida) SIN pasar
  por una transición de `GameState` si nadie queda en la partida --
  sin este segundo listener, ese caso límite dejaría timers y
  zombies huérfanos sin ronda dueña.
- **Spawn de oleada escalonado (`SpawnIntervalSeconds`), no todos de
  una vez**: reduce el pico de cómputo de pathfinding inicial (cada
  zombie recién spawneado calcula su primer path) y respeta
  `WORLD_MAP_DESIGN.md` sección 10 ("el peligro debe sentirse por
  cantidad/ambientación, no por apariciones tramposas").
- **`ZombieId` generado por `ZombieService`, no leído de
  `Instance.Name`**: a diferencia de `ResourceService` (que usa
  `instance.Name` de un Part YA existente en el `.model.json` como
  `NodeId`), un zombie no existe hasta que se spawnea -- no hay
  ningún nombre previo del que partir. Se genera `zombieType .. "_" ..
  HttpService:GenerateGUID(false)` y se lo asigna como `Model.Name`
  para que sea legible en el Explorer de Studio.
- Fases 1-7 verificadas intactas salvo los cambios puntuales y
  documentados arriba (`ServiceLoader.lua`, `ConfigurationService.lua`,
  `Types.lua`); ningún otro archivo de `ServerScriptService`,
  `ReplicatedStorage`, `StarterPlayer` ni `Workspace/WorldMap` se
  tocó. `CombatService.lua` en particular queda exactamente como la
  Fase 7 lo dejó.

## Próxima fase sugerida

Sistema de construcción de bases/barricadas/defensas (usando
`BuildZones` de la Fase 4 y los recursos de la Fase 5), y/o tiendas
del lobby y economía avanzada -- ambos explícitamente fuera de
alcance de la Fase 8. A decidir al arrancar la próxima fase.
