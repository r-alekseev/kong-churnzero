local table_new             = require "table.new"
local cjson                 = require "cjson"

local ngx_header            = ngx.header
local ngx_resp              = ngx.resp

local AccessContext         = require "kong.plugins.churnzero.access"
local HeaderFilterContext   = require "kong.plugins.churnzero.header_filter"
local LogContext            = require "kong.plugins.churnzero.log"

local cjson_encode          = cjson.encode

local BasePlugin            = require("kong.plugins.base_plugin") 
local ChurnZeroPlugin       = BasePlugin:extend()

ChurnZeroPlugin.PRIORITY    = 13
ChurnZeroPlugin.VERSION     = "0.1.0"


local function produce_event( app_key, account_external_id, contact_external_id, event_date, event_name, quantity )
  return {
    -- Every request must include your appKey which can be found on the Admin > AppKey Page.
    ["appKey"]            = app_key,

    -- The accountExternalId is your unique record to identify your account. 
    -- This ID should also be in your CRM.
    ["accountExternalId"] = account_external_id,

    -- The contactExternalId must be unique within the account. 
    -- This could be a email address, a unique record that is also contained in your CRM, 
    -- or the ID of the contact record of your CRM.
    ["contactExternalId"] = contact_external_id,

    -- Must be 'trackEvent'.
    ["action"]            = 'trackEvent',

    -- The date of the event (defaults to time of API call) in format ISO-8601 ("2012-03-19T07:22Z")
    ["eventDate"]         = event_date,

    -- This is the unique name of the event (ie. "Sent Blog Post"). 
    -- If the Event Name is not found it will be created.
    ["eventName"]         = event_name,

    -- The number related to this event. 
    -- (ie. Commonly used to track things like email sent, etc)
    ["quantity"]          = quantity
  }
end


-- ctor.
-- @param[type=string] `name` Name of plugin using for logging.
function ChurnZeroPlugin:new( name )
  ChurnZeroPlugin.super.new( self, name or "churnzero" )
end


-- Executed for every request from a client and before it is being proxied to the upstream service.
-- @param[type=table] `conf` Plugin configuration.
function ChurnZeroPlugin:access( conf )
  ChurnZeroPlugin.super.access( self )

  local ngx_ctx       = ngx.ctx
  local uri           = ngx.var.uri

  -- catch events from route string
  local route_event_count, route_events = AccessContext 
    :new( conf ) 
    :catch_churnzero_route_events( uri )

  -- save events (based on route) to nginx context
  if not ngx_ctx.churnzero then ngx_ctx.churnzero = table_new( 0, 4 ) end
  ngx_ctx.churnzero.route_event_count = route_event_count
  ngx_ctx.churnzero.route_events = route_events 
end


-- Executed when all response headers bytes have been received from the upstream service.
-- @param[type=table] `conf` Plugin configuration.
function ChurnZeroPlugin:header_filter( conf )
  ChurnZeroPlugin.super.header_filter( self )

  local ngx_ctx           = ngx.ctx
  local consumer_headers  = ngx_header
  local upstream_headers  = ngx_resp.get_headers()

  -- catch events from headers
  local header_event_count, header_events = HeaderFilterContext 
    :new( conf ) 
    :catch_churnzero_header_events( consumer_headers, upstream_headers )

  -- save events (based on headers) to nginx context
  if not ngx_ctx.churnzero then ngx_ctx.churnzero = table_new( 0, 4 ) end
  ngx_ctx.churnzero.header_event_count = header_event_count
  ngx_ctx.churnzero.header_events = header_events 
end


-- Executed when the last response byte has been sent to the client.
-- @param[type=table] `conf` Plugin configuration.
function ChurnZeroPlugin:log( conf )
  ChurnZeroPlugin.super.log( self )

  local ngx_ctx     = ngx.ctx
  local ngx_var     = ngx.var
  local ngx_socket  = ngx.socket

  local ctx_churnzero = ngx_ctx.churnzero
  if not ctx_churnzero then return end

  -- load consumer info
  local authenticated_consumer = ngx_ctx.authenticated_consumer
  local authenticated_credential = ngx_ctx.authenticated_credential
  local remote_addr = ngx_var.remote_addr

  -- load events (based on headers) from nginx context
  local header_events = ctx_churnzero.header_events
  local header_event_count = ctx_churnzero.header_event_count

  -- load events (based on headers) from nginx context
  local route_events = ctx_churnzero.route_events
  local route_event_count = ctx_churnzero.route_event_count

  -- send http request to churnzero based on events from headers
  LogContext 
      :new( conf )
      :produce_churnzero_events( header_events, header_event_count, produce_event, authenticated_consumer, authenticated_credential, remote_addr )
      :produce_churnzero_events( route_events, route_event_count, produce_event, authenticated_consumer, authenticated_credential, remote_addr )
      :send_churnzero_request( ngx_socket, cjson_encode )

  -- cleanup nginx context
  ngx_ctx.churnzero = nil
end


return ChurnZeroPlugin

