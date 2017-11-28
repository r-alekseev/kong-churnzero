local ngx_log               = ngx.log
local ngx_socket            = ngx.socket

local ngx_socket_tcp        = ngx_socket.tcp

local ERR                   = ngx.ERR
local DEBUG                 = ngx.DEBUG


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

  local sock = ngx_socket_tcp()
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

  ngx_log( DEBUG, "payload:\r\n" .. payload )

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


return {
  parse_url = parse_url,
  send = function ( parsed_url, timeout, payload )
    local ok, err = ngx.timer.at( 0, send, ngx_socket, parsed_url, timeout, payload )
    if not ok then
      ngx_log( ERR, "failed to create timer ", err )
    end
  end
}