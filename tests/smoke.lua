-- Headless smoke test. Loads neat.nvim the way vim.pack does (on 'runtimepath',
-- plugin/ sourced at startup) and exercises one scenario:
--
--   SMOKE=<scenario> nvim --headless --clean --cmd "set rtp^=$PWD" --cmd 'luafile tests/smoke.lua'
--
-- Scenarios: off, statusline, ui, cmdline (cmdline needs nui.nvim on 'rtp' too).
-- Runs before plugin/ (so it can set vim.g.neat), tests after VimEnter, and
-- exits non-zero on the first failure.
local name = assert(os.getenv("SMOKE"), "set SMOKE to off, statusline, ui or cmdline")
local failures = 0

local function check(cond, msg)
  if cond then
    io.stdout:write("ok   " .. msg .. "\n")
  else
    failures = failures + 1
    io.stdout:write("FAIL " .. msg .. "\n")
  end
end

local function health_errors()
  vim.cmd("checkhealth neat")
  local errors = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    io.stdout:write("     | " .. line .. "\n")
    if line:find("ERROR") then
      errors[#errors + 1] = line
    end
  end
  vim.cmd("bwipeout!")
  return errors
end

local function loaded(mod)
  return package.loaded[mod] ~= nil
end

local tests = {}

function tests.off()
  check(vim.fn.exists(":Neat") == 2, ":Neat exists")
  check(not loaded("neat"), "nothing is required without vim.g.neat")
  require("neat").setup({})
  for _, mod in ipairs({ "neat.statusline", "neat.notify", "neat.select", "neat.indent", "neat.cmdline" }) do
    check(not loaded(mod), mod .. " is not loaded when off")
  end
  check(vim.go.statusline == "", "'statusline' is untouched")
  vim.cmd("helptags doc")
  check(pcall(vim.cmd, "help neat"), ":h neat")
  check(pcall(vim.cmd, "help :Neat-indent"), ":h :Neat-indent")
  vim.cmd("helpclose")
  check(not pcall(require("neat").setup, { notify = { enabled = "yes" } }), "setup() rejects a non-boolean enabled")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

function tests.statusline()
  require("neat").setup({ statusline = { enabled = true } })
  local sl = require("neat.statusline")
  check(sl.did_setup, "statusline started")
  check(sl.is_enabled(), "'statusline' is ours")
  check(type(sl.render()) == "string", "render() returns a string")
  vim.cmd("Neat statusline disable")
  check(not sl.is_enabled(), ":Neat statusline disable")
  vim.cmd("Neat statusline toggle")
  check(sl.is_enabled(), ":Neat statusline toggle")
  vim.cmd("Neat statusline refresh")
  sl.setup({ lsp_scope = "buffer" })
  check(sl.config.lsp_scope == "buffer", "setup() again applies new options")
  check(not pcall(sl.setup, { lsp_scope = 1 }), "setup() rejects a wrong type")
  sl.setup({})
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

-- started through vim.g.neat (set below, before plugin/neat.lua runs)
function tests.ui()
  check(require("neat").did_setup, "plugin/neat.lua ran setup() from vim.g.neat")
  check(not loaded("neat.statusline"), "statusline stays off")
  check(not loaded("neat.input"), "neat.input is not loaded at startup")
  check(not loaded("neat.notify.notifier"), "the notifier is not loaded at startup")
  check(not loaded("neat.indent.snacks"), "the indent engine is not loaded without a file")
  vim.notify("smoke test")
  check(loaded("neat.notify.notifier"), "the first vim.notify() loads the notifier")
  check(vim.notify == require("neat.notify.notifier").notify, "vim.notify is the notifier after the first call")
  check(vim.ui.select == require("neat.select").select, "vim.ui.select is neat's")
  vim.cmd("edit tests/smoke.lua")
  check(loaded("neat.indent.snacks"), "opening a file loads the indent engine")
  vim.cmd("Neat indent off")
  check(not require("neat.indent.snacks").enabled, ":Neat indent off")
  vim.cmd("Neat indent toggle")
  check(require("neat.indent.snacks").enabled, ":Neat indent toggle")
  check(not pcall(require("neat.notify").setup, { backend = "nope" }), "notify rejects an unknown backend")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

function tests.cmdline()
  local Config = require("neat.cmdline.config")
  check(not Config.is_running(), "cmdline stays off without enabled = true")
  vim.cmd("Neat cmdline enable")
  check(Config.is_running(), ":Neat cmdline enable")
  vim.cmd("Neat cmdline toggle")
  check(not Config.is_running(), ":Neat cmdline toggle")
  check(not pcall(Config.setup, { confirm = { style = "nope" } }), "setup rejects a wrong confirm.style")
  Config.setup({})
  require("neat").setup({ cmdline = { enabled = true } })
  vim.wait(1000, Config.is_running)
  check(Config.is_running(), "neat.setup({ cmdline = { enabled = true } }) starts it")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

if name == "ui" then
  vim.g.neat = {
    select = { enabled = true },
    input = { enabled = true },
    notify = { enabled = true, backend = "snacks" },
    indent = { enabled = true, backend = "snacks" },
  }
end

-- run after VimEnter, like a real session
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = xpcall(tests[name], debug.traceback)
      if not ok then
        failures = failures + 1
        io.stdout:write("FAIL " .. tostring(err) .. "\n")
      end
      io.stdout:write(("%s: %d failure(s)\n"):format(name, failures))
      vim.cmd(failures == 0 and "qa!" or "cquit 1")
    end)
  end,
})
