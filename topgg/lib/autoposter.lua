local Api = require('api');
local EventEmitter = require('EventEmitter');
local timer = require('timer');

EventEmitter:__init()

local AutoPoster = require('class')('AutoPoster', EventEmitter);

function AutoPoster:init(apiToken, client)
  if not client or not client.guilds or not client.user or not client.user.id then
    error("argument 'client' must be a discordia/discordia-like client instance");
  end

  Api:init(apiToken, client.user.id)

  timer.setInterval(900000, function()
    local poster = coroutine.create(function()
      local stats = {serverCount = #client.guilds}
      Api:postStats(stats);
      self:emit('posted');
    end);

    coroutine.resume(poster);
  end);

  return self;
end

return AutoPoster;
