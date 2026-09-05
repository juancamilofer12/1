--!strict
--[[
	ConfigurationService.lua

	Responsabilidad: validar en el arranque que la configuración del
	juego es coherente (por ejemplo, que MatchConfig.MinPlayersToStart
	sea >= 1) y exponer un punto único de acceso a los módulos de
	Config ya congelados.

	No guarda estado propio: es una capa fina de validación +
	agregación sobre Shared/Config. Se lista como servicio (y no
	simplemente como Config compartido) porque su Init() realmente
	hace trabajo: falla rápido y ruidoso si alguien deja la
	configuración en un estado inválido, en vez de que el bug
	aparezca silenciosamente en medio de una partida.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local PartyConfig = require(ReplicatedStorage.Shared.Config.PartyConfig)
local PlayerDataConfig = require(ReplicatedStorage.Shared.Config.PlayerDataConfig)
local RemotesConfig = require(ReplicatedStorage.Shared.Config.RemotesConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Config.InventoryConfig)
local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)
local ResourceTypeEnum = require(ReplicatedStorage.Shared.Enums.ResourceType)
local WeaponKind = require(ReplicatedStorage.Shared.Enums.WeaponKind)

local Types = require(ReplicatedStorage.Shared.Types)

-- Ver nota en CleanupService.lua sobre por qué no se castea el
-- módulo entero a Types.Service acá.
local ConfigurationService = {}
ConfigurationService.Name = "ConfigurationService" :: string

local VALID_LOG_LEVELS = { DEBUG = true, INFO = true, WARN = true, ERROR = true }

local VALID_RESOURCE_TYPES_FOR_TOOLS: { [string]: boolean } = {
	[ResourceTypeEnum.Wood] = true,
	[ResourceTypeEnum.Stone] = true,
	[ResourceTypeEnum.Metal] = true,
	[ResourceTypeEnum.Scrap] = true,
}

local function validate()
	assert(VALID_LOG_LEVELS[GameConfig.LogLevel], "GameConfig.LogLevel inválido: " .. tostring(GameConfig.LogLevel))

	assert(MatchConfig.MinPlayersToStart >= 1, "MatchConfig.MinPlayersToStart debe ser >= 1")
	assert(MatchConfig.CountdownDuration > 0, "MatchConfig.CountdownDuration debe ser > 0")
	assert(MatchConfig.CountdownTickInterval > 0, "MatchConfig.CountdownTickInterval debe ser > 0")
	assert(
		MatchConfig.CountdownTickInterval <= MatchConfig.CountdownDuration,
		"MatchConfig.CountdownTickInterval no debería ser mayor que CountdownDuration"
	)
	assert(MatchConfig.EndingDuration > 0, "MatchConfig.EndingDuration debe ser > 0")
	assert(MatchConfig.StartMatchCooldownSeconds >= 0, "MatchConfig.StartMatchCooldownSeconds debe ser >= 0")

	assert(#PlayerDataConfig.DataStoreName > 0, "PlayerDataConfig.DataStoreName no puede estar vacío")
	assert(PlayerDataConfig.MaxRetries >= 0, "PlayerDataConfig.MaxRetries debe ser >= 0")

	assert(PartyConfig.MaximumMembers >= 1, "PartyConfig.MaximumMembers debe ser >= 1")
	assert(PartyConfig.ActionCooldownSeconds >= 0, "PartyConfig.ActionCooldownSeconds debe ser >= 0")

	for resourceType, nodeConfig in pairs(ResourceConfig.Nodes) do
		assert(nodeConfig.Amount > 0, "ResourceConfig.Nodes." .. resourceType .. ".Amount debe ser > 0")
		assert(
			nodeConfig.RespawnSeconds > 0,
			"ResourceConfig.Nodes." .. resourceType .. ".RespawnSeconds debe ser > 0"
		)
	end

	assert(ToolConfig.MaxHarvestDistance > 0, "ToolConfig.MaxHarvestDistance debe ser > 0")
	for toolId, toolConfig in pairs(ToolConfig.Tools) do
		assert(toolConfig.Damage > 0, "ToolConfig.Tools." .. toolId .. ".Damage debe ser > 0")
		assert(toolConfig.CooldownSeconds >= 0, "ToolConfig.Tools." .. toolId .. ".CooldownSeconds debe ser >= 0")
		assert(
			#toolConfig.EffectiveAgainst > 0,
			"ToolConfig.Tools." .. toolId .. ".EffectiveAgainst no puede estar vacío"
		)
		for _, resourceType in ipairs(toolConfig.EffectiveAgainst) do
			assert(
				VALID_RESOURCE_TYPES_FOR_TOOLS[resourceType],
				"ToolConfig.Tools." .. toolId .. ".EffectiveAgainst tiene un ResourceType inválido: " .. tostring(resourceType)
			)
		end
	end

	local seenNames: { [string]: boolean } = {}
	for _, def in ipairs(RemotesConfig.Definitions) do
		assert(not seenNames[def.Name], "RemotesConfig tiene un nombre de remote duplicado: " .. def.Name)
		seenNames[def.Name] = true
		assert(
			def.Kind == "RemoteEvent" or def.Kind == "RemoteFunction",
			"RemotesConfig: Kind inválido para " .. def.Name
		)
	end

	-- Fase 7: WeaponConfig. Cada arma valida sus campos comunes
	-- (Damage/CooldownSeconds/Range/Rarity/Price) y, según Kind, los
	-- campos exclusivos de arma de fuego (MagazineSize/ReserveAmmo/
	-- ReloadSeconds) — asegurando además que un arma Melee NO los
	-- tenga (ver nota en WeaponConfig.lua sobre por qué quedan `nil`
	-- y no `0`).
	for weaponId, weaponConfig in pairs(WeaponConfig.Weapons) do
		assert(weaponConfig.Damage > 0, "WeaponConfig.Weapons." .. weaponId .. ".Damage debe ser > 0")
		assert(
			weaponConfig.CooldownSeconds > 0,
			"WeaponConfig.Weapons." .. weaponId .. ".CooldownSeconds debe ser > 0"
		)
		assert(weaponConfig.Range > 0, "WeaponConfig.Weapons." .. weaponId .. ".Range debe ser > 0")
		assert(weaponConfig.Price >= 0, "WeaponConfig.Weapons." .. weaponId .. ".Price debe ser >= 0")

		if weaponConfig.Kind == WeaponKind.Firearm then
			assert(
				weaponConfig.MagazineSize and weaponConfig.MagazineSize > 0,
				"WeaponConfig.Weapons." .. weaponId .. ".MagazineSize debe ser > 0 en un arma de fuego"
			)
			assert(
				weaponConfig.StartingReserveAmmo and weaponConfig.StartingReserveAmmo >= 0,
				"WeaponConfig.Weapons." .. weaponId .. ".StartingReserveAmmo debe ser >= 0"
			)
			assert(
				weaponConfig.MaxReserveAmmo and weaponConfig.MaxReserveAmmo >= weaponConfig.StartingReserveAmmo,
				"WeaponConfig.Weapons." .. weaponId .. ".MaxReserveAmmo debe ser >= StartingReserveAmmo"
			)
			assert(
				weaponConfig.ReloadSeconds and weaponConfig.ReloadSeconds > 0,
				"WeaponConfig.Weapons." .. weaponId .. ".ReloadSeconds debe ser > 0"
			)
		elseif weaponConfig.Kind == WeaponKind.Melee then
			assert(
				weaponConfig.MagazineSize == nil,
				"WeaponConfig.Weapons." .. weaponId .. " es Melee pero define MagazineSize"
			)
		else
			error("WeaponConfig.Weapons." .. weaponId .. ".Kind inválido: " .. tostring(weaponConfig.Kind))
		end
	end

	-- Fase 7: ItemConfig. MaxStack >= 1 siempre; un ítem Consumable
	-- (curación) necesita HealAmount > 0. Cualquier arma/herramienta
	-- que WeaponConfig/ToolConfig ya define debe tener también su
	-- entrada acá (InventoryService no sabría cómo apilarla/equiparla
	-- si no) y viceversa.
	for itemId, itemDef in pairs(ItemConfig.Items) do
		assert(itemDef.MaxStack >= 1, "ItemConfig.Items." .. itemId .. ".MaxStack debe ser >= 1")
		if itemDef.Consumable then
			assert(
				itemDef.HealAmount and itemDef.HealAmount > 0,
				"ItemConfig.Items." .. itemId .. " es Consumable pero HealAmount no es > 0"
			)
		end
	end
	for weaponId in pairs(WeaponConfig.Weapons) do
		assert(ItemConfig.Items[weaponId], "WeaponConfig.Weapons." .. weaponId .. " no tiene entrada en ItemConfig")
	end
	for toolId in pairs(ToolConfig.Tools) do
		assert(ItemConfig.Items[toolId], "ToolConfig.Tools." .. toolId .. " no tiene entrada en ItemConfig")
	end

	-- Fase 7: InventoryConfig. Capacidad positiva, y el kit inicial
	-- tiene que caber sin superponerse (StarterItems no puede tener
	-- más entradas no-apilables que slots disponibles) ni referenciar
	-- un ItemId que ItemConfig no reconozca.
	assert(InventoryConfig.SlotCount > 0, "InventoryConfig.SlotCount debe ser > 0")
	assert(
		#InventoryConfig.StarterItems <= InventoryConfig.SlotCount,
		"InventoryConfig.StarterItems no puede tener más entradas que InventoryConfig.SlotCount"
	)
	for _, starter in ipairs(InventoryConfig.StarterItems) do
		assert(
			ItemConfig.Items[starter.ItemId],
			"InventoryConfig.StarterItems referencia un ItemId inválido: " .. tostring(starter.ItemId)
		)
		assert(
			starter.Quantity > 0,
			"InventoryConfig.StarterItems." .. starter.ItemId .. ".Quantity debe ser > 0"
		)
	end

	-- Fase 8: ZombieConfig. Techo global positivo, y cada tipo valida
	-- sus campos comunes; los campos exclusivos (Explosive/Toxic)
	-- solo se validan si están presentes (quedan `nil` en el resto de
	-- los tipos, mismo criterio que WeaponConfig con MagazineSize).
	assert(ZombieConfig.MaxConcurrentZombies > 0, "ZombieConfig.MaxConcurrentZombies debe ser > 0")
	for zombieTypeId, zombieTypeConfig in pairs(ZombieConfig.Types) do
		assert(zombieTypeConfig.MaxHealth > 0, "ZombieConfig.Types." .. zombieTypeId .. ".MaxHealth debe ser > 0")
		assert(zombieTypeConfig.WalkSpeed > 0, "ZombieConfig.Types." .. zombieTypeId .. ".WalkSpeed debe ser > 0")
		assert(zombieTypeConfig.Damage >= 0, "ZombieConfig.Types." .. zombieTypeId .. ".Damage debe ser >= 0")
		assert(
			zombieTypeConfig.AttackCooldownSeconds > 0,
			"ZombieConfig.Types." .. zombieTypeId .. ".AttackCooldownSeconds debe ser > 0"
		)
		assert(zombieTypeConfig.AttackRange > 0, "ZombieConfig.Types." .. zombieTypeId .. ".AttackRange debe ser > 0")
		assert(
			zombieTypeConfig.DetectionRange >= zombieTypeConfig.AttackRange,
			"ZombieConfig.Types." .. zombieTypeId .. ".DetectionRange debe ser >= AttackRange"
		)
		assert(zombieTypeConfig.AgentRadius > 0, "ZombieConfig.Types." .. zombieTypeId .. ".AgentRadius debe ser > 0")
		assert(zombieTypeConfig.AgentHeight > 0, "ZombieConfig.Types." .. zombieTypeId .. ".AgentHeight debe ser > 0")

		if zombieTypeConfig.ExplosionRadius ~= nil then
			assert(
				zombieTypeConfig.ExplosionRadius > 0,
				"ZombieConfig.Types." .. zombieTypeId .. ".ExplosionRadius debe ser > 0"
			)
			assert(
				zombieTypeConfig.ExplosionDamage and zombieTypeConfig.ExplosionDamage > 0,
				"ZombieConfig.Types." .. zombieTypeId .. ".ExplosionDamage debe ser > 0"
			)
		end

		if zombieTypeConfig.PoisonDamagePerTick ~= nil then
			assert(
				zombieTypeConfig.PoisonDamagePerTick > 0,
				"ZombieConfig.Types." .. zombieTypeId .. ".PoisonDamagePerTick debe ser > 0"
			)
			assert(
				zombieTypeConfig.PoisonTickIntervalSeconds and zombieTypeConfig.PoisonTickIntervalSeconds > 0,
				"ZombieConfig.Types." .. zombieTypeId .. ".PoisonTickIntervalSeconds debe ser > 0"
			)
			assert(
				zombieTypeConfig.PoisonDurationSeconds and zombieTypeConfig.PoisonDurationSeconds > 0,
				"ZombieConfig.Types." .. zombieTypeId .. ".PoisonDurationSeconds debe ser > 0"
			)
		end
	end

	-- Fase 8: WaveConfig. Duraciones/tasas positivas, umbrales de
	-- anillo dentro de 1-3, y cada desbloqueo de tipo especial
	-- referencia un ZombieType real de ZombieConfig con peso > 0.
	assert(WaveConfig.PreparationSeconds > 0, "WaveConfig.PreparationSeconds debe ser > 0")
	assert(WaveConfig.IntermissionSeconds > 0, "WaveConfig.IntermissionSeconds debe ser > 0")
	assert(WaveConfig.BaseZombieCount > 0, "WaveConfig.BaseZombieCount debe ser > 0")
	assert(WaveConfig.ZombieCountPerRound >= 0, "WaveConfig.ZombieCountPerRound debe ser >= 0")
	assert(WaveConfig.SpawnIntervalSeconds > 0, "WaveConfig.SpawnIntervalSeconds debe ser > 0")
	assert(WaveConfig.HealthMultiplierPerRound >= 0, "WaveConfig.HealthMultiplierPerRound debe ser >= 0")
	assert(WaveConfig.SpeedMultiplierPerRound >= 0, "WaveConfig.SpeedMultiplierPerRound debe ser >= 0")
	assert(WaveConfig.MaxHealthMultiplier >= 1, "WaveConfig.MaxHealthMultiplier debe ser >= 1")
	assert(WaveConfig.MaxSpeedMultiplier >= 1, "WaveConfig.MaxSpeedMultiplier debe ser >= 1")

	for round, ring in pairs(WaveConfig.RingUnlockRound) do
		assert(round >= 1, "WaveConfig.RingUnlockRound tiene una ronda inválida: " .. tostring(round))
		assert(
			ring == 1 or ring == 2 or ring == 3,
			"WaveConfig.RingUnlockRound." .. tostring(round) .. " debe ser un anillo 1/2/3, no " .. tostring(ring)
		)
	end

	for zombieTypeId, unlock in pairs(WaveConfig.SpecialTypeUnlocks) do
		assert(
			ZombieConfig.Types[zombieTypeId],
			"WaveConfig.SpecialTypeUnlocks referencia un ZombieType inválido: " .. tostring(zombieTypeId)
		)
		assert(unlock.MinRound >= 1, "WaveConfig.SpecialTypeUnlocks." .. zombieTypeId .. ".MinRound debe ser >= 1")
		assert(unlock.Weight > 0, "WaveConfig.SpecialTypeUnlocks." .. zombieTypeId .. ".Weight debe ser > 0")
	end
end

function ConfigurationService:Init(_registry: Types.ServiceRegistry)
	validate()
end

function ConfigurationService:Start() end

-- Acceso de solo lectura a los módulos de configuración ya validados.
function ConfigurationService.Get()
	return {
		Game = GameConfig,
		Match = MatchConfig,
		Party = PartyConfig,
		PlayerData = PlayerDataConfig,
		Remotes = RemotesConfig,
		Resource = ResourceConfig,
		Tool = ToolConfig,
		Weapon = WeaponConfig,
		Item = ItemConfig,
		Inventory = InventoryConfig,
		Zombie = ZombieConfig,
		Wave = WaveConfig,
	}
end

return ConfigurationService
