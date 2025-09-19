local codec = require('http-codec')
local http = require('coro-http')
local json = require('json')
local tls = require('tls')

local ResponseType = {
  SUCCESS = 204,
  INVALID_REQUEST = 400,
  UNAUTHORIZED = 401,
  NOT_FOUND = 404,
}

local function getHeaderValue(request, input)
  if request.headers then
    for key, value in pairs(request.headers) do
      if type(key) == 'string' and string.lower(key) == input then
        return value
      end
    end
  else
    for _, header in ipairs(request) do
      local key = header[1]

      if type(key) == 'string' and string.lower(key) == input then
        return header[2]
      end
    end
  end

  return nil
end

local function responseTypeToString(response)
  if response == ResponseType.SUCCESS then
    return 'No Content'
  elseif response == ResponseType.INVALID_REQUEST then
    return 'Bad Request'
  elseif response == ResponseType.UNAUTHORIZED then
    return 'Unauthorized'
  elseif response == ResponseType.NOT_FOUND then
    return 'Not Found'
  end
end

local Webhooks = {}

Webhooks.__index = Webhooks

function Webhooks:newWithAuthorization(authorization)
  local webhooks = setmetatable({}, self)

  webhooks.authorization = authorization
  webhooks.routes = {}

  return webhooks
end

function Webhooks:new(authorization)
  local webhooks = setmetatable({}, self)

  webhooks.authorization = authorization
  webhooks.routes = {}

  return webhooks
end

function Webhooks:add(path, callback, authorization)
  authorization = authorization or self.authorization

  if type(callback) ~= 'function' then
    error('argument \'callback\' must be a function')
  elseif type(authorization) ~= 'string' then
    error('route must have a clear authorization')
  end

  table.insert(self.routes, {
    path = path,
    authorization = authorization,
    callback = callback,
  })
end

function Webhooks:resolve(request, body)
  if request.method == 'POST' then
    for _, route in pairs(self.routes) do
      if string.sub(
        request.path,
        1,
        string.len(route.path)
      ) == route.path then
        local incomingAuthorization = getHeaderValue(request, 'authorization')

        if incomingAuthorization and incomingAuthorization == route.authorization then
          local json_body, err = json.decode(body)

          if json_body then
            route.callback(json_body)
          
            return ResponseType.SUCCESS
          else
            return ResponseType.INVALID_REQUEST
          end
        end

        return ResponseType.UNAUTHORIZED
      end
    end
  end

  return ResponseType.NOT_FOUND
end

function Webhooks:start(input)
  if not input or type(input.host) ~= 'string' or type(
    input.port
  ) ~= 'number' then
    error('missing host and port')
  end

  if input.key and input.cert then
    tls.createServer(
      {
        key = input.key,
        cert = input.cert,
      },
      function (socket)
        local decode = codec.decoder()
        local data = ''

        socket:on('data', function(chunk)
          data = data .. chunk

          if data:find('\r\n\r\n') then
            local request = decode(data, 1)
            
            if request then
              local body = data:match('\r\n\r\n(.*)')
              local contentLength = getHeaderValue(request, 'content-length')
  
              if contentLength and tonumber(contentLength) == #body then
                local response = self:resolve(request, body)
                local reason = responseTypeToString(response)
  
                socket:write(string.format('HTTP/1.1 %d %s\r\n\r\n%s', response, reason, reason))
                socket:destroy()
              end
            end
          end
        end)
      end
    ):listen(input.port, input.host)
  else
    http.createServer(input.host, input.port, function (request, body)
      local response = self:resolve(request, body)
      local reason = responseTypeToString(response)

      return {
        { 'Content-Type', 'text/html' },
        { 'Content-Length', tostring(#reason) },
        code = response,
        reason = reason,
        version = 1.1,
      }, reason
    end)
  end
end

return Webhooks
