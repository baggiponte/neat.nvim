-- Adapted from dressing.nvim (MIT) by Steven Arcangeli; modified.
-- Source: lua/dressing/select/init.lua and lua/dressing/util.lua (make_queued_async_fn)
-- at stevearc/dressing.nvim 2d7c2db2507fa3c4956142ee607431ddb2828639.
-- Changes: the picker is a pluggable backend (neat.select.Backend); telescope and Neovim's own
-- menu ship as backends; no per-kind config overrides; the queued-call helper is inlined; the
-- caller's opts are copied, never modified.
--
-- vim.ui.select() through a picker backend. This module only normalises the
-- call (prompt, format_item, one picker at a time) and hands it to the
-- backend named by `select.backend`; it never requires a picker itself. See
-- `:h neat-select-backend` to plug in your own picker.

local M = {}

---@alias neat.select.OnChoice fun(item: any?, idx: integer?)

--- The `opts` a backend receives: a copy of the caller's vim.ui.select() opts
--- with `prompt` and `format_item` always set.
---@class neat.select.Opts
---@field prompt string
---@field format_item fun(item: any): string always returns a single line
---@field kind? string
---@field [string] any other keys the caller passed (e.g. `telescope`)

--- A picker for vim.ui.select().
---@class neat.select.Backend
--- Whether the picker can be used now. Called on every vim.ui.select(), so it
--- may require the picker; when false, Neovim's own menu is used instead.
---@field available fun(): boolean
--- Show the picker and call `on_choice` once: with the item and its index, or
--- with nothing when cancelled. `backend_opts` is `select[<backend name>]`
--- for a backend that ships with neat, nil for your own.
---@field select fun(items: any[], opts: neat.select.Opts, on_choice: neat.select.OnChoice, backend_opts: table?)

---@alias neat.select.BackendName "telescope"|"builtin"

---@class neat.select.Config
---@field backend? neat.select.BackendName|neat.select.Backend
---@field trim_prompt? boolean drop a trailing ":" from the prompt
---@field telescope? table options for the telescope backend (picker opts; the dropdown theme when nil)
---@field builtin? table options for the builtin backend (none yet)
---@field format_item_override? table<string, fun(item: any): string> kind -> format_item

---@type neat.select.Config
M.defaults = {
  backend = "telescope",
  trim_prompt = true,
  telescope = nil,
  builtin = {},
  format_item_override = {},
}

--- Backends that ship with neat, by name. Each module returns a neat.select.Backend.
---@type table<neat.select.BackendName, string>
local BACKENDS = {
  telescope = "neat.select.backends.telescope",
  builtin = "neat.select.backends.builtin",
}

local config = vim.deepcopy(M.defaults) ---@type neat.select.Config

--- vim.ui.select as it was before setup(); the builtin backend calls it.
---@type fun(items: any[], opts: table, on_choice: neat.select.OnChoice)
local original = vim.ui.select

--- Neovim's vim.ui.select (or whatever setup() replaced).
---@return fun(items: any[], opts: table, on_choice: neat.select.OnChoice)
function M.original()
  return original
end

--- The active options (read by the health check).
---@return neat.select.Config
function M.get_config()
  return config
end

--- The configured backend and the name its options live under.
---@return neat.select.Backend backend
---@return string? name nil for a backend table passed in the config
function M.backend()
  local backend = config.backend
  if type(backend) == "table" then
    return backend, nil
  end
  ---@cast backend neat.select.BackendName
  return require(BACKENDS[backend]), backend
end

---@param line any
---@return string
local function single_line(line)
  return (tostring(line):gsub("\n", " "))
end

---@param fn fun(item: any): any
---@return fun(item: any): string
local function single_line_of(fn)
  return function(item)
    return single_line(fn(item))
  end
end

--- Wrap `fn` so that calls run one at a time: a second call waits until the
--- first one's callback (argument `callback_index`) has run.
---@param callback_index integer
---@param fn function
---@return function
local function queued(callback_index, fn)
  local queue = {} ---@type table[]
  local consuming = false

  local function consume()
    if #queue == 0 then
      consuming = false
      return
    end
    consuming = true
    local args = table.remove(queue, 1)
    fn(vim.F.unpack_len(args))
  end

  return function(...)
    local args = vim.F.pack_len(...)
    local cb = args[callback_index]
    args[callback_index] = function(...)
      local cb_args = vim.F.pack_len(...)
      vim.schedule(function()
        -- schedule the next call first: the callback may throw
        vim.schedule(consume)
        cb(vim.F.unpack_len(cb_args))
      end)
    end
    table.insert(queue, args)
    if not consuming then
      consume()
    end
  end
end

--- The caller's opts, copied, with `prompt` and `format_item` filled in.
---@param opts? table
---@return neat.select.Opts
local function normalize(opts)
  local o = vim.tbl_extend("force", {}, opts or {}) ---@type neat.select.Opts
  o.prompt = vim.trim(single_line(o.prompt or "Select one of:"))
  if config.trim_prompt and o.prompt:sub(-1) == ":" then
    o.prompt = o.prompt:sub(1, -2)
  end
  local format = config.format_item_override[o.kind] or o.format_item
  -- format_item does not have to return a string for Neovim's menu, so tostring() it
  o.format_item = format and single_line_of(format) or single_line
  return o
end

---@param items any[]
---@param opts? table
---@param on_choice neat.select.OnChoice
local function select(items, opts, on_choice)
  vim.validate("items", items, vim.islist, "list-like table")
  vim.validate("on_choice", on_choice, "function")

  local backend, name = M.backend()
  if not backend.available() then
    return original(items, opts or {}, on_choice)
  end

  local winid = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winid)
  backend.select(
    items,
    normalize(opts),
    vim.schedule_wrap(function(item, idx)
      -- pickers move the cursor; callers (e.g. z=) expect it where it was
      if vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_set_cursor, winid, cursor)
      end
      on_choice(item, idx)
    end),
    name and config[name] or nil
  )
end

--- neat's vim.ui.select(). schedule_wrap avoids focus problems with pickers
--- opened from a mapping (dressing.nvim#15, #59).
M.select = vim.schedule_wrap(queued(3, select))

---@param c neat.select.Config
local function validate(c)
  vim.validate("select.backend", c.backend, function(v)
    return BACKENDS[v] ~= nil or (type(v) == "table" and vim.is_callable(v.available) and vim.is_callable(v.select))
  end, false, '"telescope", "builtin" or a table with available() and select()')
  vim.validate("select.trim_prompt", c.trim_prompt, "boolean")
  vim.validate("select.telescope", c.telescope, "table", true)
  vim.validate("select.builtin", c.builtin, "table")
  vim.validate("select.format_item_override", c.format_item_override, "table")
end

--- Set vim.ui.select to neat's.
---@param opts? neat.select.Config
function M.setup(opts)
  local c = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if opts and type(opts.backend) == "table" then
    c.backend = opts.backend -- keep the caller's table, not a deep copy
  end
  validate(c)
  config = c
  if vim.ui.select ~= M.select then
    original = vim.ui.select
  end
  vim.ui.select = M.select
end

return M
