local base_url = 'https://top.gg/api/v1';

local Widget = {};

function Widget.large(id)
   if type(id) ~= 'string' then
      error("argument 'id' must be a string");
   end

   return string.format('%s/widgets/large/%s', base_url, id);
end

return Widget