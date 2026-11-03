-- neat.nvim: a cmdline popup, a statusline and UI replacements in one plugin.
-- Every module is off until its table sets `enabled = true`:
--
--   require("neat").setup({
--     cmdline = { enabled = true },                     -- centred cmdline popup on top of ui2
--     statusline = { enabled = true },                  -- small cached statusline
--     select = { enabled = true },                      -- vim.ui.select via a telescope dropdown
--     input = { enabled = true },                       -- vim.ui.input in a floating window
--     notify = { enabled = true, backend = "builtin" },  -- vim.notify toasts
--     indent = { enabled = true, backend = "builtin" },  -- indent and scope guides
--     spell = { enabled = true },                       -- z= through vim.ui.select
--     pack = { enabled = true },                        -- hints in vim.pack's update review
--   })
--
-- or set `vim.g.neat` to the same table before startup. `require("neat.rename")`
-- needs no setup. Heavy modules load on first use: input on the first
-- vim.ui.input(), the builtin notifier on the first vim.notify(), the builtin
-- indent engine with the first file buffer, the cmdline popup after VimEnter.
--
-- The builtin notify, indent and input code is adapted from snacks.nvim and
-- ships inside neat (see NOTICE); snacks.nvim does not need to be installed.

local M = {}

---@alias neat.Module "cmdline"|"statusline"|"select"|"input"|"notify"|"indent"|"spell"|"pack"

--- Modules in the order setup() starts them.
---@type neat.Module[]
M.modules = { "notify", "select", "input", "indent", "spell", "pack", "statusline", "cmdline" }

---@class neat.Enabled
---@field enabled? boolean

---@class neat.Config
---@field cmdline? cmdline.Opts|neat.Enabled
---@field statusline? statusline.Config|neat.Enabled
---@field select? ui.select.Config|neat.Enabled
---@field input? neat.input.Config|neat.Enabled
---@field notify? ui.notify.Config|neat.Enabled
---@field indent? ui.indent.Config|neat.Enabled
---@field spell? neat.Enabled
---@field pack? neat.Enabled

---@class neat.input.Config
---@field icon? string
---@field icon_hl? string
---@field icon_pos? "left"|"title"|false
---@field prompt_pos? "title"|"left"|false
---@field win? table window options, see neat.win
---@field expand? boolean grow the window with the text

--- True once setup() ran.
M.did_setup = false

--- The options setup() got (read by `:Neat` and the health check).
---@type neat.Config
M.options = {}

--- `vim.ui.input` before setup(), if setup() replaced it.
local original_input ---@type function?

local function enable_input()
  original_input = original_input or vim.ui.input
  local input = package.loaded["neat.input"]
  if input then
    input.enable()
    return
  end
  -- Stub until the first call: neat.input pulls in neat.win (about 800 lines).
  vim.ui.input = function(...)
    vim.ui.input = original_input -- neat.input captures this as the builtin to fall back to
    local mod = require("neat.input")
    mod.enable()
    return mod.input(...)
  end
end

--- `vim.ui.input` that setup() replaced, if any.
function M.original_input()
  return original_input
end

---@param name neat.Module
---@return boolean
function M.enabled(name)
  local o = M.options[name]
  return type(o) == "table" and o.enabled == true
end

---@param name neat.Module
---@param opts table
local function start(name, opts)
  if name == "input" then
    require("neat.util").config.input = opts
    enable_input()
  else
    require("neat." .. name).setup(opts)
  end
end

--- Configure neat.nvim and start the modules that set `enabled = true`.
---@param opts? neat.Config defaults to `vim.g.neat` (a table, or a function returning one)
function M.setup(opts)
  if vim.fn.has("nvim-0.12") ~= 1 then
    vim.notify("neat.nvim needs Neovim >= 0.12", vim.log.levels.ERROR)
    return
  end
  if opts == nil then
    opts = vim.g.neat
    if type(opts) == "function" then
      opts = opts()
    end
  end
  opts = opts or {}
  vim.validate("opts", opts, "table")
  for _, name in ipairs(M.modules) do
    vim.validate(name, opts[name], "table", true)
    if opts[name] then
      vim.validate(name .. ".enabled", opts[name].enabled, "boolean", true)
    end
  end
  M.did_setup = true
  M.options = opts

  for _, name in ipairs(M.modules) do
    if M.enabled(name) then
      local mod_opts = vim.deepcopy(opts[name])
      mod_opts.enabled = nil
      start(name, mod_opts)
    end
  end
end

return M
