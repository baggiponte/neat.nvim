-- Adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: lua/lualine/utils/mode.lua (mode labels), components/location.lua,
-- components/progress.lua and components/filename.lua (the [+]/[-] flags)
-- at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.
-- Changes: plain functions over a per-buffer cache instead of component classes;
-- modes also carry a highlight family.

-- Built-in components. Each is function(ctx): string|nil, where
-- ctx = { win = winid, buf = bufnr, active = boolean, cfg = config }.
-- Return '' or nil to hide the component. Text must be statusline-escaped.
local api = vim.api
local hl = require('statusline.highlights')
local cache = require('statusline.cache')

local M = {}

local function esc(s)
  return (s:gsub('%%', '%%%%'))
end
M.escape = esc

-- mode ----------------------------------------------------------------------

-- label, highlight family
local modes = {
  n = { 'NORMAL', 'normal' },
  no = { 'O-PENDING', 'normal' },
  nov = { 'O-PENDING', 'normal' },
  noV = { 'O-PENDING', 'normal' },
  ['no\22'] = { 'O-PENDING', 'normal' },
  v = { 'VISUAL', 'visual' },
  vs = { 'VISUAL', 'visual' },
  V = { 'V-LINE', 'visual' },
  Vs = { 'V-LINE', 'visual' },
  ['\22'] = { 'V-BLOCK', 'visual' },
  ['\22s'] = { 'V-BLOCK', 'visual' },
  s = { 'SELECT', 'visual' },
  S = { 'S-LINE', 'visual' },
  ['\19'] = { 'S-BLOCK', 'visual' },
  i = { 'INSERT', 'insert' },
  ic = { 'INSERT', 'insert' },
  ix = { 'INSERT', 'insert' },
  R = { 'REPLACE', 'replace' },
  Rc = { 'REPLACE', 'replace' },
  Rx = { 'REPLACE', 'replace' },
  Rv = { 'V-REPLACE', 'replace' },
  Rvc = { 'V-REPLACE', 'replace' },
  Rvx = { 'V-REPLACE', 'replace' },
  c = { 'COMMAND', 'command' },
  cv = { 'EX', 'command' },
  ce = { 'EX', 'command' },
  cr = { 'COMMAND', 'command' },
  r = { 'REPLACE', 'replace' },
  rm = { 'MORE', 'normal' },
  ['r?'] = { 'CONFIRM', 'normal' },
  ['!'] = { 'SHELL', 'normal' },
  t = { 'TERMINAL', 'terminal' },
  nt = { 'NORMAL', 'normal' },
  ntT = { 'NORMAL', 'normal' },
}
local by_first =
  { n = 'normal', v = 'visual', V = 'visual', i = 'insert', R = 'replace', c = 'command', t = 'terminal' }

--- Current mode: label and highlight family ('normal', 'insert', ...).
---@return string, string
function M.mode_info()
  local m = api.nvim_get_mode().mode
  local e = modes[m]
  if e then
    return e[1], e[2]
  end
  local fam = by_first[m:sub(1, 1)] or 'normal'
  return modes[m:sub(1, 1)] and modes[m:sub(1, 1)][1] or m, fam
end

function M.mode(ctx)
  local label = M.mode_info()
  local icon = ctx.cfg.icons.mode
  return icon ~= '' and (icon .. ' ' .. label) or label
end

-- git -----------------------------------------------------------------------

function M.branch(ctx)
  local head = cache.git(ctx.buf).head
  if head == '' then
    return ''
  end
  local icon = ctx.cfg.icons.branch
  return icon ~= '' and (icon .. ' ' .. head) or head
end

function M.diff(ctx)
  return cache.git(ctx.buf).diff
end

-- file ----------------------------------------------------------------------

function M.fileicon(ctx)
  return cache.file(ctx.buf).icon
end

function M.filepath(ctx)
  return cache.file(ctx.buf).path
end

--- Tail with [+]/[-] flags (lualine 'filename' defaults, used for inactive windows).
function M.filename(ctx)
  local f = cache.file(ctx.buf)
  local s = f.name
  if vim.bo[ctx.buf].modified then
    s = s .. ' [+]'
  end
  if not vim.bo[ctx.buf].modifiable or vim.bo[ctx.buf].readonly then
    s = s .. ' [-]'
  end
  return s
end

-- diagnostics / lsp -----------------------------------------------------------

function M.diagnostics(ctx)
  return cache.diagnostics(ctx.buf)
end

function M.lsp(ctx)
  return cache.lsp(ctx.cfg.lsp_scope == 'buffer' and ctx.buf or nil)
end

-- position --------------------------------------------------------------------

function M.location(ctx)
  local line = vim.fn.line('.', ctx.win)
  local col = vim.fn.charcol('.', ctx.win)
  return string.format('%3d:%-2d', line, col)
end

function M.progress(ctx)
  local cur = vim.fn.line('.', ctx.win)
  if cur == 1 then
    return 'Top'
  end
  local total = vim.fn.line('$', ctx.win)
  if cur == total then
    return 'Bot'
  end
  return string.format('%2d%%%%', math.floor(cur / total * 100))
end

M._hl = hl
return M
