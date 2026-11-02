-- vim.notify backends. LSP progress is shown by the statusline (`lsp_progress`
-- component), not here.
--
-- * "builtin": neat's own notifier, toasts bottom-right. Its code is adapted
--   from snacks.nvim and ships inside neat; snacks.nvim is not needed.
--   "snacks" is accepted as an older name for it.
-- * "native": leave vim.notify to Neovim (ui2 shows messages when enabled)
-- * "nvim-notify": rcarriga/nvim-notify, which must be installed separately

local M = {}

---@alias ui.notify.backend "builtin"|"native"|"nvim-notify"|"snacks"

---@class ui.notify.Config
---@field enabled? boolean
---@field backend? ui.notify.backend
---@field builtin? table options for the builtin notifier (see neat.notify.notifier)
---@field snacks? table old name for `builtin`
---@field nvim_notify? table options passed to `require("notify").setup()`
local defaults = {
  backend = "builtin",
  builtin = {},
  nvim_notify = {},
}

local backends = { builtin = true, native = true, ["nvim-notify"] = true }

local config = defaults ---@type ui.notify.Config
local original ---@type fun(msg: string, level?: integer, opts?: table)?

--- The active options (read by the health check).
---@return ui.notify.Config
function M.get_config()
  return config
end

--- The `vim.notify` that was there before setup(), if setup() ran.
function M.original()
  return original
end

--- Open the notification history of the active backend.
function M.history()
  if config.backend == "builtin" then
    require("neat.notify.notifier").show_history()
  elseif config.backend == "nvim-notify" then
    vim.cmd("Notifications")
  else
    vim.cmd("messages")
  end
end

---@param opts? ui.notify.Config
function M.setup(opts)
  config = require("neat.util").builtin_alias("notify", vim.tbl_deep_extend("force", defaults, opts or {}))
  vim.validate("notify.backend", config.backend, function(v)
    return backends[v] ~= nil
  end, false, '"builtin", "native" or "nvim-notify"')
  vim.validate("notify.builtin", config.builtin, "table")
  vim.validate("notify.nvim_notify", config.nvim_notify, "table")

  original = original or vim.notify
  if config.backend == "native" then
    vim.notify = original
  elseif config.backend == "builtin" then
    require("neat.util").config.notifier = config.builtin
    -- Load the notifier (about 1,600 lines with its window code) on the first message.
    vim.notify = function(...)
      vim.notify = require("neat.notify.notifier").notify
      return vim.notify(...)
    end
  elseif config.backend == "nvim-notify" then
    local notify = require("notify")
    notify.setup(config.nvim_notify)
    vim.notify = function(...)
      return notify(...)
    end
  end
end

return M
