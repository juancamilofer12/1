--!strict
--[[
	ZombieConfig.lua

	Estadísticas diferenciadas por tipo de zombie (Fase 8). Mismo
	patrón que ToolConfig/WeaponConfig: números centralizados acá en
	vez de hardcodeados en ZombieService/ZombieAIService, congelado y
	validado por ConfigurationService.

	Campos comunes a los 9 tipos:
	- MaxHealth, WalkSpeed, Damage (daño por golpe cuerpo a cuerpo
	  contra un jugador), AttackCooldownSeconds, AttackRange,
	  DetectionRange (distancia a la que un zombie de este tipo puede
	  "notar" a un jugador y empezar a perseguirlo).
	- AgentRadius/AgentHeight: pasados tal cual como
	  AgentParameters de PathfindingService:CreatePath (ver
	  ZombieAIService) -- no hay razón para que un Giant y un Runner
	  compartan el mismo radio de agente de pathfinding.
	- Size: escala del rig placeholder (ver ZombieService.buildRig).
	  Igual filosofía que ResourceNodes en la Fase 5: geometría
	  primitiva simple, coloreada por tipo, lista para reemplazo por
	  un rig real de Creator Store (ver WORLD_MAP_DESIGN.md sección 13)
	  sin que ningún otro sistema (IA, combate, rondas) necesite
	  cambiar.
	- Color: color del placeholder, distingue tipos a simple vista
	  mientras no hay rigs reales.

	Campos exclusivos de un tipo (quedan `nil` en el resto, mismo
	criterio que WeaponConfig documenta para Melee/Firearm -- un
	acceso accidental a un campo que no aplica falla ruidoso en vez
	de comportarse como 0):
	- Explosive: ExplosionRadius, ExplosionDamage. Al golpear (o al
	  morir, ver ZombieAIService) hace daño en área y se autodestruye.
	- Toxic: PoisonDamagePerTick, PoisonTickIntervalSeconds,
	  PoisonDurationSeconds. Su golpe aplica una quemadura de veneno
	  además del daño de contacto inmediato.
	- Climber: CanClimb = true. Habilita
	  Humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	  -- placeholder para terreno vertical/escaleras que todavía no
	  existe en el mapa (ver WORLD_MAP_DESIGN.md sección 2.6/2.8 sobre
	  verticalidad del Aserradero/Cantera); no tiene efecto visible
	  hoy pero deja al tipo listo para cuando ese terreno exista.
	- Stealth: Transparency > 0 en el rig, para que sea genuinamente
	  más difícil de ver a simple vista (no solo "en teoría más
	  sigiloso") mientras conserva un DetectionRange alto -- encuentra
	  al jugador desde lejos pero cuesta verlo venir.

	Balanceo: valores de placeholder razonables, no definitivos --
	mismo criterio documentado en ResourceConfig/ToolConfig/WeaponConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local ZombieType = require(ReplicatedStorage.Shared.Enums.ZombieType)

local ZombieConfig = {
	-- Techo global de zombies vivos simultáneamente en el servidor,
	-- sin importar cuántas Matches/rondas estén activas a la vez.
	-- Es un límite DEFENSIVO de rendimiento (ZombieService lo hace
	-- cumplir en SpawnZombie), independiente y más alto que la
	-- cantidad de zombies que `WaveConfig` calcula por ronda -- si
	-- alguna vez varias Matches corrieran en paralelo en el mismo
	-- servidor, esto evita que la suma de todas las oleadas dispare
	-- el conteo de Instances sin control.
	MaxConcurrentZombies = 60,

	Types = {
		[ZombieType.Normal] = {
			MaxHealth = 100,
			WalkSpeed = 8,
			Damage = 10,
			AttackCooldownSeconds = 1.0,
			AttackRange = 5,
			DetectionRange = 40,
			AgentRadius = 2,
			AgentHeight = 5,
			Size = Vector3.new(2, 5, 1),
			Color = Color3.fromRGB(90, 100, 80),
		},
		[ZombieType.Runner] = {
			MaxHealth = 60,
			WalkSpeed = 16,
			Damage = 6,
			AttackCooldownSeconds = 0.6,
			AttackRange = 4,
			DetectionRange = 45,
			AgentRadius = 1.5,
			AgentHeight = 5,
			Size = Vector3.new(1.6, 5, 1),
			Color = Color3.fromRGB(140, 60, 50),
		},
		[ZombieType.Brute] = {
			MaxHealth = 220,
			WalkSpeed = 6,
			Damage = 25,
			AttackCooldownSeconds = 1.6,
			AttackRange = 6,
			DetectionRange = 35,
			AgentRadius = 2.5,
			AgentHeight = 6,
			Size = Vector3.new(2.6, 6, 1.2),
			Color = Color3.fromRGB(60, 60, 65),
		},
		[ZombieType.Giant] = {
			MaxHealth = 500,
			WalkSpeed = 4,
			Damage = 35,
			AttackCooldownSeconds = 2.0,
			AttackRange = 8,
			DetectionRange = 35,
			AgentRadius = 3.5,
			AgentHeight = 9,
			Size = Vector3.new(4, 9, 2),
			Color = Color3.fromRGB(70, 80, 55),
		},
		[ZombieType.Explosive] = {
			MaxHealth = 80,
			WalkSpeed = 9,
			Damage = 15,
			AttackCooldownSeconds = 1.0,
			AttackRange = 5,
			DetectionRange = 40,
			AgentRadius = 2,
			AgentHeight = 5,
			Size = Vector3.new(2, 5, 1),
			Color = Color3.fromRGB(200, 90, 25),
			-- Exclusivo Explosive: ver nota de cabecera.
			ExplosionRadius = 12,
			ExplosionDamage = 60,
		},
		[ZombieType.Toxic] = {
			MaxHealth = 110,
			WalkSpeed = 7,
			Damage = 8,
			AttackCooldownSeconds = 1.2,
			AttackRange = 5,
			DetectionRange = 38,
			AgentRadius = 2,
			AgentHeight = 5,
			Size = Vector3.new(2, 5, 1),
			Color = Color3.fromRGB(80, 150, 55),
			-- Exclusivo Toxic: ver nota de cabecera.
			PoisonDamagePerTick = 4,
			PoisonTickIntervalSeconds = 1,
			PoisonDurationSeconds = 5,
		},
		[ZombieType.Climber] = {
			MaxHealth = 90,
			WalkSpeed = 10,
			Damage = 9,
			AttackCooldownSeconds = 0.9,
			AttackRange = 4.5,
			DetectionRange = 42,
			AgentRadius = 1.8,
			AgentHeight = 5,
			Size = Vector3.new(1.8, 5, 1),
			Color = Color3.fromRGB(110, 95, 70),
			-- Exclusivo Climber: ver nota de cabecera.
			CanClimb = true,
		},
		[ZombieType.Stealth] = {
			MaxHealth = 70,
			WalkSpeed = 11,
			Damage = 14,
			AttackCooldownSeconds = 0.8,
			AttackRange = 4.5,
			DetectionRange = 55,
			AgentRadius = 1.8,
			AgentHeight = 5,
			Size = Vector3.new(1.8, 5, 1),
			Color = Color3.fromRGB(15, 15, 20),
			-- Exclusivo Stealth: ver nota de cabecera.
			Transparency = 0.55,
		},
		[ZombieType.Nightmare] = {
			MaxHealth = 350,
			WalkSpeed = 13,
			Damage = 30,
			AttackCooldownSeconds = 0.7,
			AttackRange = 6,
			DetectionRange = 60,
			AgentRadius = 2.4,
			AgentHeight = 6.5,
			Size = Vector3.new(2.4, 6.5, 1.2),
			Color = Color3.fromRGB(90, 0, 10),
		},
	},
}

return TableUtils.DeepFreeze(ZombieConfig)
