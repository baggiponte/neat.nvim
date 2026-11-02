-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: lua/lualine/components/diff/init.lua and components/diagnostics/config.lua
-- (fallback colours), highlight.lua (section z takes the mode colour)
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.

local rgb2cterm = require('statusline.cterm').rgb2cterm

local M = {}

local cfg ---@type table

--- nvim_set_hl with 256-colour fallbacks for hex fg/bg.
local function set_hl(name, hl)
  for gui, cterm in pairs({ fg = 'ctermfg', bg = 'ctermbg' }) do
    local v = hl[gui]
    if type(v) == 'string' and v:match('^#%x%x%x%x%x%x$') then
      hl[cterm] = rgb2cterm(v)
    end
  end
  vim.api.nvim_set_hl(0, name, hl)
end

local function resolve(spec)
  if spec == nil or spec == false then
    return nil
  end
  if type(spec) == 'string' then
    spec = { fg = spec }
  end
  local p = cfg.palette
  local out = {}
  for k, v in pairs(spec) do
    if (k == 'fg' or k == 'bg' or k == 'sp') and type(v) == 'string' then
      out[k] = p[v] or v
    else
      out[k] = v
    end
  end
  return out
end

--- Highlight reference for a colour spec: '%#Group#', or '%*' to inherit
--- StatusLine/StatusLineNC.
---@type table<string, string>
M.ref = {}

local function define(name, spec)
  local hl = resolve(spec)
  if not hl then
    M.ref[name] = '%*'
    return
  end
  set_hl('Stl' .. name, hl)
  M.ref[name] = '%#Stl' .. name .. '#'
end

local function fg_of(groups, fallback)
  for _, g in ipairs(groups) do
    local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
    if hl.fg then
      return string.format('#%06x', hl.fg)
    end
    if hl.sp then
      return string.format('#%06x', hl.sp)
    end
  end
  return fallback
end

local icon_cache = {}

--- Statusline group for a devicons highlight (fg only, transparent bg).
---@param group string
---@return string
function M.icon(group)
  local ref = icon_cache[group]
  if ref then
    return ref
  end
  local name = 'StlIcon' .. group:gsub('[^%w]', '')
  local fg = fg_of({ group }, nil)
  if fg then
    set_hl(name, { fg = fg })
    ref = '%#' .. name .. '#'
  else
    ref = M.ref.C
  end
  icon_cache[group] = ref
  return ref
end

function M.setup(config)
  cfg = config
  M.apply()
end

function M.apply()
  icon_cache = {}
  local c = cfg.colors
  for mode, spec in pairs(c.modes) do
    define('A' .. mode, spec)
    define('Z' .. mode, mode == 'normal' and c.z or spec)
  end
  for _, s in ipairs({ 'b', 'c', 'x', 'y' }) do
    define(s:upper(), c[s])
  end
  define('Inactive', c.inactive)

  define('DiffAdded', fg_of({ 'GitSignsAdd', 'DiffAdded', 'DiffAdd' }, '#90ee90'))
  define('DiffChanged', fg_of({ 'GitSignsChange', 'DiffChanged', 'DiffChange' }, '#f0e130'))
  define('DiffRemoved', fg_of({ 'GitSignsDelete', 'DiffRemoved', 'DiffDelete' }, '#ff0038'))
  define('DiagError', fg_of({ 'DiagnosticError' }, '#e32636'))
  define('DiagWarn', fg_of({ 'DiagnosticWarn' }, '#ffa500'))
  define('DiagInfo', fg_of({ 'DiagnosticInfo', 'Normal' }, '#ffffff'))
  define('DiagHint', fg_of({ 'DiagnosticHint' }, '#273faf'))
end

return M
