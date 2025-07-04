# Top.gg Lua SDK

The community-maintained Lua library for Top.gg.

## Installation

To install this library, place [the `topgg` directory](https://github.com/top-gg-community/lua-sdk/tree/main/topgg) beside your root directory, then install the following dependencies from the lit repository:

```
creationix/coro-http
luvit/json
luvit/secure-socket
luvit/timer
luvit/tls
```

## Setting up

```lua
local topgg = require('topgg')

local client = topgg.Api:new(os.getenv('TOPGG_TOKEN'), 'BOT_ID')
```

## Usage

### Getting a bot

```lua
local bot = client:get_bot('264811613708746752')
```

### Getting several bots

```lua
local bots = client:get_bots({
  sort = 'date',
  limit = 50,
  offset = 0
})
```

### Getting your bot's voters

```lua
--                               Page number
local voters = client:get_voters(1)
```

### Check if a user has voted for your bot

```lua
local hasVoted = client:has_voted('661200758510977084')
```

### Getting your bot's server count

```lua
local server_count = client:get_server_count()
```

### Posting your bot's server count

```lua
client:post_server_count(bot:get_server_count())
```

### Automatically posting your bot's server count every few minutes

With Discordia:

```lua
local discordia = require('discordia')

local bot = discordia.Client()

bot:on('ready', function()
  print(bot.user.username .. ' is now ready!')

  autoposter = client:new_autoposter(bot, function(server_count)
    print('Successfully posted ' .. server_count .. ' servers to Top.gg!s')
  end)
end)

bot:on('ready', function()
  print('Logged in as ' .. bot.user.username)
end)

bot:run('Bot ' .. os.getenv('BOT_TOKEN'))

-- ...

autoposter:stop() -- Optional
```

### Checking if the weekend vote multiplier is active

```lua
local is_weekend = client:is_weekend()
```

### Generating widget URLs

#### Large

```lua
local widget_url = topgg.Widget.large('discord_bot', '574652751745777665')
```

#### Votes

```lua
local widget_url = topgg.Widget.votes('discord_bot', '574652751745777665')
```

#### Owner

```lua
local widget_url = topgg.Widget.owner('discord_bot', '574652751745777665')
```

#### Social

```lua
local widget_url = topgg.Widget.social('discord_bot', '574652751745777665')
```

### Webhooks

#### Being notified whenever someone voted for your bot

##### HTTP

```lua
local webhooks = topgg.Webhooks:new(os.getenv('MY_TOPGG_WEBHOOK_SECRET'))

webhooks:add('/votes', function(vote)
  print('A user with the ID of ' .. vote.user .. ' has voted us on Top.gg!')
end)

webhooks:start({
  host = '127.0.0.1',
  port = 8080
})
```

##### HTTPS

```lua
local fs = require('fs')

local webhooks = topgg.Webhooks:new(os.getenv('MY_TOPGG_WEBHOOK_SECRET'))

webhooks:add('/votes', function(vote)
  print('A user with the ID of ' .. vote.user .. ' has voted us on Top.gg!')
end)

webhooks:start({
  key = fs.readFileSync('server.key'),
  cert = fs.readFileSync('server.crt'),
  host = '127.0.0.1',
  port = 8080
})
```