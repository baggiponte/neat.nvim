-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: dropped helpers only the removed modules used; no nvim-notify.
local lazy = require("neat.cmdline.util.lazy")

---@module "neat.cmdline.config"
local Config = lazy("neat.cmdline.config")

local M = {}

M.islist = vim.islist

---@module "neat.cmdline.util.call"
M.call = lazy("neat.cmdline.util.call")
---@module "neat.cmdline.util.nui"
M.nui = lazy("neat.cmdline.util.nui")

---@param fn fun():any
---@return any what `fn` returned
function M.ignore_events(fn)
  local ei = vim.go.eventignore
  vim.go.eventignore = "all"
  local ret = fn()
  vim.go.eventignore = ei
  return ret
end

--- Give a buffer the `noice` filetype and a `noice` tag, so other plugins leave it alone.
---@param buf integer
---@param tag string
function M.tag(buf, tag)
  local ft = vim.bo[buf].filetype

  if ft == "" then
    M.ignore_events(function()
      vim.bo[buf].filetype = "noice"
    end)
  end

  if Config.options.debug and vim.api.nvim_buf_get_name(buf) == "" then
    local path = "noice://" .. buf .. "/" .. tag
    local params = {}
    if ft ~= "" and ft ~= "noice" then
      table.insert(params, "filetype=" .. ft)
    end
    if #params > 0 then
      path = path .. "?" .. table.concat(params, "&")
    end
    vim.api.nvim_buf_set_name(buf, path)
  end
end

---@param win integer
---@param options table<string, any>
function M.wo(win, options)
  for k, v in pairs(options) do
    vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
  end
end

--- `fn`, called `ms` after the last call (on the main loop).
---@param ms integer
---@param fn function
---@return fun(...)
function M.debounce(ms, fn)
  local timer = assert(vim.uv.new_timer())
  return function(...)
    local argv = vim.F.pack_len(...)
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
    end)
  end
end

---@generic F: fun()
---@param ms integer
---@param fn F
---@param opts? {enabled?:fun():boolean}
---@return F|neat.cmdline.Interval
function M.interval(ms, fn, opts)
  opts = opts or {}
  ---@type uv.uv_timer_t
  local timer = nil

  ---@class neat.cmdline.Interval
  local T = {}

  function T.keep()
    if M.is_exiting() then
      return false
    end
    return opts.enabled == nil or opts.enabled()
  end

  function T.running()
    return timer and not timer:is_closing()
  end

  function T.stop()
    if timer and T.running() then
      timer:stop()
    end
  end

  function T.fn()
    pcall(fn)
    if timer and T.running() and not T.keep() then
      timer:stop()
    elseif T.keep() and not T.running() then
      timer = vim.defer_fn(T.fn, ms)
    end
  end

  function T.__call()
    if not T.running() and T.keep() then
      timer = vim.defer_fn(T.fn, ms)
    end
  end

  return setmetatable(T, T)
end

---@param a table<string, any>
---@param b table<string, any>
---@return string[]
function M.diff_keys(a, b)
  local diff = {}
  for k, _ in pairs(a) do
    if not vim.deep_equal(a[k], b[k]) then
      diff[k] = true
    end
  end
  for k, _ in pairs(b) do
    if not vim.deep_equal(a[k], b[k]) then
      diff[k] = true
    end
  end
  return vim.tbl_keys(diff)
end

---@param opts? {blocking:boolean, mode:boolean, input:boolean, redraw:boolean}
---@return boolean blocking
---@return string? reason
function M.is_blocking(opts)
  opts = vim.tbl_deep_extend("force", {
    blocking = true,
    mode = true,
    input = true,
    redraw = true,
  }, opts or {})
  local mode = vim.api.nvim_get_mode()

  local blocking_mode = false
  for _, m in ipairs({ "ic", "ix", "c", "no", "r%?", "rm" }) do
    if mode.mode:find(m) == 1 then
      blocking_mode = true
    end
  end

  local reason = opts.blocking and mode.blocking and "blocking"
    or opts.mode and blocking_mode and ("mode:" .. mode.mode)
    or #require("neat.cmdline.ui.cmdline").cmdlines > 0 and "cmdline"
    or nil
  return reason ~= nil, reason
end

---@param opts? vim.api.keyset.redraw
function M.redraw(opts)
  vim.api.nvim__redraw(opts or { flush = true })
end

M.protect = M.call.protect

---@param fn function
---@param ... any arguments for `fn`
---@return any
function M.try(fn, ...)
  return M.call.protect(fn)(...)
end

--- Merge `opts` into the window's config.
---@param win integer
---@param opts? vim.api.keyset.win_config
function M.win_apply_config(win, opts)
  opts = vim.tbl_deep_extend("force", vim.api.nvim_win_get_config(win), opts or {})
  vim.api.nvim_win_set_config(win, opts)
end

---@param msg string
---@param level number
---@param ... any
function M.notify(msg, level, ...)
  vim.notify(msg:format(...), level, { title = "neat.nvim cmdline" })
end

---@param msg string format string
---@param ... any format arguments
function M.warn(msg, ...)
  M.notify(msg, vim.log.levels.WARN, ...)
end

---@param msg string format string
---@param ... any format arguments
function M.error(msg, ...)
  M.notify(msg, vim.log.levels.ERROR, ...)
end

--- Will stop cmdline.nvim and show error
---@param msg string format string
---@param ... any format arguments
function M.panic(msg, ...)
  require("neat.cmdline").disable()
  vim.notify(msg:format(...), vim.log.levels.ERROR)
  error("neat.nvim cmdline was stopped to prevent further errors", 0)
end

---@param data any
function M.debug(data)
  if not Config.options.debug then
    return
  end
  if type(data) == "function" then
    data = data()
  end
  if type(data) ~= "string" then
    data = vim.inspect(data)
  end
  local file = "./cmdline.nvim.log"
  local fd = io.open(file, "a+")
  if not fd then
    error(("Could not open file %s for writing"):format(file))
  end
  fd:write(data .. "\n")
  fd:close()
end

function M.is_exiting()
  return vim.v.exiting ~= vim.NIL
end

return M
