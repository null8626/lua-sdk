  return {
    name = "topgg-lua",
    version = "1.0.0",
    description = "A library for top.gg, in lua",
    tags = { "dbl", "topgg", "top.gg" },
    license = "MIT",
    author = { name = "matthewthechickenman", email = "65732060+matthewthechickenman@users.noreply.github.com" },
    homepage = "https://github.com/Top-gg-Community/lua-sdk",
    dependencies = {
      "creationix/coro-http",
      "luvit/json",
      "luvit/secure-socket",
      "luvit/timer"
    },
    files = {
      "**.lua",
      "!test*"
    }
  }
  