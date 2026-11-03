-- Headless smoke test. Loads neat.nvim the way vim.pack does (on 'runtimepath',
-- plugin/ sourced at startup) and exercises one scenario:
--
--   SMOKE=<scenario> nvim --headless --clean --cmd "set rtp^=$PWD" --cmd 'luafile tests/smoke.lua'
--
-- Scenarios: off, statusline, ui, cmdline (cmdline needs nui.nvim on 'rtp' too).
-- Runs before plugin/ (so it can set vim.g.neat), tests after VimEnter, and
-- exits non-zero on the first failure.
-- Tests stub functions (vim.ui.select, vim.notify, ...) and pass wrong types on purpose.
---@diagnostic disable: duplicate-set-field
local name = assert(os.getenv("SMOKE"), "set SMOKE to off, statusline, ui or cmdline")
local failures = 0
-- Neovim 0.12 ships a default 'statusline'; "off" must leave it as it was
local initial_statusline = vim.go.statusline

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
  check(vim.fn.maparg("<Plug>(neat-spell-suggest)", "n") ~= "", "<Plug>(neat-spell-suggest) exists without setup()")
  check(vim.fn.maparg("z=", "n") == "", "z= is not mapped without setup()")
  require("neat").setup({})
  local modules = { "neat.statusline", "neat.notify", "neat.select", "neat.indent", "neat.cmdline", "neat.spell" }
  for _, mod in ipairs(modules) do
    check(not loaded(mod), mod .. " is not loaded when off")
  end
  check(vim.go.statusline == initial_statusline, "'statusline' is untouched")
  vim.cmd("helptags doc")
  check(pcall(vim.cmd.help, "neat"), ":h neat")
  check(pcall(vim.cmd.help, ":Neat-indent"), ":h :Neat-indent")
  vim.cmd("helpclose")
  check(not pcall(require("neat").setup, { notify = { enabled = "yes" } }), "setup() rejects a non-boolean enabled")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
  require("neat").setup({ select = { backnd = "telescope" } })
  vim.cmd("checkhealth neat")
  local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")
  check(report:find("select.backnd", 1, true) ~= nil, ":checkhealth neat lists a misspelled option")
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
  local function progress(value)
    vim.api.nvim_exec_autocmds("LspProgress", { data = { client_id = 1, params = { token = "t", value = value } } })
  end
  progress({ kind = "begin", title = "indexing", percentage = 10 })
  check(sl.render():find("indexing 10%%", 1, true) ~= nil, "LspProgress shows in the statusline")
  progress({ kind = "end" })
  check(sl.render():find("indexing", 1, true) == nil, "progress clears on end")
  sl.setup({ lsp_scope = "buffer" })
  check(sl.config.lsp_scope == "buffer", "setup() again applies new options")
  ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
  check(not pcall(sl.setup, { lsp_scope = 1 }), "setup() rejects a wrong type")
  sl.setup({})

  -- Drawing must not load plugins (the statusline runs under textlock, where a
  -- plugin manager's require hook can fail with E565): devicons is required on
  -- the next tick, then the icon shows.
  local rendering, loaded_while_rendering, loads = false, false, 0
  table.insert(package.loaders, 1, function(modname)
    if modname ~= "nvim-web-devicons" then
      return
    end
    loads = loads + 1
    loaded_while_rendering = loaded_while_rendering or rendering
    return function()
      return {
        get_icon = function()
          return "@icon@", "DevIconLua"
        end,
        get_icon_by_filetype = function() end,
      }
    end
  end)
  vim.cmd("edit tests/smoke.lua")
  rendering = true
  sl.render()
  rendering = false
  check(not loaded_while_rendering, "render() does not require nvim-web-devicons")
  vim.wait(500, function()
    return loads > 0
  end)
  check(loads == 1, "nvim-web-devicons is required once, after the draw")
  check(sl.render():find("@icon@", 1, true) ~= nil, "the file icon shows once devicons is loaded")
  vim.cmd("bwipeout!")

  -- providers of your own: icons and git status
  local status = { head = "feature", added = 2 } ---@type neat.statusline.GitStatus
  sl.setup({
    providers = {
      icons = {
        load = function()
          return true
        end,
        get = function(_, ft)
          return "<" .. ft .. ">", nil
        end,
      },
      git = {
        status = function()
          return status
        end,
        events = { { event = "User", pattern = "SmokeGit" } },
      },
    },
  })
  vim.cmd("edit tests/smoke.lua")
  sl.render()
  vim.wait(500, function()
    return sl.render():find("<lua>", 1, true) ~= nil
  end)
  check(sl.render():find("<lua>", 1, true) ~= nil, "providers.icons: your provider's icon shows")
  check(sl.render():find("feature", 1, true) ~= nil, "providers.git: your provider's branch shows")
  check(sl.render():find("+2", 1, true) ~= nil, "providers.git: your provider's diff shows")
  status = { head = "other" }
  vim.api.nvim_exec_autocmds("User", { pattern = "SmokeGit" })
  check(sl.render():find("other", 1, true) ~= nil, "providers.git: its events drop the cached status")
  ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
  check(not pcall(sl.setup, { providers = { icons = "nope" } }), "providers: an unknown name is rejected")
  sl.setup({ providers = { icons = false, git = false } })
  check(sl.render():find("<lua>", 1, true) == nil, "providers.icons = false: no icon")
  vim.cmd("bwipeout!")
  sl.setup({})
  vim.bo.filetype = "neo-tree"
  check(not sl.render():find(vim.fn.fnamemodify(vim.fn.getcwd(), ":~"), 1, true), "the neo-tree statusline is empty")
  vim.bo.filetype = ""

  -- what the cmdline row showed before 'cmdheight' 0
  vim.cmd("enew")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "foo", "bar", "foo", "foo" })
  vim.fn.setreg("/", "foo")
  vim.o.hlsearch = true
  vim.v.hlsearch = 1
  check(sl.render():find("/3]", 1, true) ~= nil, "searchcount shows [x/3] for the last search")
  vim.v.hlsearch = 0
  check(sl.render():find("/3]", 1, true) == nil, "searchcount hides after :nohlsearch")
  check(vim.o.showcmdloc == "statusline", "the showcmd component moves 'showcmd' into the statusline")
  check(sl.render():find("%S", 1, true) ~= nil, "showcmd draws through %S")
  vim.cmd("bwipeout!")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

-- started through vim.g.neat (set below, before plugin/neat.lua runs)
function tests.ui()
  check(require("neat").did_setup, "plugin/neat.lua ran setup() from vim.g.neat")
  check(not loaded("neat.statusline"), "statusline stays off")
  check(not loaded("neat.input.window") and not loaded("neat.win"), "the input window is not loaded at startup")
  check(vim.ui.input == require("neat.input").input, "vim.ui.input is neat's")
  check(not loaded("neat.notify.notifier"), "the notifier is not loaded at startup")
  check(not loaded("neat.indent.guides"), "the indent engine is not loaded without a file")
  vim.notify("smoke test")
  check(loaded("neat.notify.notifier"), "the first vim.notify() loads the notifier")
  check(require("neat.notify").shows_toasts(), "the builtin backend shows toasts")
  -- a backend of your own
  local notify_backend = {
    toasts = false,
    notify = function() end,
  }
  require("neat.notify").setup({ backend = notify_backend })
  check(vim.notify == notify_backend.notify, "notify: vim.notify is your backend's notify()")
  check(not require("neat.notify").shows_toasts(), "notify: your backend says it shows no toasts")
  require("neat.notify").setup({ backend = "builtin" })
  check(not loaded("notify"), "nvim-notify is never required by the builtin backend")
  check(vim.ui.select == require("neat.select").select, "vim.ui.select is neat's")
  check(not loaded("neat.select.backends.telescope"), "the telescope backend is not loaded at startup")

  -- select: a backend of your own gets a normalised copy of the opts
  local sel = require("neat.select")
  local got_select ---@type {opts: neat.select.Opts, backend_opts: table?}?
  sel.setup({
    backend = {
      available = function()
        return true
      end,
      select = function(items, opts, on_choice, backend_opts)
        got_select = { opts = opts, backend_opts = backend_opts }
        on_choice(items[2], 2)
      end,
    },
  })
  local caller_opts = { prompt = "Pick\none:" }
  local choice ---@type {item: any, idx: integer?}?
  vim.ui.select({ "a", "b" }, caller_opts, function(item, idx)
    choice = { item = item, idx = idx }
  end)
  vim.wait(1000, function()
    return choice ~= nil
  end)
  check(got_select ~= nil and got_select.opts.prompt == "Pick one", "select: the prompt is one line without ':'")
  check(got_select ~= nil and got_select.opts.format_item(1) == "1", "select: format_item is always set")
  check(
    caller_opts.prompt == "Pick\none:" and caller_opts.format_item == nil,
    "select: the caller's opts are untouched"
  )
  check(choice ~= nil and choice.item == "b" and choice.idx == 2, "select: the backend's pick reaches on_choice")
  -- a backend that is not available falls back to the vim.ui.select neat replaced
  local fallback_items ---@type any[]?
  vim.ui.select = function(items, _, on_choice)
    fallback_items = items
    on_choice(nil, nil)
  end
  sel.setup({ backend = "telescope" })
  vim.ui.select({ "x" }, {}, function() end)
  vim.wait(1000, function()
    return fallback_items ~= nil
  end)
  check(fallback_items ~= nil, "select: without telescope, vim.ui.select falls back to the one it replaced")
  ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
  check(not pcall(sel.setup, { backend = "nope" }), "select rejects an unknown backend")
  sel.setup({ backend = "telescope" })

  check(vim.fn.maparg("z=", "n") ~= "", "spell maps z=")
  -- z= hands the suggestions to whatever vim.ui.select is, and replaces the word
  local select = vim.ui.select
  local got ---@type {items: string[], prompt: string}?
  vim.ui.select = function(items, opts, on_choice)
    got = { items = items, prompt = opts.prompt }
    on_choice(items[1])
  end
  vim.cmd("enew")
  vim.bo.spelllang = "en"
  vim.wo.spell = true
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "teh cat" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.fn.setreg('"', "kept")
  require("neat.spell").suggest()
  check(got ~= nil and #got.items > 0 and got.prompt == 'Change "teh" to', "z= passes suggestions to vim.ui.select")
  check(got ~= nil and vim.api.nvim_get_current_line() == got.items[1] .. " cat", "z= replaces the word with the pick")
  check(vim.fn.getreg('"') == "kept", "z= leaves the unnamed register alone")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "the  wrold" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- between the words: <cword> is the next one
  require("neat.spell").suggest()
  check(got ~= nil and got.prompt == 'Change "wrold" to', "z= between words takes the next word, like <cword>")
  check(got ~= nil and vim.api.nvim_get_current_line() == "the  " .. got.items[1], "z= replaces only that word")
  vim.ui.select = select
  vim.cmd("bwipeout!")
  vim.cmd("edit tests/smoke.lua")
  check(loaded("neat.indent.guides"), "opening a file loads the indent engine")
  vim.cmd("Neat indent off")
  check(not require("neat.indent.guides").enabled, ":Neat indent off")
  vim.cmd("Neat indent toggle")
  check(require("neat.indent.guides").enabled, ":Neat indent toggle")
  -- input: the first vim.ui.input() opens the window
  local answer ---@type string?
  vim.ui.input({ prompt = "Name:", default = "neat" }, function(value)
    answer = value
  end)
  check(loaded("neat.input.window"), "the first vim.ui.input() loads the input window")
  check(vim.bo.filetype == "ui_input" and vim.api.nvim_win_get_config(0).relative ~= "", "input: a float opens")
  check(vim.api.nvim_get_current_line() == "neat", "input: the default is filled in")
  vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
  vim.wait(1000, function()
    return answer ~= nil
  end)
  check(answer == "neat", "input: <CR> confirms the text")
  ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
  check(not pcall(require("neat.notify").setup, { backend = "nope" }), "notify rejects an unknown backend")
  check(not loaded("snacks"), "snacks.nvim is never required")
  check(#health_errors() == 0, ":checkhealth neat has no errors")
end

function tests.cmdline()
  local Config = require("neat.cmdline.config")
  check(not Config.is_running(), "cmdline stays off without enabled = true")
  vim.cmd("Neat cmdline enable")
  check(Config.is_running(), ":Neat cmdline enable")
  vim.cmd("Neat cmdline toggle")
  check(not Config.is_running(), ":Neat cmdline toggle")
  ---@diagnostic disable-next-line: assign-type-mismatch, missing-fields
  check(not pcall(Config.setup, { confirm = { style = "nope" } }), "setup rejects a wrong confirm.style")
  Config.setup({})
  require("neat").setup({ cmdline = { enabled = true } })
  vim.wait(1000, Config.is_running)
  check(Config.is_running(), "neat.setup({ cmdline = { enabled = true } }) starts it")
  -- the popup only requires most modules (and nui) once you type ':', so load them all here
  local root = vim.api.nvim_get_runtime_file("lua/neat/cmdline/init.lua", false)[1]:gsub("/init%.lua$", "")
  for path in vim.fs.dir(root, { depth = 5 }) do
    if path:match("%.lua$") then
      local mod = ("neat.cmdline." .. path:gsub("%.lua$", ""):gsub("/", ".")):gsub("%.init$", "")
      local ok, err = pcall(require, mod)
      check(ok, "require('" .. mod .. "')" .. (ok and "" or ": " .. tostring(err)))
    end
  end
  check(vim.o.cmdheight == 1, "cmdline leaves 'cmdheight' alone")
  check(require("neat.cmdline.ui2").start == nil, "neat has no code that sets 'cmdheight' or enables ui2")
  vim.cmd("checkhealth neat")
  local report = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  vim.cmd("bwipeout!")
  check(report:find("'cmdheight' is 1", 1, true) ~= nil, ":checkhealth neat warns about 'cmdheight' > 0")
  check(report:find("ui2 is not enabled", 1, true) ~= nil, ":checkhealth neat warns when ui2 is off")
  check(
    vim.api.nvim_get_hl(0, { name = "NeatCmdlinePopup" }).link == "NoiceCmdlinePopup",
    "NeatCmdlinePopup links to NoiceCmdlinePopup"
  )
  check(
    vim.api.nvim_get_hl(0, { name = "NeatCmdlineIconSearch" }).link == "NoiceCmdlineIconSearch",
    "per-format groups get a Neat name too"
  )
  check(#health_errors() == 0, ":checkhealth neat has no errors")

  -- message routing, against a stand-in for ui2's private module layout
  local shown = {} ---@type {kind: string, target: string?, prompt: boolean}[]
  local fake = { cmd = { prompt = false, level = 0 }, cfg = { msg = { targets = { default = "msg" } } }, msg = {} }
  function fake.msg.msg_show(kind, ...)
    shown[#shown + 1] = { kind = kind, target = fake.cfg.msg.targets[kind], prompt = fake.cmd.prompt }
  end
  package.loaded["vim._core.ui2"] = fake
  local Messages = require("neat.cmdline.messages")
  local Confirm = require("neat.cmdline.confirm")
  local Cmdline = require("neat.cmdline.ui.cmdline")
  Messages.setup(Config.options.messages)
  check(Messages.is_patched(), "messages: ui2's msg_show is wrapped")
  local function chunks(text)
    return { { 0, text, 0 } }
  end

  -- z= / inputlist(): the list arrives as a "confirm" message before a number prompt
  shown = {}
  fake.msg.msg_show("confirm", chunks('Change "teh" to:\n 1 "the"\n 2 "ten"'), false, true, false, 1, "")
  check(#shown == 0, "z=: the list waits for its prompt")
  local number_prompt = "Type number and <Enter> or click with the mouse (q or empty cancels): "
  Cmdline.on_show("cmdline_show", {}, 0, "", number_prompt, 0, 1)
  check(#shown == 1 and shown[1].kind == "confirm", "z=: the list goes to ui2 once the prompt is a number prompt")
  check(shown[1] and shown[1].prompt == true, "z=: ui2 sees an open prompt, so it uses its dialog window")
  check(not Confirm.is_visible(), "z=: no confirm float")
  Cmdline.on_hide("cmdline_hide", 1)

  -- confirm(): the question stays in neat's float
  shown = {}
  fake.cmd.prompt = false
  fake.msg.msg_show("confirm", chunks("Save changes?"), false, true, false, 2, "")
  Cmdline.on_show("cmdline_show", {}, 0, "", "(Y)es, [N]o, (C)ancel: ", 0, 1)
  check(#shown == 0, "confirm(): the question is not passed to ui2")
  check(Confirm.is_visible() and Confirm._question == "Save changes?", "confirm(): float shows the question")
  Cmdline.on_hide("cmdline_hide", 1)
  check(not Confirm.is_visible(), "confirm(): float closes with the prompt")

  -- the message arrives after its prompt (ui2 schedules some messages)
  shown = {}
  fake.cmd.prompt = false
  Cmdline.on_show("cmdline_show", {}, 0, "", "Type number and <Enter> (q or empty cancels): ", 0, 1)
  fake.msg.msg_show("confirm", chunks("1 a\n2 b"), false, true, false, 3, "")
  check(#shown == 1, "inputlist(): a late list goes straight to ui2")
  Cmdline.on_hide("cmdline_hide", 1)

  -- ordinary messages: toasts, pager or ui2 by kind
  local notified = {} ---@type {msg: string, level: integer}[]
  local notify, can_notify = vim.notify, Messages.can_notify
  vim.notify = function(msg, level)
    notified[#notified + 1] = { msg = msg, level = level }
  end
  Messages.can_notify = function()
    return true
  end
  shown = {}
  fake.msg.msg_show("emsg", chunks("E492: Not an editor command: foo"), false, true, false, 4, "")
  check(#notified == 1 and notified[1].level == vim.log.levels.ERROR and #shown == 0, "emsg: an error toast")
  fake.msg.msg_show("echo", chunks("hello"), false, true, false, 5, "")
  check(#notified == 2 and notified[2].msg == "hello", "echo: a toast")
  fake.msg.msg_show("list_cmd", chunks(("line\n"):rep(20)), false, true, false, 6, "")
  check(#shown == 1 and shown[1].target == "pager", "list_cmd, 20 lines: ui2's pager")
  check(fake.cfg.msg.targets.list_cmd == nil, "list_cmd: ui2's targets are restored")
  fake.msg.msg_show("shell_out", chunks("x"), false, true, false, 7, "")
  check(#shown == 2 and shown[2].target == "pager", "shell_out: ui2's pager")
  fake.msg.msg_show("bufwrite", chunks('"x" 1L, 2B written'), false, true, false, 8, "")
  check(#shown == 3 and shown[3].target == nil and #notified == 2, "bufwrite: stays with ui2")
  Messages.can_notify = function()
    return false
  end
  fake.msg.msg_show("emsg", chunks("E1"), false, true, false, 9, "")
  check(#shown == 4 and #notified == 2, "emsg without a toast backend: stays with ui2")
  vim.notify, Messages.can_notify = notify, can_notify

  Messages.restore()
  check(not Messages.is_patched(), "messages: restore() unwraps msg_show")
  package.loaded["vim._core.ui2"] = nil
end

if name == "ui" then
  vim.g.neat = {
    select = { enabled = true },
    input = { enabled = true },
    notify = { enabled = true, backend = "builtin" },
    indent = { enabled = true, backend = "builtin" },
    spell = { enabled = true },
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
