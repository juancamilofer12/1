--!strict
--[[
	Signal.lua

	Implementación propia y mínima de un patrón pub/sub, equivalente
	a un BindableEvent pero en memoria de Luau puro (más liviano y
	sin pasar por la capa de replicación de Roblox).

	No depende de ningún asset ni paquete externo.

	Uso:
		local signal = Signal.new()
		local conn = signal:Connect(function(a, b) ... end)
		signal:Fire(1, 2)
		conn:Disconnect()
		signal:Destroy()
]]

local Signal = {}
Signal.__index = Signal

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal = typeof(setmetatable(
	{} :: {
		_listeners: { (...any) -> () },
		_destroyed: boolean,
	},
	Signal
))

function Signal.new(): Signal
	local self = setmetatable({
		_listeners = {},
		_destroyed = false,
	}, Signal)
	return self
end

function Signal:Connect(callback: (...any) -> ()): Connection
	if self._destroyed then
		error("No se puede conectar a un Signal ya destruido", 2)
	end

	local listeners = self._listeners
	table.insert(listeners, callback)

	local connection = {
		Connected = true,
	}

	local function disconnect(_self: Connection)
		if not connection.Connected then
			return
		end
		connection.Connected = false
		local index = table.find(listeners, callback)
		if index then
			table.remove(listeners, index)
		end
	end

	(connection :: any).Disconnect = disconnect

	return connection :: Connection
end

function Signal:Fire(...: any)
	if self._destroyed then
		return
	end
	-- Copiamos la lista para tolerar Connect/Disconnect durante el Fire.
	local listenersSnapshot = table.clone(self._listeners)
	for _, callback in ipairs(listenersSnapshot) do
		local ok, err = pcall(callback, ...)
		if not ok then
			warn("[Signal] Error en listener:", err)
		end
	end
end

function Signal:Destroy()
	self._destroyed = true
	table.clear(self._listeners)
end

return Signal
