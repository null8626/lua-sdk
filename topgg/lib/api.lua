local http = require('coro-http');
local request = http.request;
local json = require('json');
local f, gsub, byte = string.format, string.gsub, string.byte;
local insert, concat = table.insert, table.concat;
local running = coroutine.running;
local base_url = 'https://top.gg/api/v1';
local payloadRequired = {PUT = true, PATCH = true, POST = true};

local function parseErrors(ret, errors, key)
   for k, v in pairs(errors) do
      if k == '_errors' then
         for _, err in ipairs(v) do
            insert(ret, f('%s in %s : %s', err.code, key or 'payload', err.message));
         end
      else
         if key then
            parseErrors(ret, v, f(k:find('^[%a_][%a%d_]*$') and '%s.%s' or tonumber(k) and '%s[%d]' or '%s[%q]', k, v));
         else
            parseErrors(ret, v, k);
         end
      end
   end
   return concat(ret, '\n\t');
end

local Api = require('class')('Api');

function Api:init(token, id)
   if type(token) ~= 'string' or type(id) ~= 'string' then
      error("argument 'token' must be a string");
   end

   self.id = id;
   self.token = token;
end

local function tohex(char)
   return f('%%%02X', byte(char));
end

local function urlencode(obj)
   return (gsub(tostring(obj), '%W', tohex));
end

function Api:request(method, path, body, query)
   local _, main = running();
   if main then
      error('Cannot make HTTP request outside a coroutine', 2);
   end

   local url = base_url .. path;
   local index = 0
   
   if query and next(query) then
     for k, v in pairs(query) do
       local prefix = index == 0 and '?' or '&';
       index = index + 1;

       url = url .. prefix;
       url = url .. urlencode(k) .. '=' .. urlencode(v);
     end
   end

   local req = {
      {'Authorization', self.token}
   };

   if payloadRequired[method] then
      body = body and json.encode(body) or '{}';
      insert(req, {'Content-Type', 'application/json'});
      insert(req, {'Content-Length', #body});
   end

   local data, err = self:commit(method, url, req, body);
   if data then
      return data;
   else
      return nil, err;
   end
end

function Api:commit(method, url, req, body)
   local success, res, msg = pcall(request, method, url, req, body);

   if not success then
      return nil, res;
   end

   for i, v in ipairs(res) do
      res[v[1]:lower()] = v[2];
      res[i] = nil;
   end

   local data = res['content-type']:find('application/json', 1, true) and json.decode(msg, 1, json.null) or msg;

   if res.code < 300 then
      return data, nil;
   else if type(data) == 'table' then
      if data.code and data.message then
         msg = f('HTTP Error %i : %s', data.code, data.message);
      else
         msg = 'HTTP Error';
      end

      if data.errors then
         msg = parseErrors({msg}, data.errors);
      end
   end
end
   return nil, msg;
end

function Api:postStats(stats)
   if not stats or (not stats.serverCount and not stats.server_count) then
      error('Server count missing');
   end

   if type(stats.serverCount) ~= 'number' and type(stats.server_count) ~= 'number' then
      error("'serverCount' must be a number");
   end

   local server_count = stats.serverCount or stats.server_count;

   if server == 0 then
      error("'serverCount' must be non-zero");
   end

   local __stats = {
      server_count = server_count,
   };

   return self:request('POST', '/bots/stats', __stats);
end

function Api:getStats()
   return self:request('GET', '/bots/stats');
end

function Api:getBot(id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   return self:request('GET', f('/bots/%s', id));
end

function Api:getBots(query)
   if query then
      if type(query.sort) == 'string' and query.sort ~= 'monthlyPoints' and query.sort ~= 'id' and query.sort ~= 'date' then
         error("argument 'sort' must be either 'monthlyPoints', 'id', or 'date'");
      end

      if type(query.limit) == 'number' and query.limit > 500 then
         error("argument 'limit' must not exceed 500");
      end

      if type(query.offset) == 'number' and query.offset < 0 then
         error("argument 'offset' must be positive");
      end

      if type(query.fields) == 'table' then
         query.fields = concat(query.fields, ',');
      end
   end

   return self:request('GET', '/bots', nil, query);
end

function Api:getVotes(page)
   if type(page) ~= 'number' or page < 1 then
      error("argument 'page' must be a valid number");
   end

   return self:request('GET', f('/bots/%s/votes?page=%d', self.id, page));
end

function Api:hasVoted(id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end
   local data = self:request('GET', f('/bots/check?userId=%s', id));

   return not not data.voted;
end

function Api:isWeekend()
   local data = self:request('GET', '/weekend');
   return not not data.is_weekend;
end

return Api;