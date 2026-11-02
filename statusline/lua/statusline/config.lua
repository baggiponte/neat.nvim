-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors.
-- Source: default diagnostic symbols and section layout
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.

---@class statusline.Config
local M = {}

-- gruvbox-material variation (same palette as the lualine theme it replaces)
M.defaults = {
  palette = {
    lightgrey = '#a89984',
    darkgrey = '#504945',
    dust = '#ddc7a1',
    black = '#32302f',
    red = '#ea6962',
    yellow = '#d8a657',
    green = '#a9b665',
    orange = '#e78a4e',
    purple = '#d3869b',
    aqua = '#89b482',
    blue = '#7daea3',
  },

  -- Foreground per section. A colour is a palette key, a hex string, false
  -- (inherit StatusLine / StatusLineNC) or a table { fg = ..., bg = ..., bold = true }.
  -- No backgrounds by default: the colorscheme's StatusLine shows through.
  colors = {
    -- section "a" (mode) colour depends on the mode; outside normal mode,
    -- section "z" takes the mode colour too (lualine's theme fallback)
    modes = {
      normal = { fg = 'dust', bold = true },
      insert = 'aqua',
      visual = 'red',
      replace = 'green',
      command = 'yellow',
      terminal = 'purple',
    },
    b = 'red',
    c = 'dust',
    x = 'blue',
    y = 'aqua',
    z = 'dust',
    -- inactive windows: sections a and z use this, the rest keep their colour
    inactive = 'darkgrey',
  },

  icons = {
    mode = '\u{e62b}',
    branch = '\u{e0a0}',
    lsp = '\u{f085}',
    diff = { added = '+', changed = '~', removed = '-' },
    diagnostics = { error = '󰅚 ', warn = '󰀪 ', info = '󰋽 ', hint = '󰌶 ' },
  },

  -- 'all': every running client (what the lualine widget did); 'buffer': only
  -- clients attached to the window's buffer.
  lsp_scope = 'all',

  -- Keep the last diagnostic counts while in insert mode.
  diagnostics_update_in_insert = false,

  -- Layout. Each entry is a built-in component name or function(ctx): string.
  sections = {
    a = { 'mode' },
    b = { 'branch', 'diff' },
    c = { 'fileicon', 'filepath' },
    x = { 'diagnostics' },
    y = { 'lsp' },
    z = { 'location', 'progress' },
  },
  inactive_sections = {
    c = { 'filename' },
    x = { 'location' },
  },

  -- filetype -> sections table. Set an entry to false to disable it.
  extensions = {},
}

return M
