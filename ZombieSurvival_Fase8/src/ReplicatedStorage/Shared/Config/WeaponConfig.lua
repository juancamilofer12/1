--!strict
--[[
	WeaponConfig.lua

	Parámetros del sistema de armas (Fase 7): daño, cadencia, tamaño
	de cargador, munición de reserva, tiempo de recarga, alcance,
	retroceso, rareza y precio — exactamente los campos que pide la
	Fase 7, centralizados acá en vez de números sueltos hardcodeados
	en WeaponService/CombatService. Mismo patrón que ToolConfig
	(Fase 6) y ResourceConfig (Fase 5).

	Dos formas según WeaponKind:
	- Melee: Damage, CooldownSeconds (cadencia entre golpes), Range
	  (alcance corto), Rarity, Price. Sin campos de munición/recarga
	  (quedan `nil`, no `0`, para que un chequeo accidental de
	  `weapon.MagazineSize` en una rama de código de arma de fuego
	  falle ruidosamente en vez de comportarse como "cargador vacío").
	- Firearm: además de Damage/CooldownSeconds (acá cadencia = fire
	  rate)/Range/Rarity/Price, agrega MagazineSize, StartingReserveAmmo
	  (con la que un jugador empieza al recibir el arma por primera
	  vez, ver InventoryConfig.StarterItems), MaxReserveAmmo (tope que
	  no se puede superar recogiendo más munición — sin sistema de
	  loot todavía, pero el campo queda listo), ReloadSeconds y Recoil.

	`Recoil`: valor puramente numérico sin unidad definida todavía.
	Placeholder de datos para que un futuro sistema de cámara/precisión
	en el cliente lo consuma (patrón de "shake" o desviación de mira);
	esta fase NO simula precisión ni dispersión de disparos — cada
	`Combat_RangedAttack` válido impacta si el objetivo es válido y
	está en rango, sin aleatoriedad. Ver CombatService.

	Balanceo: valores de placeholder razonables, no definitivos —
	mismo criterio que ResourceConfig/ToolConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)
local WeaponType = require(ReplicatedStorage.Shared.Enums.WeaponType)
local WeaponKind = require(ReplicatedStorage.Shared.Enums.WeaponKind)
local ItemRarity = require(ReplicatedStorage.Shared.Enums.ItemRarity)

local WeaponConfig = {
	Weapons = {
		[WeaponType.Machete] = {
			Kind = WeaponKind.Melee,
			Damage = 25,
			CooldownSeconds = 0.6,
			Range = 6,
			Rarity = ItemRarity.Common,
			Price = 150,
		},
		[WeaponType.BaseballBat] = {
			Kind = WeaponKind.Melee,
			Damage = 20,
			CooldownSeconds = 0.5,
			Range = 6,
			Rarity = ItemRarity.Common,
			Price = 120,
		},
		[WeaponType.Pistol] = {
			Kind = WeaponKind.Firearm,
			Damage = 18,
			CooldownSeconds = 0.25,
			MagazineSize = 12,
			StartingReserveAmmo = 36,
			MaxReserveAmmo = 90,
			ReloadSeconds = 1.5,
			Range = 60,
			Recoil = 2,
			Rarity = ItemRarity.Uncommon,
			Price = 400,
		},
		[WeaponType.Rifle] = {
			Kind = WeaponKind.Firearm,
			Damage = 28,
			CooldownSeconds = 0.12,
			MagazineSize = 30,
			StartingReserveAmmo = 90,
			MaxReserveAmmo = 180,
			ReloadSeconds = 2.2,
			Range = 120,
			Recoil = 5,
			Rarity = ItemRarity.Rare,
			Price = 900,
		},
	},
}

return TableUtils.DeepFreeze(WeaponConfig)
