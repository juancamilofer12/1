--!strict
--[[
	WeaponKind.lua

	Enum (tabla congelada) con las dos categorías de arma que existen:
	cuerpo a cuerpo ("Melee") y de fuego ("Firearm"). WeaponConfig
	etiqueta cada arma con uno de estos dos valores; CombatService lo
	usa para decidir qué RemoteFunction (Combat_MeleeAttack /
	Combat_RangedAttack) acepta cada WeaponId, y WeaponService lo usa
	para saber qué armas necesitan estado de munición.
]]

local WeaponKind = {
	Melee = "Melee",
	Firearm = "Firearm",
}

table.freeze(WeaponKind)

return WeaponKind
