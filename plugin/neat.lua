-- neat.nvim entry point. Kept small: it defines :Neat and the <Plug> mappings
-- and, when vim.g.neat is set, starts the modules it enables. Nothing else loads until it is used.
-- `vim.g.loaded_neat = true` turns the plugin off.
if vim.g.loaded_neat then
  return
end
vim.g.loaded_neat = true

--- "on"/"enable" -> true, "off"/"disable" -> false, anything else ("toggle", nil) -> nil.
---@param arg string?
---@return boolean?
local function on_off(arg)
  if arg == "on" or arg == "enable" then
    return true
  elseif arg == "off" or arg == "disable" then
    return false
  end
  -- "toggle" or nothing
end

---@type table<string, {args?: string[], run: fun(arg?: string)}>
local subcommands = {
  cmdline = {
    args = { "enable", "disable", "toggle" },
    run = function(arg)
      local cmdline = require("neat.cmdline")
      local on = on_off(arg)
      if on == nil then
        cmdline.toggle()
      elseif on then
        cmdline.enable()
      else
        cmdline.disable()
      end
    end,
  },
  statusline = {
    args = { "enable", "disable", "toggle", "refresh" },
    run = function(arg)
      local sl = require("neat.statusline")
      if arg == "refresh" then
        return sl.refresh()
      end
      local on = on_off(arg)
      if on == nil then
        on = not sl.is_enabled()
      end
      if on then
        sl.enable()
      else
        sl.disable()
      end
    end,
  },
  indent = {
    args = { "on", "off", "toggle" },
    run = function(arg)
      require("neat.indent").set(on_off(arg))
    end,
  },
  notifications = {
    run = function()
      require("neat.notify").history()
    end,
  },
}

vim.api.nvim_create_user_command("Neat", function(args)
  local sub = subcommands[args.fargs[1]]
  if not sub then
    vim.notify("Neat: unknown subcommand " .. vim.inspect(args.fargs[1]), vim.log.levels.ERROR)
    return
  end
  local arg = args.fargs[2]
  if arg and not (sub.args and vim.tbl_contains(sub.args, arg)) then
    vim.notify(("Neat %s: unknown argument %q"):format(args.fargs[1], arg), vim.log.levels.ERROR)
    return
  end
  sub.run(arg)
end, {
  nargs = "+",
  desc = "neat.nvim: cmdline, statusline, indent, notifications",
  complete = function(arglead, cmdline)
    local words = vim.split(cmdline, "%s+", { trimempty = true })
    local n = #words - (arglead ~= "" and 1 or 0) -- words before the one being typed
    local candidates = n <= 1 and vim.tbl_keys(subcommands)
      or (n == 2 and subcommands[words[2]] and subcommands[words[2]].args)
      or {}
    candidates = vim.tbl_filter(function(c)
      return c:find(arglead, 1, true) == 1
    end, candidates)
    table.sort(candidates)
    return candidates
  end,
})

-- <Plug> mappings work without setup(); map them to any key you like.
vim.keymap.set("n", "<Plug>(neat-spell-suggest)", function()
  require("neat.spell").suggest()
end, { desc = "neat: spelling suggestions through vim.ui.select" })

if vim.g.neat ~= nil and not require("neat").did_setup then
  require("neat").setup()
end
