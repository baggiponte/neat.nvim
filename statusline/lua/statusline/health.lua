-- :checkhealth statusline
local M = {}

local health = vim.health

---@param user table
---@param defaults table
---@param prefix string
---@param out string[]
local function unknown_keys(user, defaults, prefix, out)
  for k, v in pairs(user) do
    local path = prefix .. tostring(k)
    if defaults[k] == nil then
      out[#out + 1] = path
    elseif type(v) == 'table' and type(defaults[k]) == 'table' and not vim.islist(v) then
      unknown_keys(v, defaults[k], path .. '.', out)
    end
  end
  return out
end

function M.check()
  health.start('statusline.nvim')
  if vim.fn.has('nvim-0.12') == 1 then
    health.ok('Neovim ' .. tostring(vim.version()))
  else
    health.error('Neovim >= 0.12 is required')
  end

  local sl = require('statusline')
  if not sl.did_setup then
    health.warn('setup() has not run', 'plugin/statusline.lua runs it at startup unless vim.g.loaded_statusline is set')
    return
  end

  if sl.is_enabled() then
    health.ok("'statusline' is drawn by statusline.nvim")
  else
    health.warn(
      "'statusline' was changed after setup(): " .. vim.go.statusline,
      'Another plugin or your config set it; `:Statusline enable` takes it back'
    )
  end
  if vim.o.laststatus == 0 then
    health.warn("'laststatus' is 0, so no statusline is shown")
  end

  -- palette, sections and extensions are open-ended maps
  local defaults = vim.deepcopy(require('statusline.config').defaults)
  local user = vim.deepcopy(sl.user_options)
  for _, k in ipairs({ 'palette', 'sections', 'inactive_sections', 'extensions' }) do
    defaults[k], user[k] = nil, nil
  end
  if type(user.colors) == 'table' then
    user.colors.modes = nil
  end
  local unknown = unknown_keys(user, defaults, '', {})
  if #unknown == 0 then
    health.ok('No unknown options')
  else
    table.sort(unknown)
    health.warn('Unknown options (typos?): ' .. table.concat(unknown, ', '))
  end

  if vim.o.termguicolors then
    health.ok("'termguicolors' is on")
  else
    health.info("'termguicolors' is off: using 256-colour approximations of the palette")
  end

  if pcall(require, 'gitsigns') then
    health.ok('gitsigns.nvim is installed: branch and diff come from it')
  else
    health.info('gitsigns.nvim is not installed: the branch is read from .git/HEAD and diff counts are empty')
  end

  if pcall(require, 'nvim-web-devicons') then
    health.ok('nvim-web-devicons is installed')
  else
    health.info('nvim-web-devicons is not installed: the fileicon component is empty')
  end
end

return M
