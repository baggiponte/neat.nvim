-- The `nvim-notify` notify backend: rcarriga/nvim-notify, which must be
-- installed. It is required and set up on the first message, not at startup.

local opts = {} ---@type table options for require("notify").setup()
local notify ---@type table? the nvim-notify module, once set up
local warned = false

---@type neat.notify.Backend
return {
  toasts = true,
  setup = function(backend_opts)
    opts = backend_opts or {}
    notify = nil -- set up again with the new options on the next message
  end,
  notify = function(msg, level, o)
    if not notify then
      local ok, mod = pcall(require, "notify")
      if not ok then
        -- say why once, then show this message the plain way
        local original = require("neat.notify").original()
        if not warned then
          warned = true
          original('neat.nvim: notify.backend is "nvim-notify" but nvim-notify is not installed', vim.log.levels.ERROR)
        end
        return original(msg, level, o)
      end
      mod.setup(opts)
      notify = mod
    end
    return notify(msg, level, o)
  end,
  history = function()
    vim.cmd("Notifications")
  end,
}
