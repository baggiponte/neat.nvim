-- ui.nvim entry point. Starts ui.nvim with `vim.g.ui` (or the defaults) unless
-- init.lua already called require("ui").setup(). `vim.g.loaded_ui = true` turns it off.
-- Kept small: the heavy modules load on first use (see lua/ui/init.lua).
if vim.g.loaded_ui then
  return
end
vim.g.loaded_ui = true

local function on_off(arg)
  if arg == "on" then
    return true
  elseif arg == "off" then
    return false
  end
  -- "toggle" or nothing
end

local subcommands = {
  notifications = {
    run = function()
      require("ui.notify").history()
    end,
  },
  indent = {
    args = { "on", "off", "toggle" },
    run = function(arg)
      require("ui.indent").set(on_off(arg))
    end,
  },
}

vim.api.nvim_create_user_command("Ui", function(args)
  local sub = subcommands[args.fargs[1]]
  if not sub then
    vim.notify("Ui: unknown subcommand " .. vim.inspect(args.fargs[1]), vim.log.levels.ERROR)
    return
  end
  sub.run(args.fargs[2])
end, {
  nargs = "+",
  desc = "ui.nvim: notifications | indent on|off|toggle",
  complete = function(arglead, cmdline)
    local words = vim.split(cmdline, "%s+", { trimempty = true })
    local n = #words - (arglead ~= "" and 1 or 0) -- words before the one being typed
    local candidates = n <= 1 and vim.tbl_keys(subcommands)
      or (n == 2 and subcommands[words[2]] and subcommands[words[2]].args)
      or {}
    return vim.tbl_filter(function(c)
      return c:find(arglead, 1, true) == 1
    end, candidates)
  end,
})

if not require("ui").did_setup then
  require("ui").setup()
end
