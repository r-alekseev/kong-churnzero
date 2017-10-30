local cjson   = require "cjson"
local url     = require "socket.url"
local newtab  = require "table.new"

local ngx_log   = ngx.log
local ngx_resp  = ngx.resp

local string_format = string.format
local string_match  = string.match
local cjson_encode  = cjson.encode


local ChurnZeroHandler = require("kong.plugins.base_plugin"):extend()

ChurnZeroHandler.PRIORITY = 13
ChurnZeroHandler.VERSION = "0.1.0"


local HTTP = "http"
local HTTPS = "https"


-- Search 'event_header_value' in 'headers' by 'header_name' 
-- Splits the 'event_header_value' value to 'event_name' and 'quantity' using 'delimiter'
-- Returns 'event_name' and 'quantity'
local function get_event_name_quantity(headers, header_name, delimiter)

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.headers = headers or "nil"
  ngx.ctx.churnzero.debug.header_filter.header_name = header_name or "nil"
  ngx.ctx.churnzero.debug.header_filter.delimiter = delimiter or "nil"

  local pattern = "([^"..delimiter.."]+)"..delimiter.."([^"..delimiter.."]*)"
  local default_quantity = 1

  local event_header_value = headers[header_name]

  if not event_header_value then
    return false, nil, nil
  end

  local event_name, quantity = delimiter ~= nil and string_match(event_header_value, pattern) or event_header_value, default_quantity

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.event_header_value = event_header_value or "nil"
  ngx.ctx.churnzero.debug.header_filter.pattern = pattern or "nil"
  ngx.ctx.churnzero.debug.header_filter.event_name = event_name or "nil"
  ngx.ctx.churnzero.debug.header_filter.quantity = quantity or "nil"

  return true, event_name, quantity
end


-- If user authenticated, fills 'identifier' by 'authenticated_consumer' or 'authenticated_credential' depends on 'contact_external_id_from' value
-- If user unauthenticated, fills 'identifier' by 'remote_addr' or 'enabled' by false depends on 'contact_external_id_unauthenticated' value
local function get_contact_external_id(authenticated_consumer, authenticated_credential, remote_addr, contact_external_id_from, contact_external_id_unauthenticated)

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.authenticated_consumer = authenticated_consumer or "nil"
  ngx.ctx.churnzero.debug.header_filter.authenticated_credential = authenticated_credential or "nil"
  ngx.ctx.churnzero.debug.header_filter.remote_addr = remote_addr or "nil"
  ngx.ctx.churnzero.debug.header_filter.contact_external_id_from = contact_external_id_from or "nil"
  ngx.ctx.churnzero.debug.header_filter.contact_external_id_unauthenticated = contact_external_id_unauthenticated or "nil"

  local enabled = true
  local identifier = nil

  if contact_external_id_from == "consumer" then
    identifier = authenticated_consumer and (authenticated_consumer.username or authenticated_consumer.custom_id or authenticated_consumer.id)
  elseif contact_external_id_from == "credential" then
    identifier = authenticated_credential and authenticated_credential.key
  end

  if not identifier then
    if contact_external_id_unauthenticated == "ip" then
      identifier = remote_addr
    elseif contact_external_id_unauthenticated == "disabled" then
      enabled = false
    end
  end

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.enabled = enabled
  ngx.ctx.churnzero.debug.header_filter.identifier = identifier or "nil"

  return enabled, identifier
end


local function make_request_body(app_key, account_external_id, contact_external_id, event_date, event_headers, event_header_number)

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.app_key = app_key or "nil"
  ngx.ctx.churnzero.debug.header_filter.account_external_id = account_external_id or "nil"
  ngx.ctx.churnzero.debug.header_filter.contact_external_id = contact_external_id or "nil"
  ngx.ctx.churnzero.debug.header_filter.event_date = event_date or "nil"
  ngx.ctx.churnzero.debug.header_filter.event_headers = event_headers or "nil"
  ngx.ctx.churnzero.debug.header_filter.event_header_number = event_header_number or "nil"

  local events = newtab(event_header_number, 0)
  local event_number = 1

  for _, event_header in ipairs(event_headers) do
    events[event_number] = {
      app_key = app_key,
      account_external_id = account_external_id,
      contact_external_id = contact_external_id,
      action = 'trackEvent',
      event_date = event_date,
      event_name = event_header.name,
      quantity = event_header.quantity
    }

    event_number = event_number + 1
  end

  local body = cjson_encode(events)

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.app_key = app_key or "nil"
  ngx.ctx.churnzero.debug.header_filter.events = events or "nil"
  ngx.ctx.churnzero.debug.header_filter.event_number = event_number or "nil"

  return body
end


-- Generates the raw http message.
-- @param `parsed_url_query` contains the host details
-- @param `body`  Body of the message as a string (must be encoded according to the `content_type` parameter)
-- @return raw http message
local function generate_churnzero_payload(parsed_url, body)

  local method = 'POST'
  local content_type = 'application/json'
  local cache_control = 'no-cache'

  ngx.ctx.churnzero.debug.header_filter.method = method or "nil"
  ngx.ctx.churnzero.debug.header_filter.content_type = content_type or "nil"
  ngx.ctx.churnzero.debug.header_filter.cache_control = cache_control or "nil"

  local url
  if parsed_url.query then
    url = parsed_url.path .. "?" .. parsed_url.query
  else
    url = parsed_url.path
  end

  -- TODO: add Keep-Alive
  -- local headers = string_format(
  --   "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: %s\r\nCache-Control: %s\r\n",
  --   method:upper(), url, parsed_url.host, content_type, cache_control)

  local headers = string_format(
    "%s %s HTTP/1.1\r\nHost: %s\r\nContent-Type: %s\r\nCache-Control: %s\r\n",
    method:upper(), url, parsed_url.host, content_type, cache_control)

  local payload = string_format("%s\r\n%s", headers, body)

  ngx.ctx.churnzero.debug.header_filter.payload = payload or "nil"

  return payload
end


-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details like domain name, port, path etc
local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
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

  -- DEBUG
  ngx.ctx.churnzero.debug.header_filter.parsed_url = parsed_url or "nil"

  return parsed_url
end


-- Log to a Http end point.
-- This basically is structured as a timer callback.
-- @param `premature` see openresty ngx.timer.at function
-- @param `parsed_url` parsed url table including host, port and scheme
-- @param `timeout` 
-- @param `payload` raw http request payload to be logged
-- @param `name` the plugin name (used for logging purposes in case of errors etc.)
local function log(premature, parsed_url, timeout, payload, name)

  if premature then
    return
  end
  name = "[" .. name .. "] "

  local ok, err

  local host = parsed_url.host
  local port = tonumber(parsed_url.port)

  local sock = ngx.socket.tcp()
  sock:settimeout(timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if parsed_url.scheme == HTTPS then
    local _, err = sock:sslhandshake(true, host, false)
    if err then
      ngx.log(ngx.ERR, name .. "failed to do SSL handshake with " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  end

  ok, err = sock:send(payload)
  if not ok then
    ngx.log(ngx.ERR, name .. "failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  -- TODO: add keepalive
  -- ok, err = sock:setkeepalive(keepalive)
  -- if not ok then
  --   ngx.log(ngx.ERR, name .. "failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
  --   return
  -- end
end


-- ctor.
function ChurnZeroHandler:new(name)
  ChurnZeroHandler.super.new(self, name or "churnzero")
end


-- The goal of this method is to populate ngx.ctx.churnzero.event_headers collection
function ChurnZeroHandler:header_filter(conf)
  ChurnZeroHandler.super.header_filter(self)

  local ctx = ngx.ctx

  -- TODO: IMPLEMENTATION NOTES
  -- TODO: Support of many events with many settings is necessary
  -- TODO: Each service MAY emit many X-ChurnZero-EventName-* headers (X-ChurnZero-EventName-1, X-ChurnZero-EventName-2, ...)
  -- TODO: Each service MAY emit additional headers, associated (by numbers) with ^^^^^ (X-ChurnZero-Quantity-1, X-ChurnZero-AccountExternalId-1, ..)
  -- TODO: We need to test it all huh

  -- DEBUG
  ngx.ctx.churnzero = { debug = { header_filter = { } } }

  -- obtain eventName and quantity parameters

  local headers = ngx_resp.get_headers()

  local event_header_number = 1
  ctx.churnzero.event_headers = { }

  -- TODO: support multiple headers/events
  local header_name = conf.event_from_response_header.header_name
  local delimiter = conf.event_from_response_header.event_name_quantity_delimiter

  local header_exists, event_name, quantity = get_event_name_quantity (
    headers, 
    header_name, 
    delimiter 
  )

  if header_exists then

    ctx.churnzero.event_headers[event_header_number] = {
      name = event_name,
      quantity = quantity
    }

    event_header_number = event_header_number + 1
  end

  ctx.churnzero.event_header_number = event_header_number
end

-- The goal of this method is to send an asynchronous http request to ChurnZero
function ChurnZeroHandler:log(conf)
  ChurnZeroHandler.super.log(self)

  local ctx = ngx.ctx
  local var = ngx.var

  -- obtain contactExternalId parameter

  local authenticated_consumer = ctx.authenticated_consumer
  local authenticated_credential = ctx.authenticated_credential
  local remote_addr = var.remote_addr

  local contact_external_id_from = conf.contact_external_id.from
  local contact_external_id_unauthenticated = conf.contact_external_id.unauthenticated

  local enabled, contact_external_id = get_contact_external_id (
    authenticated_consumer, 
    authenticated_credential, 
    remote_addr, 
    contact_external_id_from, 
    contact_external_id_unauthenticated 
  )

  if not enabled or not contact_external_id then
    return
  end

  -- make request body

  local app_key = conf.app_key
  local account_external_id = conf.account_external_id
  -- MISSED: The date of the event (defaults to time of API call) in format ISO-8601 ("2012-03-19T07:22Z")
  local event_date = nil

  local event_headers = ctx.churnzero.event_headers
  local event_header_number = ctx.churnzero.event_header_number

  local body = make_request_body (
    app_key, 
    account_external_id, 
    contact_external_id, 
    event_date, 
    event_headers,
    event_header_number
  )

  -- send request asynchronously
  -- TODO: add keepalive

  local endpoint_url = conf.endpoint_url
  local timeout = conf.timeout

  local parsed_url = parse_url(endpoint_url)

  local payload = generate_churnzero_payload (
    parsed_url, 
    body
  )


  local ok, err = ngx.timer.at(0, log, parsed_url, timeout, payload, self._name)
  if not ok then
    ngx_log(ngx.ERR, "[" .. self._name .. "] failed to create timer: ", err)
  end


  local debug_json = cjson_encode(ctx.churnzero)
  local conf_json = cjson_encode(conf)
  ngx_log(ngx.ERR, "[" .. self._name .. "] TRACE LOG EVENT: ", debug_json, conf_json)

end


return ChurnZeroHandler
