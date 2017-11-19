local table_new               = require "table.new"

local string_match            = string.match

local Object                  = require "kong.vendor.classic"
local AccessContext           = (Object):extend()


function AccessContext:new( conf )
  
  self._conf = conf

  return self
end


local function match_route_pattern( route_event_pattern, uri )

  -- divide pattern to matching part and event_name part
  local matching_part, event_name_part = string_match( route_event_pattern, "^(%S+)%s+(%S+)$" )

  if not matching_part or not event_name_part then return nil end

  -- apply matching part to uri
  local match = string_match( uri, matching_part )

  if not match then return nil end
  
  return { event_name = event_name_part }

end


function AccessContext:catch_churnzero_route_events( uri )

  local conf = self._conf

  local route_event_number     = 0
  local route_events           = table_new( 2, 0 )

  local events_from_route_patterns = conf.events_from_route_patterns

  if not events_from_route_patterns or #events_from_route_patterns == 0 then return self end

  -- get events from route 
  for _, route_event_pattern in ipairs(events_from_route_patterns) do

    local route_event = match_route_pattern( route_event_pattern, uri )

    if route_event then
      route_event_number = route_event_number + 1
      route_events[ route_event_number ] = route_event
    end
  end

  return route_event_number, route_events
end

return AccessContext