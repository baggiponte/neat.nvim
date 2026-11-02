-- ui.nvim: the UI pieces this config used from snacks.nvim and dressing.nvim.
--
-- It starts by itself (plugin/ui.lua) with the defaults, or with `vim.g.ui`.
-- Call setup() to pass options instead; `vim.g.loaded_ui = true` turns it off.
--
--   require("ui").setup({
--     select = {},                       -- vim.ui.select via a telescope dropdown
--     input = {},                        -- vim.ui.input in a floating window
--     notify = { backend = "snacks" },   -- vim.notify + LSP progress
--     indent = { backend = "snacks" },   -- indent and scope guides
--   })
--
-- Each module is on unless its table sets `enabled = false`. `require("ui.rename")` needs no setup.
-- Heavy modules load on first use: input on the first vim.ui.input(), the snacks notifier on the
-- first vim.notify(), the snacks indent engine with the first file buffer.

local M = {}

local modules = { "select", "input", "notify", "indent" }

---@class ui.Config
---@field select? ui.select.Config
---@field input? ui.input.Config
---@field notify? ui.notify.Config
---@field indent? ui.indent.Config

---@class ui.input.Config
---@field enabled? boolean
---@field icon? string
---@field icon_hl? string
---@field icon_pos? "left"|"title"|false
---@field prompt_pos? "title"|"left"|false
---@field win? table window options, see ui.win
---@field expand? boolean grow the window with the text

--- True once setup() ran (plugin/ui.lua then leaves it alone).
M.did_setup = false

--- The options setup() got (read by the health check).
---@type ui.Config
M.options = {}

--- `vim.ui.input` before setup(), restored by `:Ui input off`.
local original_input ---@type function?

local function enable_input()
  original_input = original_input or vim.ui.input
  local input = package.loaded["ui.input"]
  if input then
    input.enable()
    return
  end
  -- Stub until the first call: ui.input pulls in ui.win (about 800 lines).
  vim.ui.input = function(...)
    vim.ui.input = original_input -- ui.input captures this as the builtin to fall back to
    local mod = require("ui.input")
    mod.enable()
    return mod.input(...)
  end
end

--- `vim.ui.input` that setup() replaced, if any.
function M.original_input()
  return original_input
end

---@param opts? ui.Config defaults to `vim.g.ui`
function M.setup(opts)
  if opts == nil then
    opts = vim.g.ui
    if type(opts) == "function" then
      opts = opts()
    end
  end
  opts = opts or {}
  vim.validate("opts", opts, "table")
  for _, name in ipairs(modules) do
    vim.validate(name, opts[name], "table", true)
  end
  M.did_setup = true
  M.options = opts

  for _, name in ipairs(modules) do
    local mod_opts = opts[name] or {}
    if mod_opts.enabled ~= false then
      mod_opts = vim.deepcopy(mod_opts)
      mod_opts.enabled = nil
      if name == "input" then
        require("ui.util").config.input = mod_opts
        enable_input()
      else
        require("ui." .. name).setup(mod_opts)
      end
    end
  end
end

return M
