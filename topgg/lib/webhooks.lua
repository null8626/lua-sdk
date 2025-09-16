local http = require('coro-http')
local json = require('json')
local tls = require('tls')

local Webhooks = {}

Webhooks.__index = Webhooks

function Webhooks:new_with_authorization(authorization)
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
    error("argument 'callback' must be a function")
  elseif type(authorization) ~= 'string' then
    error('route must have a clear authorization')
  end

  table.insert(self.routes, {
    path = path,
    authorization = authorization,
    callback = callback,
  })
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
      function(socket)
        local body = ''

        socket:on('data', function(chunk)
          body = body .. chunk

          if body:find('\r\n\r\n') then
            local method = body:match('^(%S+)')

            if method == 'POST' then
              local url = body:match('^%S+%s+(%S+)')
              local headers =
                (body:match('^(.-)\r\n\r\n') or ''):gmatch('[^\r\n]+')

              for _, route in pairs(self.routes) do
                if string.sub(url, 1, string.len(route.path)) == route.path then
                  for line in headers do
                    local key, value = line:match('^([^:]+):%s*(.*)$')

                    if key and string.lower(key) == 'authorization' then
                      if value ~= route.authorization then
                        socket:write(
                          'HTTP/1.1 401 Unauthorized\r\n\r\nUnauthorized'
                        )
                        socket:destroy()
                        return
                      end

                      local payload = body:match('\r\n\r\n(.*)')
                      local json_body = json.decode(payload or '')

                      if json_body then
                        route.callback(json_body)

                        socket:write('HTTP/1.1 204 No Content\r\n\r\n')
                      else
                        socket:write(
                          'HTTP/1.1 400 Bad Request\r\n\r\nInvalid JSON body'
                        )
                      end

                      socket:destroy()
                      return
                    end
                  end

                  socket:write('HTTP/1.1 401 Unauthorized\r\n\r\nUnauthorized')
                  socket:destroy()
                  return
                end
              end
            end

            socket:write('HTTP/1.1 404 Not Found\r\n\r\nNot Found')
            socket:destroy()
          end
        end)
      end
    ):listen(input.port, input.host)
  else
    http.createServer(input.host, input.port, function(request, body)
      if request.method == 'POST' then
        for _, route in pairs(self.routes) do
          if string.sub(
            request.path,
            1,
            string.len(route.path)
          ) == route.path then
            for _, header in ipairs(request) do
              if type(header[1]) == 'string' and string.lower(
                header[1]
              ) == 'authorization' then
                if header[2] == route.authorization then
                  local json_body, err = json.decode(body)

                  if json_body then
                    route.callback(json_body)

                    return {
                      { 'Content-Type', 'text/html' },
                      { 'Content-Length', '0' },
                      code = 204,
                      reason = 'No Content',
                      version = 1.1,
                    }, ''
                  else
                    return {
                      { 'Content-Type', 'text/html' },
                      { 'Content-Length', '17' },
                      code = 400,
                      reason = 'Bad Request',
                      version = 1.1,
                    }, 'Invalid JSON body'
                  end
                end
              end
            end

            return {
              { 'Content-Type', 'text/html' },
              { 'Content-Length', '12' },
              code = 401,
              reason = 'Unauthorized',
              version = 1.1,
            }, 'Unauthorized'
          end
        end
      end

      return {
        { 'Content-Type', 'text/html' },
        { 'Content-Length', '9' },
        code = 404,
        reason = 'Not Found',
        version = 1.1,
      }, 'Not Found'
    end)
  end
end

return Webhooks
