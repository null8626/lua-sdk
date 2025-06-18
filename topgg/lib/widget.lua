local base_url = 'https://top.gg/api/v1';

local Widget = {};

function Widget.large(ty, id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   if ty ~= 'discord_bot' and ty ~= 'discord_server' then
      error("argument 'ty' must be 'discord_bot' or 'discord_server'");
   end

   return string.format('%s/widgets/large/%s/%s', base_url, ty:gsub('_', '/'), id);
end

function Widget.votes(ty, id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   if ty ~= 'discord_bot' and ty ~= 'discord_server' then
      error("argument 'ty' must be 'discord_bot' or 'discord_server'");
   end

   return string.format('%s/widgets/small/votes/%s/%s', base_url, ty:gsub('_', '/'), id);
end

function Widget.owner(ty, id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   if ty ~= 'discord_bot' and ty ~= 'discord_server' then
      error("argument 'ty' must be 'discord_bot' or 'discord_server'");
   end

   return string.format('%s/widgets/small/owner/%s/%s', base_url, ty:gsub('_', '/'), id);
end

function Widget.social(ty, id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   if ty ~= 'discord_bot' and ty ~= 'discord_server' then
      error("argument 'ty' must be 'discord_bot' or 'discord_server'");
   end

   return string.format('%s/widgets/small/social/%s/%s', base_url, ty:gsub('_', '/'), id);
end

return Widget