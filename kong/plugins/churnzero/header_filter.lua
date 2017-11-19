local table_new               = require "table.new"

local Object                  = require "kong.vendor.classic"
local HeaderFilterContext     = (Object):extend()


function HeaderFilterContext:new( conf )
  
  self._conf = conf

  return self
end


local event_name_suffix           = "EventName"
local quantity_suffix             = "Quantity"
local account_external_id_suffix  = "AccountExternalId"
local contact_external_id_suffix  = "ContactExternalId"
local app_key_suffix              = "AppKey"
local event_date_suffix           = "EventDate"

local function get_churnzero_headers_event( consumer_headers, upstream_headers, headers_prefix, hide_headers, number )

  local number_postfix = number and ( "-" .. tostring(number) ) or ""

  local event_name_header_name          = headers_prefix .. event_name_suffix .. number_postfix
  local event_name                      = upstream_headers[ event_name_header_name ]

  if not event_name then return nil end

  local quantity_header_name            = headers_prefix .. quantity_suffix .. number_postfix
  local quantity                        = upstream_headers [ quantity_header_name ]

  local account_external_id_header_name = headers_prefix .. account_external_id_suffix .. number_postfix
  local account_external_id             = upstream_headers [ account_external_id_header_name ]

  local contact_external_id_header_name = headers_prefix .. contact_external_id_suffix .. number_postfix
  local contact_external_id             = upstream_headers [ contact_external_id_header_name ]

  local app_key_header_name             = headers_prefix .. app_key_suffix .. number_postfix
  local app_key                         = upstream_headers [ app_key_header_name ]

  local event_date_header_name          = headers_prefix .. event_date_suffix .. number_postfix
  local event_date                      = upstream_headers [ event_date_header_name ]

  local header_event = {
    event_name            = event_name,
    quantity              = quantity,
    account_external_id   = account_external_id,
    contact_external_id   = contact_external_id,
    app_key               = app_key,
    event_date            = event_date 
  }

  if hide_headers then
    consumer_headers[ event_name_header_name ]           = nil
    consumer_headers[ quantity_header_name ]             = nil
    consumer_headers[ account_external_id_header_name ]  = nil
    consumer_headers[ contact_external_id_header_name ]  = nil
    consumer_headers[ app_key_header_name ]              = nil
    consumer_headers[ event_date_header_name ]           = nil
  end

  return header_event
end


local function iter_churnzero_headers_events_with_number_postfix( consumer_headers, upstream_headers, headers_prefix, hide_churnzero_headers )

  local number = 0
  return function ()

    number = number + 1
    return get_churnzero_headers_event( consumer_headers, upstream_headers, headers_prefix, hide_churnzero_headers, number )
  end
end


function HeaderFilterContext:catch_churnzero_header_events( consumer_headers, upstream_headers )

  local conf = self._conf

  local header_event_number     = 0
  local header_events           = table_new( 2, 0 )

  local headers_prefix          = conf.events_from_header_prefix
  local hide_churnzero_headers  = conf.hide_churnzero_headers

  -- get events from headers with number postfix
  for header_event_n in iter_churnzero_headers_events_with_number_postfix( consumer_headers, upstream_headers, headers_prefix, hide_churnzero_headers ) do
    header_event_number = header_event_number + 1
    header_events[ header_event_number ] = header_event_n
  end

  -- get events from headers without number postfix
  local header_event = get_churnzero_headers_event( consumer_headers, upstream_headers, headers_prefix, hide_churnzero_headers )
  if header_event then
    header_event_number = header_event_number + 1
    header_events[ header_event_number ] = header_event
  end

  return header_event_number, header_events
end

return HeaderFilterContext
