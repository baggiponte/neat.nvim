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
-- Messages that land in ui2's "msg" window get `padding` spaces on both sides
-- of every line, so the text does not touch the window's border.
-- "confirm" messages (the question before confirm(), `z=`, inputlist())
-- always go to neat.cmdline.confirm, which shows choice prompts in its float
-- and hands the rest back to ui2.
-- `:messages` and `g<` keep working: Neovim records the history itself.
-- Like the other ui2 patches this relies on ui2's private module layout; if it
-- changes shape, we do nothing and ui2 shows every message.

local M = {}

local MARK = "__neat_msg_show"

---@alias neat.cmdline.MessageRoute "notify"|"pager"|"auto"|"ui2"

---@class neat.cmdline.MessagesConfig
---@field enabled boolean
---@field routes table<string, neat.cmdline.MessageRoute|false> msg_show kind -> route; unlisted kinds stay with ui2
---@field pager_lines integer "auto" routes open the pager above this many lines
---@field padding integer spaces on each side of the text in ui2's "msg" window

---@type neat.cmdline.MessagesConfig
M.opts = {
  enabled = true,
  routes = {},
  pager_lines = 5,
  padding = 1,
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
  local notify = package.loaded["neat.notify"] ---@type table?
  return notify ~= nil and notify.shows_toasts()
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
---@param ... any the rest of msg_show's arguments
function M.forward(target, kind, ...)
  local ui2 = get_ui2()
  local real = ui2 and ui2.msg[MARK]
  if not (ui2 and real) then
    return
  end
  local args = vim.F.pack_len(...)
  local id, trigger = args[5], args[6]
  local pager = type(ui2.wins) == "table" and ui2.wins.pager
  local pager_open = trigger == "typed_cmd"
    and type(pager) == "number"
    and vim.api.nvim_win_is_valid(pager)
    and not vim.api.nvim_win_get_config(pager).hide
  if
    M.opts.padding > 0
    and type(args[1]) == "table"
    and not args[4] -- `:echon` continues a line that is already padded
    and not pager_open
    and (target or M.target(ui2, kind, id, trigger)) == "msg"
  then
    args[1] = M.pad(args[1], M.opts.padding)
  end
  local targets = target and type(ui2.cfg) == "table" and type(ui2.cfg.msg) == "table" and ui2.cfg.msg.targets
  if type(targets) ~= "table" then
    real(kind, vim.F.unpack_len(args))
    return
  end
  local old = targets[kind]
  targets[kind] = target
  local ok, err = pcall(real, kind, vim.F.unpack_len(args))
  targets[kind] = old
  if not ok then
    error(err, 0)
  end
end

--- The target ui2 picks for a message, the way its msg_show() does.
---@param ui2 table
---@param kind string
---@param id? integer|string
---@param trigger? string
---@return string?
function M.target(ui2, kind, id, trigger)
  local targets = type(ui2.cfg) == "table" and type(ui2.cfg.msg) == "table" and ui2.cfg.msg.targets
  if type(targets) ~= "table" or kind == "search_cmd" then
    return nil
  end
  if trigger and trigger ~= "" and targets[trigger] then
    return targets[trigger]
  end
  if type(id) == "string" then
    for pat, tgt in pairs(targets) do
      if id:match(pat) then
        return tgt
      end
    end
  end
  return kind ~= "" and targets[kind] or targets.default
end

--- `content` with `n` spaces on both sides of every line. A leading "\r"
--- (ui2 reads it as "overwrite the last line") stays first.
---@param content [integer, string, integer][]
---@param n integer
---@return [integer, string, integer][]
function M.pad(content, n)
  if n <= 0 or #content == 0 then
    return content
  end
  local pad = (" "):rep(n)
  local ret = {} ---@type [integer, string, integer][]
  for i, chunk in ipairs(content) do
    local text = chunk[2]:gsub("\n", pad .. "\n" .. pad)
    if i == 1 then
      local cr, rest = text:match("^(\r?)(.*)$")
      text = cr .. pad .. rest
    end
    local copy = vim.list_slice(chunk) ---@type [integer, string, integer]
    copy[2] = text
    ret[i] = copy
  end
  -- no trailing pad after a final newline: it would show as a line of spaces
  local last = ret[#ret]
  if last[2]:sub(-#pad - 1) ~= "\n" .. pad then
    last[2] = last[2] .. pad
  end
  return ret
end

local notifying = false

---@param kind string
---@param content [integer, string, integer][]
---@param replace_last boolean
---@param history boolean
---@param append boolean
---@param ... any msg_show arguments added by later Neovim versions
local function msg_show(kind, content, replace_last, history, append, ...)
  if kind == "confirm" then
    local Confirm = require("neat.cmdline.confirm")
    if Confirm.enabled() then
      local rest = vim.F.pack_len(...)
      Confirm.on_message(content, function()
        M.forward(nil, kind, content, replace_last, history, append, vim.F.unpack_len(rest))
      end)
      return
    end
  end

  local route = M.opts.enabled and M.opts.routes[kind] or nil
  -- `:echon` continues the previous message, which ui2 is showing
  if not route or route == "ui2" or append then
    M.forward(nil, kind, content, replace_last, history, append, ...)
    return
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
  M.forward(route == "pager" and "pager" or nil, kind, content, replace_last, history, append, ...)
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

---@param opts? neat.cmdline.MessagesConfig
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
