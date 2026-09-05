--!strict
--[[
	ItemConfig.lua

	Catálogo único de todo ItemId que InventoryService/EquipmentService
	saben manejar: a qué ItemCategory pertenece, si apila (Stackable)
	y cuánto por stack (MaxStack), y si es consumible (Consumable +
	HealAmount para objetos de curación).

	No duplica los datos que ya viven en WeaponConfig/ToolConfig (daño,
	cadencia, etc. de un arma/herramienta siguen leyéndose de ahí): acá
	solo se agrega la metadata que hace falta para que un ItemId pueda
	vivir dentro de un ItemStack de la mochila (Types.ItemStack) y
	moverse/apilarse/equiparse de forma genérica sin que
	InventoryService necesite saber si un ItemId es un arma, una
	herramienta o un recurso.

	Los ItemId de armas/herramientas/recursos son exactamente los
	mismos strings que WeaponType/ToolType/ResourceType ya definen
	(mismo criterio que ToolConfig.EffectiveAgainst mapeando contra
	ResourceType en vez de inventar una segunda taxonomía): un
	`WeaponType.Machete` es el mismo ItemId tanto en WeaponConfig.Weapons
	como en ItemConfig.Items.

	Objetos no equipables (Resource) simplemente no tienen entrada en
	EquipmentService.SLOT_ACCEPTS — viven en la mochila pero nunca
	pueden moverse a un slot de equipamiento.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

local WeaponType = require(ReplicatedStorage.Shared.Enums.WeaponType)
local ToolType = require(ReplicatedStorage.Shared.Enums.ToolType)
local ResourceType = require(ReplicatedStorage.Shared.Enums.ResourceType)
local ConsumableType = require(ReplicatedStorage.Shared.Enums.ConsumableType)
local UtilityItemType = require(ReplicatedStorage.Shared.Enums.UtilityItemType)
local ItemCategory = require(ReplicatedStorage.Shared.Enums.ItemCategory)

local ItemConfig = {
	Items = {
		-- Armas: nunca apilan (cada unidad ocupa su propio slot/su
		-- propio slot de equipamiento) — no existe todavía el
		-- concepto de "copia" de un arma con desgaste individual, así
		-- que MaxStack = 1 es simplemente "una unidad por slot".
		[WeaponType.Machete] = { Category = ItemCategory.Weapon, Stackable = false, MaxStack = 1 },
		[WeaponType.BaseballBat] = { Category = ItemCategory.Weapon, Stackable = false, MaxStack = 1 },
		[WeaponType.Pistol] = { Category = ItemCategory.Weapon, Stackable = false, MaxStack = 1 },
		[WeaponType.Rifle] = { Category = ItemCategory.Weapon, Stackable = false, MaxStack = 1 },

		-- Herramientas: mismo criterio que las armas.
		[ToolType.WoodcutterAxe] = { Category = ItemCategory.Tool, Stackable = false, MaxStack = 1 },
		[ToolType.Pickaxe] = { Category = ItemCategory.Tool, Stackable = false, MaxStack = 1 },

		-- Recursos: apilan alto, coherente con que ResourceConfig ya
		-- entrega de a varias unidades por golpe/nodo.
		[ResourceType.Wood] = { Category = ItemCategory.Resource, Stackable = true, MaxStack = 99 },
		[ResourceType.Stone] = { Category = ItemCategory.Resource, Stackable = true, MaxStack = 99 },
		[ResourceType.Metal] = { Category = ItemCategory.Resource, Stackable = true, MaxStack = 99 },
		[ResourceType.Scrap] = { Category = ItemCategory.Resource, Stackable = true, MaxStack = 99 },

		-- Curación: apilan moderado, y son Consumable (ver
		-- InventoryService.ConsumeItem). HealAmount es cuánto restaura
		-- Humanoid.Health al consumirse, tope en Humanoid.MaxHealth.
		[ConsumableType.Bandage] = {
			Category = ItemCategory.Healing,
			Stackable = true,
			MaxStack = 10,
			Consumable = true,
			HealAmount = 25,
		},
		[ConsumableType.Medkit] = {
			Category = ItemCategory.Healing,
			Stackable = true,
			MaxStack = 5,
			Consumable = true,
			HealAmount = 75,
		},

		-- Utilidad: placeholder sin lógica de uso propia esta fase
		-- (ver UtilityItemType.lua) — solo existe para que el slot de
		-- Utilidad tenga con qué probarse de punta a punta.
		[UtilityItemType.Flashlight] = { Category = ItemCategory.Utility, Stackable = false, MaxStack = 1 },
	},
}

return TableUtils.DeepFreeze(ItemConfig)
