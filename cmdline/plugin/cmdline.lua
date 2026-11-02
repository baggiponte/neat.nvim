-- cmdline.nvim entry point. Kept small: nothing is required until it is used.
-- The popup itself is opt-in: call require("cmdline").setup(), or set
-- vim.g.cmdline (a table of options, or a function returning one) before startup.
if vim.g.loaded_cmdline then
  return
end
vim.g.loaded_cmdline = true

local subcommands = {
  enable = function()
    require("cmdline").enable()
  end,
  disable = function()
    require("cmdline").disable()
  end,
  toggle = function()
    require("cmdline").toggle()
  end,
}

vim.api.nvim_create_user_command("Cmdline", function(args)
  local fn = subcommands[args.fargs[1]]
  if not fn then
    vim.notify("Cmdline: unknown subcommand " .. vim.inspect(args.fargs[1]), vim.log.levels.ERROR)
    return
  end
  fn()
end, {
  nargs = 1,
  desc = "cmdline.nvim: enable, disable or toggle the cmdline popup",
  complete = function(arglead)
    return vim.tbl_filter(function(name)
      return name:find(arglead, 1, true) == 1
    end, vim.tbl_keys(subcommands))
  end,
})

if vim.g.cmdline ~= nil then
  require("cmdline").setup()
end
