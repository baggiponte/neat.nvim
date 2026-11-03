-- Contract test for the private ui2 layout neat patches (vim._core.ui2).
--
--   nvim --headless --clean --cmd "set rtp^=$PWD" -l tests/ui2_contract.lua
--
-- tests/smoke.lua checks neat's patches against a stand-in for ui2, so it
-- keeps passing when Neovim changes the real thing. This test loads the real
-- modules and checks that every field neat reads, writes or wraps is still
-- there with the type neat expects, then applies and removes neat's patches
-- on them. It does not draw anything: ui2 only attaches with a UI. CI runs it
-- on stable and nightly; a failure names the field that moved.
local failures = 0

---@param cond any
---@param msg string
local function check(cond, msg)
  io.stdout:write((cond and "ok   " or "FAIL ") .. msg .. "\n")
  if not cond then
    failures = failures + 1
  end
end

---@param mod table?
---@param modname string
---@param fields table<string, string> field -> expected type
local function has(mod, modname, fields)
  local names = vim.tbl_keys(fields)
  table.sort(names)
  for _, name in ipairs(names) do
    local got = mod and type(mod[name]) or "missing module"
    check(got == fields[name], ("%s.%s is a %s (got %s)"):format(modname, name, fields[name], got))
  end
end

---@param modname string
---@return table?
local function load(modname)
  local ok, mod = pcall(require, modname)
  check(ok and type(mod) == "table", ("require('%s')"):format(modname) .. (ok and "" or ": " .. tostring(mod)))
  return ok and type(mod) == "table" and mod or nil
end

io.stdout:write(vim.split(vim.fn.execute("version"), "\n", { trimempty = true })[1] .. "\n")

local ui2 = load("vim._core.ui2")
-- neat.cmdline.ui2.start, .patch, messages.forward, pager.float, confirm.forward
has(ui2, "ui2", { enable = "function", cfg = "table", wins = "table", cmdheight = "number" })
has(ui2 and ui2.cfg, "ui2.cfg", { msg = "table" })
has(ui2 and ui2.wins, "ui2.wins", { cmd = "number", pager = "number" })

local cmd = load("vim._core.ui2.cmdline")
-- neat.cmdline.ui2 wraps the handlers and reads/writes the state fields
has(cmd, "ui2.cmd", {
  cmdline_show = "function",
  cmdline_hide = "function",
  level = "number",
  indent = "number",
  srow = "number",
  prompt = "boolean",
})

local msg = load("vim._core.ui2.messages")
-- neat.cmdline.messages wraps msg_show, neat.cmdline.pager wraps set_pos
has(msg, "ui2.msg", { msg_show = "function", set_pos = "function" })
if msg and type(msg.msg_show) == "function" then
  local info = debug.getinfo(msg.msg_show, "u")
  -- neat forwards (kind, content, replace_last, history, append, ...)
  check(info.nparams >= 5, ("ui2.msg.msg_show takes >= 5 parameters (got %d)"):format(info.nparams))
end
-- ui2 picks a message's target from cfg.msg.targets[kind]; neat's pager
-- route sets that entry around the call
local src = msg and debug.getinfo(msg.msg_show, "S").source:gsub("^@", "")
local text = src and vim.fn.filereadable(src) == 1 and table.concat(vim.fn.readfile(src), "\n") or ""
check(text:find("cfg.msg.targets[kind]", 1, true) ~= nil, "ui2.msg.msg_show looks up cfg.msg.targets[kind]")
check(text:find("cmd_on_key", 1, true) ~= nil, "ui2.msg still has cmd_on_key (read by neat.cmdline.ui2)")

-- enable() sets ui2.cmd and ui2.msg once a UI is attached; do the same by
-- hand, then apply and remove neat's patches on the real modules
if ui2 and cmd and msg then
  ui2.cmd, ui2.msg = cmd, msg
  local Ui2 = require("neat.cmdline.ui2")
  local Messages = require("neat.cmdline.messages")
  local Pager = require("neat.cmdline.pager")
  Ui2.setup({})
  Messages.setup()
  Pager.setup()
  check(Ui2.is_patched(), "neat wraps ui2's cmdline handlers")
  check(Messages.is_patched(), "neat wraps ui2's msg_show")
  check(Pager.is_patched(), "neat wraps ui2's set_pos")
  check(ui2.cmd.cmdline_show ~= cmd.cmdline_show, "ui2.cmd.cmdline_show goes through neat")
  check(ui2.cmd.srow == cmd.srow, "ui2.cmd proxies reads to the real module")
  Pager.restore()
  Messages.restore()
  Ui2.restore()
  check(ui2.cmd == cmd and msg.msg_show ~= nil and not Messages.is_patched(), "restore() puts ui2 back")
end

if failures > 0 then
  io.stdout:write(("%d failure(s)\n"):format(failures))
  os.exit(1)
end
