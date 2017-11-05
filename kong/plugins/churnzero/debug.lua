local table_new		= require "table.new"

-- local DEBUG 		= ngx.DEBUG
local ERR 			= ngx.ERR

local ngx_log   	= ngx.log

local Object 		= require "kong.vendor.classic"

--------------------------------------------------------------------------------------------
-- SYNOPSIS: -------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------
-- local debug = (require "kong.plugins.churnzero.debug"):new(true, cjson.encode, "thename")
--------------------------------------------------------------------------------------------
-- debug:log_s("abc 123", ERR)
--
-- >>abc 123
--------------------------------------------------------------------------------------------
-- debug:log_t({ a = 1, b = "b", c = { "z", "x", "c" }}, ERR)
--
-- >> {"b":"b","a":1,"c":["z","x","c"]}
--------------------------------------------------------------------------------------------
-- debug:accumulate({ a1 = 1, b1 = "b", c1 = { "z1", "x1", "c1" }})
-- debug:accumulate({ a2 = 11, b2 = "bb", c2 = { "z2", "x2", "c2" }})
-- debug:log_flush(ERR)
--
-- >> {"a1":1,"a2":11,"c1":["z1","x1","c1"],"b1":"b","b2":"bb","c2":["z2","x2","c2"]}
--------------------------------------------------------------------------------------------
-- debug:accumulate({ q = "q", w = "ww", e = "eee", r = { "q", "w", "e", "r" }})
-- debug:log_flush(ERR)
--
-- >> {"r":["q","w","e","r"],"w":"ww","q":"q","e":"eee"}
--------------------------------------------------------------------------------------------

local Debug 		= (Object):extend()

local function empty_table()
	return table_new(0, 4)
end

-- ctor.
-- @param `enabled` is debug enabled
-- @param `serialize_f` serialize function
-- @param `name` name to logging
function Debug:new(enabled, serialize_f, name)
	self._enabled = enabled ~= nil and serialize_f ~= nil
	self._serialize_f = serialize_f
	self._name = name

	self._values_t = empty_table()

	return self
end

-- Accumulates debug information 
-- @param `values_t` a table which values adds to debug values
function Debug:accumulate(values_t)

	if not self._enabled then return end

	for k, v in pairs(values_t) do
		self._values_t[k] = v
	end
end

-- Flushes all debug values to error.log using serializer
-- @param `level` ngx log level
function Debug:log_flush(level)

	if not self._enabled then return end

	local values_t = self._values_t
	self:log_t(values_t, level)
	self._values_t = empty_table()

	return self
end

-- Logs values to error.log 
-- @param `values_t` a table with values for log
-- @param `level` nginx log level
function Debug:log_t(values_t, level)

	if not self._enabled then return end

	local serialize_f = self._serialize_f
	if not serialize_f then return end
	local serialized = serialize_f(values_t)
	self:log_s(serialized, level)

	return self
end

-- Logs a string to error.log 
-- @param `str` a string for log
-- @param `level` nginx log level
function Debug:log_s(str, level)

	if not self._enabled then return end

	local name = self._name
	ngx_log(level or ERR, name and "[" .. name .. "]" or "", str or "nil")

	return self
end

return Debug