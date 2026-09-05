--!strict
--[[
	ItemCategory.lua

	Enum (tabla congelada) con las categorías de objeto que
	InventoryService/EquipmentService entienden. Todo ItemId
	administrado por el inventario (armas, herramientas, recursos,
	curación, utilidad) tiene una entrada en ItemConfig.Items con una
	de estas categorías.

	La categoría es también lo que determina en qué slot de
	equipamiento puede entrar un objeto (ver
	EquipmentService.SLOT_ACCEPTS): Weapon -> PrimaryWeapon/
	SecondaryWeapon, Tool -> Tool, Healing -> Healing, Utility ->
	Utility. Resource no es equipable en ningún slot (solo vive en la
	mochila): no tiene entrada en SLOT_ACCEPTS.
]]

local ItemCategory = {
	Weapon = "Weapon",
	Tool = "Tool",
	Resource = "Resource",
	Healing = "Healing",
	Utility = "Utility",
}

table.freeze(ItemCategory)

return ItemCategory
