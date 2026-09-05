--!strict
--[[
	WeaponType.lua

	Enum (tabla congelada) con los identificadores de arma que existen
	en el juego. Usar SIEMPRE estas constantes en vez de strings
	sueltos, igual que ResourceType.lua/ToolType.lua.

	Fase 7: 2 armas cuerpo a cuerpo (Machete, BaseballBat) y 2 de
	fuego (Pistol, Rifle) — el mínimo para probar ambas ramas del
	sistema (WeaponConfig.Kind = "Melee" | "Firearm"). Armas
	adicionales (escopeta, arma cuerpo a cuerpo pesada, etc.) son de
	fases posteriores y se agregan acá cuando les toque, sin tocar
	WeaponService/CombatService.
]]

local WeaponType = {
	Machete = "Machete",
	BaseballBat = "BaseballBat",
	Pistol = "Pistol",
	Rifle = "Rifle",
}

table.freeze(WeaponType)

return WeaponType
