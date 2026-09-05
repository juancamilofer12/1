--!strict
--[[
	ItemRarity.lua

	Enum (tabla congelada) con los niveles de rareza que puede tener
	un objeto (por ahora, solo armas usan esto vía WeaponConfig.Rarity).
	Puramente informativo en esta fase: no afecta drop rates, precios
	de tienda ni ninguna otra lógica todavía (no existe economía ni
	loot table aún) — es un campo de datos que WeaponConfig necesita
	centralizar según el pedido de la Fase 7 ("rareza, precio"), listo
	para que una futura fase de loot/economía lo consuma.
]]

local ItemRarity = {
	Common = "Common",
	Uncommon = "Uncommon",
	Rare = "Rare",
	Epic = "Epic",
}

table.freeze(ItemRarity)

return ItemRarity
