-- vim.notify() through a backend. This module only picks the backend named by
-- `notify.backend` and points vim.notify at it; it never requires a notifier
-- plugin itself. See `:h neat-notify-backend` to plug in your own.
--
-- * "builtin": neat's own toasts, bottom-right. Their code is adapted from
--   snacks.nvim and ships inside neat; snacks.nvim is not needed.
-- * "native": leave vim.notify to Neovim (ui2 shows messages when enabled).
-- * "nvim-notify": rcarriga/nvim-notify, which must be installed separately.
--
-- LSP progress is shown by the statusline (`lsp_progress` component), not here.

local M = {}

---@alias neat.notify.Notify fun(msg: string, level?: integer, opts?: table)

--- A vim.notify() implementation.
---@class neat.notify.Backend
--- Show a message. Becomes vim.notify, so it must accept vim.notify()'s arguments.
---@field notify neat.notify.Notify
--- Whether messages show outside the message area (toasts, a panel, ...).
--- The cmdline module routes messages to vim.notify() only when true.
---@field toasts boolean
--- Open the message history (`:Neat notifications`); `:messages` when nil.
---@field history? fun()
--- Called by setup() with `notify[<backend name>]` (nil for your own backend).
--- Keep it cheap: load the notifier in notify() on the first message.
---@field setup? fun(backend_opts: table?)

---@alias neat.notify.BackendName "builtin"|"native"|"nvim-notify"

---@class neat.notify.Config
---@field backend? neat.notify.BackendName|neat.notify.Backend
---@field builtin? table options for the builtin notifier (snacks.nvim's `notifier` keys)
---@field nvim_notify? table options passed to `require("notify").setup()`

---@type neat.notify.Config
M.defaults = {
  backend = "builtin",
  builtin = {},
  nvim_notify = {},
}

--- Backends that ship with neat: the module that returns each, and the
--- config key that holds its options.
---@type table<neat.notify.BackendName, {module: string, opts: string?}>
local BACKENDS = {
  builtin = { module = "neat.notify.backends.builtin", opts = "builtin" },
  native = { module = "neat.notify.backends.native" },
  ["nvim-notify"] = { module = "neat.notify.backends.nvim_notify", opts = "nvim_notify" },
}

local config = vim.deepcopy(M.defaults) ---@type neat.notify.Config
local backend ---@type neat.notify.Backend? nil before setup()
local original = vim.notify ---@type neat.notify.Notify

--- The active options (read by the health check).
---@return neat.notify.Config
function M.get_config()
  return config
end

--- The `vim.notify` that was there before setup().
---@return neat.notify.Notify
function M.original()
  return original
end

--- The active backend, nil before setup().
---@return neat.notify.Backend?
function M.backend()
  return backend
end

--- Whether vim.notify() shows toasts, so that routing a message there does
--- not echo it back into the message area.
---@return boolean
function M.shows_toasts()
  return backend ~= nil and backend.toasts and vim.notify == backend.notify
end

--- Open the notification history of the active backend.
function M.history()
  if backend and backend.history then
    backend.history()
  else
    vim.cmd("messages")
  end
end

---@param c neat.notify.Config
local function validate(c)
  vim.validate("notify.backend", c.backend, function(v)
    return BACKENDS[v] ~= nil or (type(v) == "table" and vim.is_callable(v.notify) and type(v.toasts) == "boolean")
  end, false, '"builtin", "native", "nvim-notify" or a table with notify() and toasts')
  vim.validate("notify.builtin", c.builtin, "table")
  vim.validate("notify.nvim_notify", c.nvim_notify, "table")
end

--- Point vim.notify at the configured backend.
---@param opts? neat.notify.Config
function M.setup(opts)
  local c = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if opts and type(opts.backend) == "table" then
    c.backend = opts.backend -- keep the caller's table, not a deep copy
  end
  validate(c)
  config = c

  local b, backend_opts
  if type(c.backend) == "table" then
    b = c.backend --[[@as neat.notify.Backend]]
  else
    local spec = BACKENDS[c.backend]
    b = require(spec.module) --[[@as neat.notify.Backend]]
    backend_opts = spec.opts and c[spec.opts]
  end
  if b.setup then
    b.setup(backend_opts)
  end
  if not backend or vim.notify ~= backend.notify then
    original = vim.notify
  end
  backend = b
  vim.notify = b.notify
end

return M
