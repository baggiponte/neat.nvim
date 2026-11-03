-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors.
-- Source: default diagnostic symbols and section layout
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.

---@alias neat.statusline.Color string|false|vim.api.keyset.highlight palette key, hex string, false (inherit) or a highlight table
---@alias neat.statusline.Component string|fun(ctx: neat.statusline.Context): string?

---@class neat.statusline.Context
---@field win integer
---@field buf integer
---@field active boolean
---@field cfg neat.statusline.Config

---@class neat.statusline.Sections
---@field a? neat.statusline.Component[]
---@field b? neat.statusline.Component[]
---@field c? neat.statusline.Component[]
---@field x? neat.statusline.Component[]
---@field y? neat.statusline.Component[]
---@field z? neat.statusline.Component[]

--- `statusline` options for `require("neat").setup()`. Every field is optional.
---@class neat.statusline.Config
---@field palette? table<string, string> name -> hex colour
---@field colors? {modes?: table<string, neat.statusline.Color>, b?: neat.statusline.Color, c?: neat.statusline.Color, x?: neat.statusline.Color, y?: neat.statusline.Color, z?: neat.statusline.Color, inactive?: neat.statusline.Color}
---@field icons? {mode?: string, branch?: string, lsp?: string, diff?: {added?: string, changed?: string, removed?: string}, diagnostics?: {error?: string, warn?: string, info?: string, hint?: string}}
---@field providers? neat.statusline.Providers where file icons and git status come from
---@field lsp_scope? "all"|"buffer"
---@field diagnostics_update_in_insert? boolean
---@field sections? neat.statusline.Sections replaces the default sections one by one
---@field inactive_sections? neat.statusline.Sections replaces the default inactive sections whole
---@field extensions? table<string, neat.statusline.Sections|false> filetype -> sections; false disables a built-in one

local M = {}

-- gruvbox-material variation (same palette as the lualine theme it replaces)
---@type neat.statusline.Config
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

  -- Adapters for the plugins the statusline reads (`:h neat-statusline-providers`):
  -- a provider name, a table of your own, or false for none.
  providers = {
    icons = 'devicons', -- nvim-web-devicons, required after the first draw
    git = 'gitsigns', -- gitsigns' buffer variables; the branch falls back to .git/HEAD
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
    x = { 'showcmd', 'recording', 'diagnostics' },
    y = { 'lsp_progress', 'lsp' },
    z = { 'searchcount', 'location', 'progress' },
  },
  inactive_sections = {
    c = { 'filename' },
    x = { 'location' },
  },

  -- filetype -> sections table. Set an entry to false to disable it.
  extensions = {},
}

return M
