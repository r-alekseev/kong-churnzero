local table_new               = require "table.new"

local ngx_resp                = ngx.resp

-- local ERR                  = ngx.ERR

local Object                  = require "kong.vendor.classic"
local HeaderFilterContext     = (Object):extend()


-- ctor.
-- @param[type=table] `conf` Plugin configuration.
-- @param[type=table] `debug` Debug object for loging purposes
function HeaderFilterContext:new(conf, debug)
  self._debug = debug
  self._conf = conf

  return self
end


local event_name_suffix = "EventName-"
local event_quantity_suffix = "Quantity-"

local function get_churnzero_headers_event(headers, headers_prefix, number, debug)

  debug:log_s("[get_churnzero_headers_event]")

  local event_name_header_name        = headers_prefix .. event_name_suffix .. tostring(number)
  local event_name                    = headers[event_name_header_name]

  debug:log_s("[get_churnzero_headers_event] event_name: " .. 
    (event_name or "nil") .. ", event_name_header_name: " .. 
    (event_name_header_name or "nil"))

  if not event_name then 
    return nil 
  end

  local event_quantity_header_name    = headers_prefix .. event_quantity_suffix .. tostring(number)
  local quantity                      = headers[event_quantity_header_name]

  debug:log_s("[get_churnzero_headers_event] quantity: " .. 
    (quantity or "nil") .. ", event_quantity_header_name: " .. 
    (event_quantity_header_name or "nil"))

  local header_event = {
    event_name    = event_name,
    quantity      = quantity,
  }

  return header_event
end


local function iter_churnzero_headers_events(headers, headers_prefix, debug)
  
  debug:log_s("[iter_churnzero_headers_events]")

  local number = 0
  return function ()
    number = number + 1
    return get_churnzero_headers_event(headers, headers_prefix, number, debug)
  end
end

-- Parses headers with prefix set in `conf` and saves events data to `ngx_ctx`
-- @param[type=table] `conf` Plugin configuration.
-- @param[type=table] `ngx_header` Table for obtain headers, that should be `ngx.headers`
-- @return table A table containing the new headers.
function HeaderFilterContext:catch_churnzero_header_events(conf, ngx_headers)
  local debug = self._debug :log_s("[catch_churnzero_header_events]")
  local conf = self._conf

  local headers               = ngx_resp.get_headers()

  local header_event_number   = 0
  local header_events         = table_new(0, 4)

  local headers_prefix        = conf.events_from_header_prefix

  for header_event in iter_churnzero_headers_events(headers, headers_prefix, debug) do
    header_event_number = header_event_number + 1
    header_events[header_event_number] = header_event
    
    debug :log_s("[catch_churnzero_header_events] header_event #" .. tostring(header_event_number) .. ":")
          :log_t(header_event)
  end

  return header_event_number, header_events
end

return HeaderFilterContext
