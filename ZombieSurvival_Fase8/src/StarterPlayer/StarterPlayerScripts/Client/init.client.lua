--!strict
--[[
	init.client.lua

	Bootstrap del cliente. Valida que el pipeline de remotes funciona
	de punta a punta invocando "Ping", y luego inicializa los
	controladores de cliente reales (Fase 2: PartyUI; Fase 6:
	ToolClient; Fase 7: InventoryClient, WeaponClient).

	Orden de Init() importa: InventoryClient.Init() pide el snapshot
	inicial de mochila/equipamiento y DEBE correr antes que
	ToolClient/WeaponClient, que dependen de ese cache para encontrar
	en qué slot está un objeto antes de pedir equiparlo.

	Fases futuras agregarán acá (o en submódulos requeridos desde
	este archivo) el resto de los controladores de cliente.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetClient = require(ReplicatedStorage.Shared.Net.NetClient)
local PartyUI = require(script.Party.PartyUI)
local InventoryClient = require(script.Inventory.InventoryClient)
local ToolClient = require(script.Tools.ToolClient)
local WeaponClient = require(script.Weapons.WeaponClient)

local ok, serverTime = pcall(NetClient.InvokeServer, "Ping")

if ok then
	print("[Bootstrap Cliente] Conectado. Hora del servidor:", serverTime)
else
	warn("[Bootstrap Cliente] Falló el Ping inicial al servidor:", serverTime)
end

PartyUI.Init()
InventoryClient.Init()
ToolClient.Init()
WeaponClient.Init()
