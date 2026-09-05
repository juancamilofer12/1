--!strict
--[[
	TableUtils.lua

	Utilidades puras de tablas. Sin estado, sin efectos secundarios
	salvo los explícitamente indicados (DeepFreeze muta la tabla
	recibida y también la retorna).
]]

local TableUtils = {}

-- Copia profunda de una tabla (no copia funciones ni userdata, solo
-- valores primitivos y subtablas).
function TableUtils.DeepCopy<T>(original: T): T
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in pairs(original :: any) do
		if type(value) == "table" then
			copy[key] = TableUtils.DeepCopy(value)
		else
			copy[key] = value
		end
	end

	return (copy :: any) :: T
end

-- Congela recursivamente una tabla para volverla inmutable.
-- Útil para congelar módulos de Config y evitar mutaciones
-- accidentales desde cualquier punto del código.
function TableUtils.DeepFreeze<T>(tbl: T): T
	if type(tbl) ~= "table" then
		return tbl
	end

	for _, value in pairs(tbl :: any) do
		if type(value) == "table" and not table.isfrozen(value) then
			TableUtils.DeepFreeze(value)
		end
	end

	table.freeze(tbl :: any)
	return tbl
end

return TableUtils
