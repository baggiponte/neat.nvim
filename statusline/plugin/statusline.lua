-- statusline.nvim entry point. Draws the statusline with `vim.g.statusline`
-- (or the defaults) unless init.lua already called require('statusline').setup().
-- `vim.g.loaded_statusline = true` turns it off.
if vim.g.loaded_statusline then
  return
end
vim.g.loaded_statusline = true

local subcommands = {
  enable = function()
    require('statusline').enable()
  end,
  disable = function()
    require('statusline').disable()
  end,
  toggle = function()
    local sl = require('statusline')
    if sl.is_enabled() then
      sl.disable()
    else
      sl.enable()
    end
  end,
  refresh = function()
    require('statusline').refresh()
  end,
}

vim.api.nvim_create_user_command('Statusline', function(args)
  local fn = subcommands[args.fargs[1]]
  if not fn then
    vim.notify('Statusline: unknown subcommand ' .. vim.inspect(args.fargs[1]), vim.log.levels.ERROR)
    return
  end
  fn()
end, {
  nargs = 1,
  desc = 'statusline.nvim: enable, disable, toggle or refresh',
  complete = function(arglead)
    return vim.tbl_filter(function(name)
      return name:find(arglead, 1, true) == 1
    end, vim.tbl_keys(subcommands))
  end,
})

if not require('statusline').did_setup then
  require('statusline').setup()
end
