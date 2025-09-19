local http = require('coro-http')
local timer = require('timer')
local json = require('json')
local base64 = require('base64')

local baseUrl = 'https://top.gg/api'

local function parseErrors(ret, errors, key)
  for k, v in pairs(errors) do
    if k == '_errors' then
      for _, err in ipairs(v) do
        table.insert(
          ret,
          string.format(
            '%s in %s : %s',
            err.code or err.status,
            key or 'payload',
            err.message or err.detail
          )
        )
      end
    else
      if key then
        parseErrors(
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
        parseErrors(ret, v, k)
      end
    end
  end

  return table.concat(ret, '\n\t')
end

local function addBase64Padding(data)
  data = data:gsub('-', '+'):gsub('_', '/')

  local rem = #data % 4

  if rem ~= 0 then
    data = data .. string.rep('=', 4 - rem)
  end
  
  return data
end

local function parseToken(token)
  local tokenSegments = {}
  
  for seg in string.gmatch(token, '([^.]+)') do
    table.insert(tokenSegments, seg)
  end

  if #tokenSegments ~= 3 then
    return nil
  end

  local tokenData = base64.decode(addBase64Padding(tokenSegments[2]))
  local obj = json.decode(tokenData)

  if obj and obj.id then
    return obj.id
  end

  return nil
end

local function urlencode(obj)
  return (string.gsub(tostring(obj), '%W', function(char)
    return string.format('%%%02X', string.byte(char))
  end))
end

local Api = {}

Api.__index = Api

function Api:new(token)
  if type(token) ~= 'string' then
    error('argument \'token\' must be a string')
  end

  local id = parseToken(token)

  if not id then
    error('argument \'token\' is not a valid Top.gg API token')
  end

  local object = setmetatable({}, self)

  object.token = token
  object.id = id

  return object
end

function Api:__request(method, path, body, query)
  local _, main = coroutine.running()

  if main then
    error('Cannot make HTTP request outside of a coroutine', 2)
  end

  local url = baseUrl .. path
  local index = 0

  if query and next(query) then
    for k, v in pairs(query) do
      local prefix = index == 0 and '?' or '&'

      index = index + 1
      url = url .. prefix .. urlencode(k) .. '=' .. urlencode(v)
    end
  end

  local request = { { 'Authorization', 'Bearer ' .. self.token } }

  if method ~= 'GET' then
    body = body and json.encode(body) or '{}'

    table.insert(request, { 'Content-Type', 'application/json' })
    table.insert(request, { 'Content-Length', #body })
  end

  return self:__commit(method, url, request, body)
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
    res['content-type']:find('json', 1, true) and json.decode(
      msg,
      1,
      json.null
    ) or msg

  if res.code < 300 then
    return data, nil
  elseif type(data) == 'table' then
    if (data.code or data.status) and (data.message or data.detail) then
      msg = string.format('HTTP Error %i : %s', data.code or data.status, data.message or data.detail)
    else
      msg = 'HTTP Error'
    end

    if data.errors then
      msg = parseErrors({ msg }, data.errors)
    end
  end

  return nil, msg
end

function Api:postStats(stats)
  if not stats or not (stats.serverCount or stats.server_count) then
    error('Server count missing')
  end

  local newStats = {
    server_count = stats.serverCount or stats.server_count,
  }

  if type(newStats.server_count) ~= 'number' or newStats.server_count <= 0 then
    error('\'server_count\' must be a number and non-zero')
  end

  local _, res = self:__request('POST', '/bots/stats', newStats)
  return res
end

function Api:getStats(_id)
  return self:__request('GET', '/bots/stats')
end

function Api:getBot(id)
  if type(id) ~= 'string' then
    error('argument \'id\' must be a string')
  end

  return self:__request('GET', string.format('/bots/%s', id))
end

function Api:getBots(query)
  if query then
    if type(
      query.sort
    ) == 'string' and query.sort ~= 'monthlyPoints' and query.sort ~= 'id' and query.sort ~= 'date' then
      error('argument \'sort\' must be either \'monthlyPoints\', \'id\', or \'date\'')
    elseif type(query.limit) == 'number' and query.limit > 500 then
      error('argument \'limit\' must not exceed 500')
    elseif type(query.offset) == 'number' and query.offset < 0 then
      error('argument \'offset\' must be positive')
    end

    if type(query.fields) == 'table' then
      query.fields = table.concat(query.fields, ',')
    end
  end

  return self:__request('GET', '/bots', nil, query)
end

function Api:getUser(id)
  error('getUser() is deprecated since API v0')
end

function Api:getVotes(page)
  if type(page) ~= 'number' or page < 1 then
    error('argument \'page\' must be a valid number')
  end

  return self:__request(
    'GET',
    string.format('/bots/%s/votes?page=%d', self.id, page)
  )
end

function Api:hasVoted(id)
  if type(id) ~= 'string' then
    error('argument \'id\' must be a string')
  end

  local data, err = self:__request('GET', string.format('/bots/check?userId=%s', id))

  if data then
    return data.voted ~= 0, nil
  end

  return nil, err
end

function Api:isWeekend()
  local data, err = self:__request('GET', '/weekend')

  if data then
    return data.is_weekend, nil
  end

  return nil, err
end

function Api:newAutoposter(client, posted, delay)
  if not client or not client.guilds or not client.user or not client.user.id then
    error(
      'argument \'client\' must be a discordia/discordia-like client instance'
    )
  elseif type(delay) ~= 'number' or delay < 900000 then
    delay = 900000
  end

  local id = timer.setInterval(delay, function()
    coroutine.resume(
      coroutine.create(function()
        local serverCount = #client.guilds

        if serverCount ~= 0 then
          self:postStats({ server_count = serverCount })

          if type(posted) == 'function' then
            posted(serverCount)
          end
        end
      end)
    )
  end)

  return { stop = function()
    timer.clearInterval(id)
  end }
end

return Api
