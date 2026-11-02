-- Headless smoke test: loads one plugin the way vim.pack does (on 'runtimepath',
-- plugin/ sourced at startup), exercises its command and runs its health check.
--
--   SMOKE=<name> nvim --headless --clean --cmd 'set rtp^=<plugin dir>' -c 'luafile tests/smoke.lua'
--
-- Exits non-zero on the first failure.
local name = assert(os.getenv("SMOKE"), "set SMOKE to cmdline, ui or statusline")
local failures = 0

local function check(cond, msg)
  if cond then
    io.stdout:write("ok   " .. msg .. "\n")
  else
    failures = failures + 1
    io.stdout:write("FAIL " .. msg .. "\n")
  end
end

local function health_errors(plugin)
  vim.cmd("checkhealth " .. plugin)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local errors = {}
  for _, line in ipairs(lines) do
    io.stdout:write("     | " .. line .. "\n")
    if line:find("ERROR") then
      errors[#errors + 1] = line
    end
  end
  vim.cmd("bwipeout!")
  return errors
end

local tests = {}

function tests.statusline()
  local sl = require("statusline")
  check(sl.did_setup, "plugin/statusline.lua ran setup()")
  check(sl.is_enabled(), "'statusline' is ours")
  check(type(sl.render()) == "string", "render() returns a string")
  vim.cmd("Statusline disable")
  check(not sl.is_enabled(), ":Statusline disable")
  vim.cmd("Statusline enable")
  check(sl.is_enabled(), ":Statusline enable")
  vim.cmd("Statusline refresh")
  sl.setup({ lsp_scope = "buffer" })
  check(sl.config.lsp_scope == "buffer", "setup() again applies new options")
  check(not pcall(sl.setup, { lsp_scope = 1 }), "setup() rejects a wrong type")
  sl.setup({})
  check(#health_errors("statusline") == 0, ":checkhealth statusline has no errors")
end

function tests.ui()
  local ui = require("ui")
  check(ui.did_setup, "plugin/ui.lua ran setup()")
  check(package.loaded["ui.input"] == nil, "ui.input is not loaded at startup")
  check(package.loaded["ui.notify.notifier"] == nil, "the notifier is not loaded at startup")
  check(package.loaded["ui.indent.snacks"] == nil, "the indent engine is not loaded without a file")
  vim.notify("smoke test")
  check(package.loaded["ui.notify.notifier"] ~= nil, "the first vim.notify() loads the notifier")
  check(vim.notify == require("ui.notify.notifier").notify, "vim.notify is the notifier after the first call")
  vim.cmd("edit tests/smoke.lua")
  check(package.loaded["ui.indent.snacks"] ~= nil, "opening a file loads the indent engine")
  vim.cmd("Ui indent off")
  check(not require("ui.indent.snacks").enabled, ":Ui indent off")
  vim.cmd("Ui indent toggle")
  check(require("ui.indent.snacks").enabled, ":Ui indent toggle")
  check(not pcall(ui.setup, { notify = { backend = "nope" } }), "setup() rejects an unknown backend")
  ui.setup({})
  check(#health_errors("ui") == 0, ":checkhealth ui has no errors")
end

function tests.cmdline()
  local cmdline = require("cmdline")
  local Config = require("cmdline.config")
  check(not Config.is_running(), "cmdline stays off without setup()")
  check(vim.fn.exists(":Cmdline") == 2, ":Cmdline exists")
  vim.cmd("Cmdline enable")
  check(Config.is_running(), ":Cmdline enable before setup() uses vim.g.cmdline")
  vim.cmd("Cmdline toggle")
  check(not Config.is_running(), ":Cmdline toggle")
  check(not pcall(Config.setup, { confirm = { style = "nope" } }), "setup rejects a wrong confirm.style")
  Config.setup({})
  cmdline.enable()
  check(Config.is_running(), "enable() after setup")
  check(#health_errors("cmdline") == 0, ":checkhealth cmdline has no errors")
end

-- run after VimEnter, like a real session
vim.schedule(function()
  local ok, err = xpcall(tests[name], debug.traceback)
  if not ok then
    failures = failures + 1
    io.stdout:write("FAIL " .. tostring(err) .. "\n")
  end
  io.stdout:write(("%s: %d failure(s)\n"):format(name, failures))
  vim.cmd(failures == 0 and "qa!" or "cquit 1")
end)
