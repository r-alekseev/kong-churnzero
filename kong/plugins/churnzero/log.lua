local table_new             = require "table.new"
local socket_url                   = require "socket.url"

-- luacheck: push ignore string
local string_len            = string.len
local string_format         = string.format
local string_upper          = string.upper
-- luacheck: pop

local Object                = require "kong.vendor.classic"
local LogFilterContext      = (Object):extend()


local HTTP = "http"
local HTTPS = "https"


-- ctor.
-- @param[type=table] `conf` Plugin configuration.
-- @param[type=table] `debug` Debug object for loging purposes
function LogFilterContext:new(conf, debug)
  self._debug = debug
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
local function get_external_id(conf, section, authenticated_consumer, authenticated_credential, remote_addr, debug)

  debug :log_s("[get_external_id]") :log_t({ 
    authenticated_consumer = authenticated_consumer,
    authenticated_credential = authenticated_credential,
    remote_addr = remote_addr })

  local identifier = nil

  -- if authenticated
  if conf[section].authenticated_from == "consumer" then
    identifier = authenticated_consumer and (authenticated_consumer.username or authenticated_consumer.custom_id or authenticated_consumer.id)
  elseif conf[section].authenticated_from == "credential" then
    identifier = authenticated_credential and authenticated_credential.key
  end

  -- if unauthenticated
  if not identifier then
    if conf[section].unauthenticated_from == "ip" then 
      identifier = remote_addr
    elseif conf[section].unauthenticated_from == "const" then 
      identifier = conf[section].unauthenticated_const
    end
  end

  identifier = conf[section].prefix .. identifier

  debug :log_s("[get_external_id] identifier: " .. identifier) 

  return identifier
end


-- Generates the raw http message.
-- @param `parsed_url_query` contains the host details
-- @param `body`  Body of the message as a string (must be encoded according to the `content_type` parameter)
-- @return raw http message
local function generate_churnzero_payload(parsed_url, body, debug)
  local method = 'POST'
  local content_type = 'application/json'
  local cache_control = 'no-cache'

  debug :log_s("[generate_churnzero_payload]") :log_t({ 
    method = method,
    content_type = content_type,
    cache_control = cache_control })

  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end

  local content_length = string_len(body)

  -- TODO: add Keep-Alive
  -- local headers = string_format(
  --   "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: %s\r\nCache-Control: %s\r\n",
  --   method:upper(), url, parsed_url.host, content_type, cache_control)

  local headers = string_format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nContent-Type: %s\r\nCache-Control: %s\r\nContent-Length: %s\r\n",
    string_upper(method), url, parsed_url.host, content_type, cache_control, content_length)

  local payload = string_format("%s\r\n%s", headers, body)

  debug :log_s("[generate_churnzero_payload] payload: " .. (payload or "nil"))

  return payload
end


-- Parse host url.
-- @param `host_url` host url
-- @return `parsed_url` a table with host details like domain name, port, path etc
local function parse_url(host_url)
  local parsed_url = socket_url.parse(host_url)
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


-- Log to a Http endpoint.
-- This basically is structured as a timer callback.
-- @param `premature` see openresty ngx.timer.at function
-- @param `parsed_url` parsed url table including host, port and scheme
-- @param `timeout` 
-- @param `payload` raw http request payload to be logged
local function send(premature, ngx_socket, parsed_url, timeout, payload, debug)
  debug :log_s("[send]")

  if premature then return end

  debug :log_s("[send] premature ok")

  local ok, err

  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local sock = ngx_socket.tcp()
  sock:settimeout(timeout)
  debug :log_s("[send] [sock:connect(" .. (host or "nil") ..", " .. tostring(port or "nil") .. ")]")

  ok, err = sock:connect(host, port)
  if not ok then
    debug :log_s("[send] ERROR failed to connect to " .. host .. ":" .. tostring(port) .. ": " .. (err or ""))
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      debug :log_s("[send] ERROR failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": " .. (err or ""))
    end
  end

  ok, err = sock:send(payload)
  if not ok then
  	debug :log_s("[send] ERROR failed to send data to " .. host .. ":" .. tostring(port) .. ": " .. (err or ""))
  	return
  end

  debug :log_s("[send] sent payload: \r\n" .. (payload or "nil"))

  local line, err = sock:receive()

  debug :log_s("[send] sock:receive()")

  if not line then
    debug :log_s("[send] ERROR failed to receive status from " .. host .. ":" .. tostring(port) .. ": " .. (err or ""))
    return
  end

  debug :log_s("[send] status: " .. line or "nil")

  if line ~= "HTTP/1.1 200 OK" then

    debug :log_s("[send] sock:receive(\"*a\")")

    local chunk, err, partial = sock:receive("*a")

    if not chunk then
      debug :log_s("[send] ERROR failed to receive body from " .. host .. ":" .. tostring(port) .. ": " .. (err or ""))
      return
    end

    debug :log_s("[log] received \r\n" .. line .. "\r\n" .. chunk .. "\r\n" .. partial)

  end

  -- TODO: add keepalive
  -- ok, err = sock:setkeepalive(keepalive)
  -- if not ok then
  --   ngx.log(ngx.ERR, name .. "failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
  --   return
  -- end
end


-- Produces full events based on short events (based on f.e. headers or routes)
-- @param[type=table] `short_events` Table with short event data from headers or routes
-- @param[type=integer] `short_event_count` Count of items in 'short_events'
function LogFilterContext:produce_churnzero_events(short_events, short_event_count, produce_event, authenticated_consumer, authenticated_credential, remote_addr)
  local debug = self._debug :log_s("[produce_churnzero_events]")
  local conf = self._conf

  local app_key = conf.app_key
  local event_date = os.date("!%Y-%m-%dT%H:%M:%SZ") -- Z local event_date = os.date("!%Y-%m-%dT%H:%M:%SZ")

  local account_external_id = get_external_id(conf, "account", authenticated_consumer, authenticated_credential, remote_addr, debug)
  local contact_external_id = get_external_id(conf, "contact", authenticated_consumer, authenticated_credential, remote_addr, debug)

  debug :log_s("[produce_churnzero_events] attributes:") :log_t( {
    app_key = app_key,
    event_date = event_date,
    account_external_id = account_external_id,
    contact_external_id = contact_external_id,
  })

  local events = self._events or table_new(short_event_count, 0) 
  local event_number = self._event_number

  for _, short_event in ipairs(short_events) do
    event_number = event_number + 1
    events[event_number] = produce_event(
      short_event.app_key or app_key,
      short_event.account_external_id or account_external_id,
      short_event.contact_external_id or contact_external_id,
      short_event.event_date or event_date,
      short_event.event_name,
      short_event.quantity or 1)
  end

  self._event_number = event_number
  self._events = events

  debug 
  	:log_s("[produce_churnzero_events] event_number:" .. tostring(event_number) .. ", events: ") 
    :log_t(events)

  return self
end


-- Sends a request with events to ChurnZero using all events
-- @param[type=function] `serialize_f` Function for serialize events
function LogFilterContext:send_churnzero_request(ngx_socket, serialize_f)
  local debug = self._debug :log_s("[send_churnzero_request]")
  local conf = self._conf

  local events = self._events
  local event_number = self._event_number
  if event_number == 0 or not events then
  	return self
  end

  local body = serialize_f(events)

  debug :log_s("[send_churnzero_request] body: " .. (body or "nil"))

  local endpoint_url = conf.endpoint_url
  local timeout = conf.timeout

  local parsed_url = parse_url(endpoint_url)
  local payload = generate_churnzero_payload(parsed_url, body, debug)

  debug :log_s("[send_churnzero_request]:") :log_t({
  	parsed_url = parsed_url,
  	payload = payload})

  local ok, err = ngx.timer.at(0, send, ngx_socket, parsed_url, timeout, payload, debug)
  if not ok then
    debug :log_s("[send_churnzero_request] failed to create timer: ", err)
  end

  return self
end


return LogFilterContext