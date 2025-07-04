local http = require('coro-http')
local timer = require('timer')
local json = require('json')

local base_url = 'https://top.gg/api/v1'

local function parse_errors(ret, errors, key)
  for k, v in pairs(errors) do
    if k == '_errors' then
      for _, err in ipairs(v) do
        table.insert(
          ret,
          string.format(
            '%s in %s : %s',
            err.code,
            key or 'payload',
            err.message
          )
        )
      end
    else
      if key then
        parse_errors(
          ret,
          v,
          string.format(
            k:find('^[%a_][%a%d_]*$') and '%s.%s' or tonumber(
              k
            ) and '%s[%d]' or '%s[%q]',
            k,
            v
          )
        )
      else
        parse_errors(ret, v, k)
      end
    end
  end

  return table.concat(ret, '\n\t')
end

local Api = {}

Api.__index = Api

function Api:new(token, id)
  if type(token) ~= 'string' or type(id) ~= 'string' then
    error("argument 'token' must be a string")
  end

  local object = setmetatable({}, self)

  object.token = token
  object.id = id

  return object
end

local function urlencode(obj)
  return (string.gsub(tostring(obj), '%W', function(char)
    return string.format('%%%02X', string.byte(char))
  end))
end

function Api:__request(method, path, body, query)
  local _, main = coroutine.running()

  if main then
    error('Cannot make HTTP request outside of a coroutine', 2)
  end

  local url = base_url .. path
  local index = 0

  if query and next(query) then
    for k, v in pairs(query) do
      local prefix = index == 0 and '?' or '&'

      index = index + 1
      url = url .. prefix .. urlencode(k) .. '=' .. urlencode(v)
    end
  end

  local request = { { 'Authorization', self.token } }

  if method ~= 'GET' then
    body = body and json.encode(body) or '{}'

    table.insert(request, { 'Content-Type', 'application/json' })
    table.insert(request, { 'Content-Length', #body })
  end

  local data, err = self:__commit(method, url, request, body)

  if data then
    return data
  else
    return nil, err
  end
end

function Api:__commit(method, url, request, body)
  local success, res, msg = pcall(http.request, method, url, request, body)

  if not success then
    return nil, res
  end

  for i, v in ipairs(res) do
    res[v[1]:lower()] = v[2]
    res[i] = nil
  end

  local data =
    res['content-type']:find('application/json', 1, true) and json.decode(
      msg,
      1,
      json.null
    ) or msg

  if res.code < 300 then
    return data, nil
  elseif type(data) == 'table' then
    if data.code and data.message then
      msg = string.format('HTTP Error %i : %s', data.code, data.message)
    else
      msg = 'HTTP Error'
    end

    if data.errors then
      msg = parse_errors({ msg }, data.errors)
    end
  end

  return nil, msg
end

function Api:post_server_count(server_count)
  if type(server_count) ~= 'number' or server_count <= 0 then
    error("'server_count' must be a number and non-zero")
  end

  return self:__request('POST', '/bots/stats', { server_count = server_count })
end

function Api:get_server_count()
  local stats = self:__request('GET', '/bots/stats')

  return stats and stats.server_count
end

function Api:get_bot(id)
  if type(id) ~= 'string' then
    error("argument 'id' must be a string")
  end

  return self:__request('GET', string.format('/bots/%s', id))
end

function Api:get_bots(query)
  if query then
    if type(
      query.sort
    ) == 'string' and query.sort ~= 'monthlyPoints' and query.sort ~= 'id' and query.sort ~= 'date' then
      error("argument 'sort' must be either 'monthlyPoints', 'id', or 'date'")
    elseif type(query.limit) == 'number' and query.limit > 500 then
      error("argument 'limit' must not exceed 500")
    elseif type(query.offset) == 'number' and query.offset < 0 then
      error("argument 'offset' must be positive")
    end

    if type(query.fields) == 'table' then
      query.fields = table.concat(query.fields, ',')
    end
  end

  return self:__request('GET', '/bots', nil, query)
end

function Api:get_voters(page)
  if type(page) ~= 'number' or page < 1 then
    error("argument 'page' must be a valid number")
  end

  return self:__request(
    'GET',
    string.format('/bots/%s/votes?page=%d', self.id, page)
  )
end

function Api:has_voted(id)
  if type(id) ~= 'string' then
    error("argument 'id' must be a string")
  end

  local data = self:__request('GET', string.format('/bots/check?userId=%s', id))

  return not not data.voted
end

function Api:is_weekend()
  local data = self:__request('GET', '/weekend')

  return not not data.is_weekend
end

function Api:new_autoposter(client, posted, delay)
  if not client or not client.guilds or not client.user or not client.user.id then
    error(
      "argument 'client' must be a discordia/discordia-like client instance"
    )
  elseif type(delay) ~= 'number' or delay < 900000 then
    delay = 900000
  end

  local id = timer.setInterval(delay, function()
    coroutine.resume(
      coroutine.create(function()
        local server_count = 5 -- #client.guilds
        self:post_server_count(server_count)

        if type(posted) == 'function' then
          posted(server_count)
        end
      end)
    )
  end)

  return { stop = function()
    timer.clearInterval(id)
  end }
end

return Api
