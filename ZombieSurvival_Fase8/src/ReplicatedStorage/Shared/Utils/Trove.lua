--!strict
--[[
	Trove.lua

	Gestor de limpieza de recursos (conexiones, instancias, funciones
	o cualquier objeto con :Destroy()). Implementación propia, sin
	dependencias externas.

	Uso típico dentro de un servicio o por-jugador:
		local trove = Trove.new()
		trove:Add(part)
		trove:Add(signal:Connect(fn))
		trove:Add(function() print("cleanup") end)
		...
		trove:Destroy() -- limpia TODO lo agregado, en orden inverso
]]

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable(
	{} :: {
		_items: { any },
	},
	Trove
))

local function cleanupItem(item: any)
	local itemType = typeof(item)

	if itemType == "RBXScriptConnection" then
		item:Disconnect()
	elseif itemType == "Instance" then
		item:Destroy()
	elseif itemType == "function" then
		item()
	elseif itemType == "table" and typeof(item.Destroy) == "function" then
		item:Destroy()
	elseif itemType == "table" and typeof(item.Disconnect) == "function" then
		item:Disconnect()
	else
		warn("[Trove] No se sabe cómo limpiar un item de tipo:", itemType)
	end
end

function Trove.new(): Trove
	local self = setmetatable({
		_items = {},
	}, Trove)
	return self
end

-- Agrega un recurso a limpiar más adelante. Retorna el mismo recurso
-- para poder encadenar: local part = trove:Add(Instance.new("Part"))
function Trove:Add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

-- Quita un recurso de la lista sin limpiarlo (por si se limpia manualmente).
function Trove:Remove(item: any)
	local index = table.find(self._items, item)
	if index then
		table.remove(self._items, index)
	end
end

-- Limpia y vacía todo lo acumulado hasta ahora, sin destruir el Trove.
-- Útil para trove por-ronda que se reutiliza entre partidas.
function Trove:Clean()
	-- Orden inverso: lo último agregado se limpia primero.
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		self._items[i] = nil
		local ok, err = pcall(cleanupItem, item)
		if not ok then
			warn("[Trove] Error limpiando item:", err)
		end
	end
end

function Trove:Destroy()
	self:Clean()
end

return Trove
