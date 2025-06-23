# Top.gg Lua SDK

The community-maintained Lua library for Top.gg.

## Installation

To install this library, place [the `topgg` directory](https://github.com/top-gg-community/lua-sdk/tree/main/topgg) beside your root directory, then install the following dependencies from the lit repository:

```
creationix/coro-http
luvit/json
luvit/secure-socket
luvit/timer
```

## Setting up

```lua
local topgg = require("topgg");

local botId = "BOT_ID";

topgg.Api:init(os.getenv("TOPGG_TOKEN"), botId);
```

## Usage

### Getting a bot

```lua
local bot = topgg.Api:getBot("264811613708746752");
```

### Getting several bots

```lua
local bots = topgg.Api:getBots({
  sort = "date",
  limit = 50,
  offset = 0
});
```

### Getting your bot's voters

```lua
--                                Page number
local voters = topgg.Api:getVotes(1);
```

### Check if a user has voted for your bot

```lua
local hasVoted = topgg.Api:hasVoted("661200758510977084");
```

### Getting your bot's server count

```lua
local stats = topgg.Api:getStats();
local serverCount = stats.server_count;
```

### Posting your bot's server count

```lua
topgg.Api:postStats({
  serverCount = bot:getServerCount()
});
```

### Automatically posting your bot's server count every few minutes

With Discordia:

```lua
local discordia = require("discordia");
local client = discordia.Client();

client:on('ready', function()
  print(client.user.username .. " is now ready!");

  autoposter = topgg.AutoPoster:init(os.getenv("TOPGG_TOKEN"), client);

  autoposter:on("posted", function()
    print("Posted stats to Top.gg!");
  end);
end);

client:run("Bot " .. os.getenv("BOT_TOKEN"));
```

### Checking if the weekend vote multiplier is active

```lua
local isWeekend = topgg.Api:isWeekend();
```

### Generating widget URLs

#### Large

```lua
local widgetUrl = topgg.Widget.large("discord_bot", "574652751745777665");
```

#### Votes

```lua
local widgetUrl = topgg.Widget.votes("discord_bot", "574652751745777665");
```

#### Owner

```lua
local widgetUrl = topgg.Widget.owner("discord_bot", "574652751745777665");
```

#### Social

```lua
local widgetUrl = topgg.Widget.social("discord_bot", "574652751745777665");
```