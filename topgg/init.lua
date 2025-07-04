package.path =
  './deps/?/init.lua;./deps/?.lua;./topgg/lib/?.lua;./deps/secure-socket/?.lua;' .. package.path

return {
  Api = require('api'),
  Webhooks = require('webhooks'),
  Widget = require('widget'),
  test = function()
    print('[topgg-lua TEST] Library loaded successfully')
  end,
}
