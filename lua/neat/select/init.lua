-- Adapted from dressing.nvim (MIT) by Steven Arcangeli; modified.
-- Source: lua/dressing/select/init.lua and lua/dressing/util.lua (make_queued_async_fn)
-- at stevearc/dressing.nvim 2d7c2db2507fa3c4956142ee607431ddb2828639.
-- Changes: telescope is the only backend (falls back to the builtin `vim.ui.select` when telescope
-- is missing); no per-kind config overrides; the queued-call helper is inlined.

local M = {}

---@class ui.select.Config
---@field enabled? boolean
---@field trim_prompt? boolean drop a trailing ":" from the prompt
---@field telescope? table telescope picker opts; defaults to the dropdown theme
---@field format_item_override? table<string, fun(item: any): string>
---@field spell? boolean map z= to a picker of spelling suggestions (needs telescope)
local defaults = {
  trim_prompt = true,
  telescope = nil,
  format_item_override = {},
  spell = true,
}

local config = defaults ---@type ui.select.Config
local original ---@type fun(items: any[], opts: table, on_choice: fun(item: any?, idx: integer?))?

local function sanitize_line(line)
  return (string.gsub(tostring(line), "\n", " "))
end

local function with_sanitize_line(fn)
  return function(...)
    return sanitize_line(fn(...))
  end
end

-- Calls `fn` one at a time: a second `vim.ui.select` waits until the first has called back.
local function make_queued_async_fn(callback_arg_num, fn)
  local queue = {}
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
    local cb = args[callback_arg_num]
    args[callback_arg_num] = function(...)
      local cb_args = vim.F.pack_len(...)
      vim.schedule(function()
        -- first schedule the consumption, only later invoke the callback, because the callback could fail
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

-- schedule_wrap avoids focus problems for the picker
-- (see https://github.com/stevearc/dressing.nvim/issues/15 and #59)
M.select = vim.schedule_wrap(make_queued_async_fn(3, function(items, opts, on_choice)
  vim.validate("items", items, vim.islist, "list-like table")
  vim.validate("on_choice", on_choice, "function")
  opts = opts or {}

  local telescope = require("neat.select.telescope")
  if not telescope.is_supported() then
    return (original or vim.ui.select)(items, opts, on_choice)
  end

  opts.prompt = vim.trim(sanitize_line(opts.prompt or "Select one of:"))
  if config.trim_prompt and opts.prompt:sub(-1, -1) == ":" then
    opts.prompt = opts.prompt:sub(1, -2)
  end

  local format_override = config.format_item_override[opts.kind]
  if format_override then
    opts.format_item = with_sanitize_line(format_override)
  elseif opts.format_item then
    -- format_item doesn't have to return a string for the core implementation, so wrap it in tostring
    opts.format_item = with_sanitize_line(opts.format_item)
  else
    opts.format_item = sanitize_line
  end

  local winid = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(winid)
  telescope.select(
    config.telescope,
    items,
    opts,
    vim.schedule_wrap(function(...)
      if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_set_cursor(winid, cursor)
      end
      on_choice(...)
    end)
  )
end))

---@param opts? ui.select.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.validate("select.trim_prompt", config.trim_prompt, "boolean")
  vim.validate("select.telescope", config.telescope, "table", true)
  vim.validate("select.format_item_override", config.format_item_override, "table")
  vim.validate("select.spell", config.spell, "boolean")
  original = original or vim.ui.select
  vim.ui.select = M.select
  -- leave z= alone when the user mapped it
  if config.spell and vim.fn.maparg("z=", "n") == "" then
    vim.keymap.set("n", "z=", function()
      require("neat.select.spell").suggest()
    end, { desc = "neat: spelling suggestions in a picker" })
  end
end

return M
