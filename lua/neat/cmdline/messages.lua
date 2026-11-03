-- neat.nvim: route ui2's messages by kind, like noice's router but small.
--
-- ui2 (vim._core.ui2) receives every `msg_show` event. We wrap its handler
-- and send each message where its kind says (`messages.routes`):
-- - "notify": `vim.notify()`, so messages share the toasts and history of
--   neat's `notify` module (noice sends them to nvim-notify the same way);
-- - "pager": ui2's pager, which neat shows as a centred float;
-- - "auto": the pager when the message is longer than `pager_lines`, else a
--   toast (`:ls` with three buffers is a toast, `:map` opens the pager);
-- - "ui2": ui2's own target (its small message window with 'cmdheight' 0).
-- "confirm" messages (the question before confirm(), `z=`, inputlist())
-- always go to neat.cmdline.confirm, which shows choice prompts in its float
-- and hands the rest back to ui2.
-- `:messages` and `g<` keep working: Neovim records the history itself.
-- Like the other ui2 patches this relies on ui2's private module layout; if it
-- changes shape, we do nothing and ui2 shows every message.

local M = {}

local MARK = "__neat_msg_show"

---@alias neat.cmdline.MessageRoute "notify"|"pager"|"auto"|"ui2"

---@class CmdlineMessagesOptions
---@field enabled boolean
---@field routes table<string, neat.cmdline.MessageRoute|false> msg_show kind -> route; unlisted kinds stay with ui2
---@field pager_lines integer "auto" routes open the pager above this many lines

---@type CmdlineMessagesOptions
M.opts = {
  enabled = true,
  routes = {},
  pager_lines = 5,
}

local levels = vim.log.levels
---@type table<string, integer>
local LEVEL = {
  emsg = levels.ERROR,
  echoerr = levels.ERROR,
  lua_error = levels.ERROR,
  rpc_error = levels.ERROR,
  wmsg = levels.WARN,
}

---@return table?
local function get_ui2()
  local ui2 = package.loaded["vim._core.ui2"]
  if type(ui2) == "table" and type(ui2.msg) == "table" and type(ui2.msg.msg_show) == "function" then
    return ui2
  end
end

--- Whether `vim.notify` shows toasts instead of echoing (which would loop back here).
---@return boolean
function M.can_notify()
  local ok, neat = pcall(require, "neat")
  if not (ok and neat.enabled("notify")) then
    return false
  end
  return require("neat.notify").get_config().backend ~= "native"
end

---@param content? [integer, string, integer][]
---@return string
function M.text(content)
  local text = {}
  for _, chunk in ipairs(content or {}) do
    text[#text + 1] = chunk[2]
  end
  return (table.concat(text):gsub("\n+$", ""))
end

--- Call ui2's real handler, sending the message to `target` ("cmd", "msg" or
--- "pager") instead of the configured one when given.
---@param target? string
---@param kind string
function M.forward(target, kind, ...)
  local ui2 = get_ui2()
  local real = ui2 and ui2.msg[MARK]
  if not real then
    return
  end
  local targets = target and type(ui2.cfg) == "table" and type(ui2.cfg.msg) == "table" and ui2.cfg.msg.targets
  if type(targets) ~= "table" then
    return real(kind, ...)
  end
  local old = targets[kind]
  targets[kind] = target
  local ok, err = pcall(real, kind, ...)
  targets[kind] = old
  if not ok then
    error(err, 0)
  end
end

local notifying = false

---@param kind string
---@param content [integer, string, integer][]
---@param replace_last boolean
---@param history boolean
---@param append boolean
local function msg_show(kind, content, replace_last, history, append, ...)
  if kind == "confirm" then
    local Confirm = require("neat.cmdline.confirm")
    if Confirm.enabled() then
      local rest = vim.F.pack_len(...)
      return Confirm.on_message(content, function()
        M.forward(nil, kind, content, replace_last, history, append, vim.F.unpack_len(rest))
      end)
    end
  end

  local route = M.opts.enabled and M.opts.routes[kind] or nil
  -- `:echon` continues the previous message, which ui2 is showing
  if not route or route == "ui2" or append then
    return M.forward(nil, kind, content, replace_last, history, append, ...)
  end

  local text = M.text(content)
  if route == "auto" then
    local _, newlines = text:gsub("\n", "")
    route = newlines + 1 > M.opts.pager_lines and "pager" or "notify"
  end
  if route == "notify" and (notifying or text == "" or not M.can_notify()) then
    route = "ui2"
  end

  if route == "notify" then
    notifying = true
    local ok, err = pcall(vim.notify, text, LEVEL[kind] or levels.INFO)
    notifying = false
    if ok then
      return
    end
    -- the toast failed: show the message (and why) the plain way
    M.forward(nil, kind, content, replace_last, history, append, ...)
    error(err, 0)
  end
  return M.forward(route == "pager" and "pager" or nil, kind, content, replace_last, history, append, ...)
end

local function patch()
  local ui2 = get_ui2()
  if not ui2 then
    return false
  end
  if ui2.msg[MARK] then
    return true
  end
  ui2.msg[MARK] = ui2.msg.msg_show
  ui2.msg.msg_show = msg_show
  return true
end

---@param opts? CmdlineMessagesOptions
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  patch()
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("neat.cmdline.messages", { clear = true }),
    callback = function()
      vim.schedule(patch)
    end,
  })
end

--- Whether ui2's message handler is wrapped right now.
---@return boolean
function M.is_patched()
  local ui2 = get_ui2()
  return ui2 ~= nil and ui2.msg[MARK] ~= nil
end

function M.restore()
  pcall(vim.api.nvim_del_augroup_by_name, "neat.cmdline.messages")
  local ui2 = get_ui2()
  if ui2 and ui2.msg[MARK] then
    ui2.msg.msg_show = ui2.msg[MARK]
    ui2.msg[MARK] = nil
  end
end

return M
