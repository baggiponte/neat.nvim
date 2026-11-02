-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: attaches to `ext_cmdline` only; messages and the popupmenu are left
-- to Neovim (ui2 and the completion plugin). Updates go through cmdline.render.
local require = require("cmdline.util.lazy")

local Cmdline = require("cmdline.ui.cmdline")
local Config = require("cmdline.config")
local Render = require("cmdline.render")
local Util = require("cmdline.util")

local M = {}
M._attached = false

local queue = {}

local timer = vim.uv.new_timer()
local processing = false

function M.process_queue()
  processing = true
  timer:stop()
  while #queue > 0 do
    local item = table.remove(queue, 1)
    M.ui_attach_cb(vim.F.unpack_len(item))
  end
  processing = false
end

local stack_level = 0
function M.ui_attach_cb(handler, event, ...)
  if stack_level > 50 then
    return Util.panic("Event loop detected. Shutting down...")
  end
  stack_level = stack_level + 1

  M.safe_handle(handler, event, ...)

  -- redraw right away while Neovim blocks (e.g. in cmdline mode), otherwise
  -- the throttled updater picks it up
  if Render.is_dirty() and require("cmdline.util.ffi").textlock == 0 and Util.is_blocking() then
    Util.try(Render.update)
  end
  stack_level = stack_level - 1
end

---@return boolean
local function gui_has_cmdline()
  for _, ui in ipairs(vim.api.nvim_list_uis()) do
    if ui.ext_cmdline then
      return true
    end
  end
  return false
end

function M.enable()
  if gui_has_cmdline() then
    if Config.options.debug then
      vim.schedule(function()
        Util.warn("The GUI already draws the cmdline; cmdline.nvim stays off")
      end)
    end
    return
  end

  M._attached = true

  local schedule_process = vim.schedule_wrap(M.process_queue)

  ---@diagnostic disable-next-line: redundant-parameter
  vim.ui_attach(Config.ns, { ext_cmdline = true }, function(event, ...)
    if Util.is_exiting() then
      return
    end
    if Config.options.debug then
      Util.debug({ event = event, ... })
    end
    local handler = M.get_handler(event)
    if not handler then
      return
    end
    table.insert(queue, vim.F.pack_len(handler, event, ...))
    if vim.in_fast_event() then
      timer:start(0, 0, schedule_process)
    elseif not processing then
      M.process_queue()
    end
    return true
  end)

  vim.api.nvim_create_autocmd("SwapExists", {
    group = vim.api.nvim_create_augroup("cmdline.swap_exists", { clear = true }),
    callback = function()
      Util.try(Render.update)
    end,
  })
end

function M.disable()
  if M._attached then
    M._attached = false
    vim.ui_detach(Config.ns)
  end
end

---@param event string
---@return fun(event: string, ...)?
function M.get_handler(event)
  local event_type = event:match("^cmdline_(.*)$")
  local handler = event_type and Cmdline["on_" .. event_type]
  return type(handler) == "function" and handler or nil
end

---@param handler fun(...)
---@param event string
function M.handle(handler, event, ...)
  handler(event, ...)
end
M.safe_handle = Util.protect(M.handle, { msg = "An error happened while handling a ui event" })

return M
