-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: replaces noice's message manager, router and filters. The cmdline
-- is the only thing left to route, so each cmdline format maps straight to
-- its own view instead of going through route filters.
local require = require("neat.cmdline.util.lazy")

local Config = require("neat.cmdline.config")
local Util = require("neat.cmdline.util")
local View = require("neat.cmdline.view")

local M = {}

---@type table<string, NoiceView|false>
M._views = {}
---@type NoiceView?
M._current = nil
---@type NoiceMessage?
M._message = nil
---@type CmdlineFormat?
M._format = nil
M._dirty = false
M._updating = false
---@type Interval?
M._updater = nil

---@param format CmdlineFormat
---@return NoiceView?
local function get_view(format)
  local key = format.name or ""
  if M._views[key] == nil then
    M._views[key] = View.get_view(format.view, format.opts) or false
  end
  return M._views[key] or nil
end

-- Show `message` with the view of `format`, or hide the cmdline when `message` is nil.
---@param message? NoiceMessage
---@param format? CmdlineFormat
function M.set(message, format)
  M._message = message
  M._format = message
    and (format or { name = "", view = Config.options.cmdline.view, opts = Config.options.cmdline.opts })
  M._dirty = true
end

function M.is_dirty()
  return M._dirty
end

function M.update()
  if not M._dirty or M._updating or Util.is_exiting() then
    return
  end
  M._updating = true
  M._dirty = false

  local view = M._message and get_view(M._format --[[@as CmdlineFormat]])

  if M._current and M._current ~= view then
    M._current:clear()
    M._current:display()
  end

  if view then
    view:set(M._message --[[@as NoiceMessage]])
    view:display()
    -- retry on the next tick when the view failed to render
    if view._errors > 0 then
      view._errors = 0
      M._dirty = true
    end
  end
  M._current = view or nil

  Util.redraw()
  M._updating = false
end

function M.enable()
  if not M._updater then
    M._updater = Util.interval(Config.options.throttle, Util.protect(M.update))
  end
  M._updater()
end

function M.disable()
  if M._updater then
    M._updater.stop()
    M._updater = nil
  end
  M.set(nil)
  M.update()
end

return M
