local table_new             = require "table.new"
local socket_url            = require "socket.url"

-- luacheck: push ignore string
local string_len            = string.len
local string_format         = string.format
-- luacheck: pop

local Object                = require "kong.vendor.classic"
local LogFilterContext      = (Object):extend()

local ngx_log               = ngx.log

local ERR                   = ngx.ERR
local DEBUG                 = ngx.DEBUG

local HTTP = "http"
local HTTPS = "https"


function LogFilterContext:new( conf )

  self._conf = conf
  self._events = nil
  self._event_number = 0

  return self
end


-- If user authenticated, fills 'identifier' 
--   by 'authenticated_consumer' if 'authenticated_from' = "consumer" 
--   by 'authenticated_credential' if 'authenticated_from' = "credential" 
-- If user unauthenticated, fills 'identifier' 
--   by 'remote_addr' if 'unauthenticated_from' = "ip"
--   by 'unauthenticated_const' if 'unauthenticated_from' = "const"
local function get_external_id( conf, section, authenticated_consumer, authenticated_credential, remote_addr )

  local identifier = nil

  -- if authenticated
  if conf[ section ].authenticated_from == "consumer" then
    identifier = authenticated_consumer and ( authenticated_consumer.username or authenticated_consumer.custom_id or authenticated_consumer.id )
  elseif conf[ section ].authenticated_from == "credential" then
    identifier = authenticated_credential and authenticated_credential.key
  end

  -- if unauthenticated
  if not identifier then
    if conf[ section ].unauthenticated_from == "ip" then 
      identifier = remote_addr
    elseif conf[ section ].unauthenticated_from == "const" then 
      identifier = conf[ section ].unauthenticated_from_const
    end
  end

  identifier = conf[ section ].prefix .. identifier

  return identifier
end


local function generate_churnzero_payload( parsed_url, body )

  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end

  local content_length = string_len( body )

  local payload = string_format(
    "POST %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nCache-Control: no-cache\r\nContent-Length: %s\r\n\r\n%s",
    url, parsed_url.host, content_length, body )

  return payload
end


local function parse_url(host_url)

  local parsed_url = socket_url.parse( host_url )
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end

  return parsed_url
end


local function send( premature, ngx_socket, parsed_url, timeout, payload )

  if premature then return end

  local ok, err

  local host = parsed_url.host
  local port = tonumber( parsed_url.port )

  local sock = ngx_socket.tcp()
  sock:settimeout( timeout )

  ok, err = sock:connect( host, port )
  if not ok then
    ngx_log( ERR, "failed to connect to " .. host .. ":" .. tostring( port ) .. ": ", err ) 
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake( true, host, false )
    if err then
      ngx_log( ERR, "failed to do SSL handshake with " .. host .. ":" .. tostring( port ) .. ": ", err )
    end
  end

  ok, err = sock:send( payload )
  if not ok then
    ngx_log( ERR, "failed to send data to " .. host .. ":" .. tostring( port ) .. ": ", err )
    return
  end

  -- / self control (optional)

  ngx_log( ERR, "payload:\r\n" .. payload )

  local line, err = sock:receive()

  if not line then
  	ngx_log( ERR, "failed to receive status from " .. host .. ":" .. tostring( port ) .. ": ", err )
    return
  end

  if line ~= "HTTP/1.1 200 OK" then

    local chunk, err, partial = sock:receive( "*a" )

    if not chunk then
      ngx_log( ERR, "failed to receive body from " .. host .. ":" .. tostring( port ) .. ": ", err )
      return
    end

    ngx_log( ERR, "received " .. line .. "\r\n" .. chunk .. "\r\n" .. partial )
  end

  -- \ self control (optional)
end


function LogFilterContext:produce_churnzero_events( short_events, short_event_count, produce_event_f, authenticated_consumer, authenticated_credential, remote_addr )

  local conf = self._conf

  -- consumer unauthenticated and this is disabled
  if not authenticated_consumer and not conf.unauthenticated_enabled then return self end

  -- events collection is empty
  if short_event_count < 1 or not short_events then return self end

  local app_key = conf.app_key
  local event_date = os.date("!%Y-%m-%dT%H:%M:%S") .. conf.timezone

  local account_external_id = get_external_id( conf, "account", authenticated_consumer, authenticated_credential, remote_addr )
  local contact_external_id = get_external_id( conf, "contact", authenticated_consumer, authenticated_credential, remote_addr )

  local events = self._events or table_new( short_event_count, 0 ) 
  local event_number = self._event_number

  for _, short_event in ipairs( short_events ) do
    event_number = event_number + 1
    events[event_number] = produce_event_f(
      short_event.app_key or app_key,
      short_event.account_external_id or account_external_id,
      short_event.contact_external_id or contact_external_id,
      short_event.event_date or event_date,
      short_event.event_name,
      short_event.quantity or 1 )
  end

  self._event_number = event_number
  self._events = events

  return self
end


function LogFilterContext:send_churnzero_request( ngx_socket, serialize_f )

  local conf = self._conf

  local events = self._events
  local event_number = self._event_number
  
  if event_number == 0 or not events then return self end

  local body = serialize_f( events )

  local endpoint_url = conf.endpoint_url
  local timeout = conf.timeout

  local parsed_url = parse_url( endpoint_url )
  local payload = generate_churnzero_payload( parsed_url, body )

  local ok, err = ngx.timer.at( 0, send, ngx_socket, parsed_url, timeout, payload )
  if not ok then
  	ngx_log( ERR, "failed to create timer ", err )
  end

  return self
end


return LogFilterContext