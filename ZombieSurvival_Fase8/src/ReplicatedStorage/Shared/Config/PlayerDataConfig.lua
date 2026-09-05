--!strict
--[[
	PlayerDataConfig.lua

	Configuración del sistema de datos de jugador: nombre del
	DataStore, versión de esquema actual y cuántos reintentos
	hacer ante fallos transitorios de la API de DataStores.

	La versión de esquema (SchemaVersion) permite en el futuro
	migrar datos viejos sin romper compatibilidad.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtils = require(ReplicatedStorage.Shared.Utils.TableUtils)

local PlayerDataConfig = {
	DataStoreName = "ZombieSurvival_PlayerData_v1",
	SchemaVersion = 1,

	-- Reintentos ante errores transitorios de DataStoreService.
	MaxRetries = 3,
	RetryBackoffSeconds = 2,

	-- Plantilla base de datos por defecto para un jugador nuevo.
	-- Se completa con UserId/SessionStart en tiempo de ejecución.
	-- `InventorySlots`/`Equipment` (Fase 7, reemplazan el `Inventory`
	-- temporal de la Fase 6): se dejan vacíos acá a propósito.
	-- `PlayerDataService.buildDefaultData` es quien arma los slots
	-- vacíos (según InventoryConfig.SlotCount) y coloca el kit inicial
	-- (InventoryConfig.StarterItems) — no se hace acá para no acoplar
	-- el esquema de datos al tamaño/contenido de ese kit.
	-- `PlayerDataService.buildDefaultData` hace una copia profunda de
	-- esta tabla, así que cada jugador arranca con su propia `{}` y
	-- nunca comparte la referencia.
	DefaultTemplate = {
		DataVersion = 1,
		InventorySlots = {},
		Equipment = {},
	},
}

return TableUtils.DeepFreeze(PlayerDataConfig)
