-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: lua/lualine/components/filetype.lua (icon lookup) and
-- components/diagnostics (severity order) at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.
-- Changes: results are cached per buffer and invalidated by autocmds.

-- Per-buffer caches, invalidated by autocmds (see init.lua). Rendering only
-- reads from here; nothing is polled.
local api = vim.api
local hl = require('neat.statusline.highlights')

local M = {}

local cfg
local files = {} ---@type table<integer, {icon:string, path:string, name:string}>
local gits = {} ---@type table<integer, {head:string, diff:string}>
local diags = {} ---@type table<integer, string>
local lsp_all ---@type string?
local lsp_buf = {} ---@type table<integer, string>
local heads = {} ---@type table<string, string> git dir -> branch

local function esc(s)
  return (s:gsub('%%', '%%%%'))
end

function M.setup(config)
  cfg = config
end

-- file ----------------------------------------------------------------------

local devicons ---@type table|false|nil

-- Same lookup as lualine's filetype component: by file name, then by
-- filetype, then a generic icon; nothing when the buffer has no filetype.
local function get_icon(buf)
  local ft = vim.bo[buf].filetype
  if ft == '' then
    return ''
  end
  if devicons == nil then
    local ok, mod = pcall(require, 'nvim-web-devicons')
    devicons = ok and mod or false
  end
  if not devicons then
    return ''
  end
  local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':t')
  local icon, group = devicons.get_icon(name)
  if icon == nil then
    icon, group = devicons.get_icon_by_filetype(ft)
  end
  if icon == nil and group == nil then
    icon, group = '\u{e612}', 'DevIconDefault'
  end
  if not icon then
    return ''
  end
  return hl.icon(group) .. icon
end

function M.file(buf)
  local f = files[buf]
  if f then
    return f
  end
  local name = api.nvim_buf_get_name(buf)
  f = {
    icon = get_icon(buf),
    path = name == '' and '' or esc(vim.fn.fnamemodify(name, ':~:.')),
    name = name == '' and '[No Name]' or esc(vim.fn.fnamemodify(name, ':t')),
  }
  files[buf] = f
  return f
end

function M.invalidate_file(buf)
  if buf then
    files[buf] = nil
  else
    files = {}
  end
end

-- git -----------------------------------------------------------------------

local function read_head(gitdir)
  local fd = io.open(gitdir .. '/HEAD', 'r')
  if not fd then
    return ''
  end
  local line = fd:read('*l') or ''
  fd:close()
  local ref = line:match('^ref: refs/heads/(.+)$')
  if ref then
    return ref
  end
  return line:sub(1, 7)
end

--- Branch without gitsigns: read .git/HEAD of the buffer's (or cwd's) repo.
local function fallback_head(buf)
  local name = api.nvim_buf_get_name(buf)
  local start = (name ~= '' and vim.bo[buf].buftype == '') and vim.fs.dirname(name) or vim.fn.getcwd()
  local root = vim.fs.root(start, '.git')
  if not root then
    return ''
  end
  local gitdir = root .. '/.git'
  local h = heads[gitdir]
  if h then
    return h
  end
  local stat = vim.uv.fs_stat(gitdir)
  if stat and stat.type == 'file' then -- worktree / submodule
    local fd = io.open(gitdir, 'r')
    local line = fd and fd:read('*l') or ''
    if fd then
      fd:close()
    end
    local dir = line:match('^gitdir: (.+)$')
    if dir then
      gitdir = dir:sub(1, 1) == '/' and dir or (root .. '/' .. dir)
    end
  end
  h = read_head(gitdir)
  heads[root .. '/.git'] = h
  return h
end

function M.git(buf)
  local g = gits[buf]
  if g then
    return g
  end
  local b = vim.b[buf]
  local head = b.gitsigns_head
  if head == nil or head == '' then
    head = fallback_head(buf)
  end
  local diff = ''
  local st = b.gitsigns_status_dict
  if st then
    local icons = cfg.icons.diff
    local parts = {}
    if (st.added or 0) > 0 then
      parts[#parts + 1] = hl.ref.DiffAdded .. icons.added .. st.added
    end
    if (st.changed or 0) > 0 then
      parts[#parts + 1] = hl.ref.DiffChanged .. icons.changed .. st.changed
    end
    if (st.removed or 0) > 0 then
      parts[#parts + 1] = hl.ref.DiffRemoved .. icons.removed .. st.removed
    end
    diff = table.concat(parts, ' ')
  end
  g = { head = esc(head), diff = diff }
  gits[buf] = g
  return g
end

function M.invalidate_git(buf, heads_too)
  if heads_too then
    heads = {}
  end
  if buf then
    gits[buf] = nil
  else
    gits = {}
  end
end

-- diagnostics -----------------------------------------------------------------

local severities = {
  { vim.diagnostic.severity.ERROR, 'error', 'DiagError' },
  { vim.diagnostic.severity.WARN, 'warn', 'DiagWarn' },
  { vim.diagnostic.severity.INFO, 'info', 'DiagInfo' },
  { vim.diagnostic.severity.HINT, 'hint', 'DiagHint' },
}

function M.diagnostics(buf)
  local d = diags[buf]
  if d then
    return d
  end
  local counts = vim.diagnostic.count(buf)
  local parts = {}
  for _, s in ipairs(severities) do
    local n = counts[s[1]]
    if n and n > 0 then
      parts[#parts + 1] = hl.ref[s[3]] .. cfg.icons.diagnostics[s[2]] .. n
    end
  end
  d = table.concat(parts, ' ')
  diags[buf] = d
  return d
end

function M.invalidate_diagnostics(buf)
  if buf then
    diags[buf] = nil
  else
    diags = {}
  end
end

-- lsp -------------------------------------------------------------------------

local function client_names(filter)
  local names = {}
  for _, client in ipairs(vim.lsp.get_clients(filter)) do
    names[#names + 1] = client.name
  end
  if #names == 0 then
    return ''
  end
  local icon = cfg.icons.lsp
  return esc((icon ~= '' and (icon .. ' ') or '') .. table.concat(names, '|'))
end

function M.lsp(buf)
  if buf then
    local s = lsp_buf[buf]
    if not s then
      s = client_names({ bufnr = buf })
      lsp_buf[buf] = s
    end
    return s
  end
  if not lsp_all then
    lsp_all = client_names()
  end
  return lsp_all
end

function M.invalidate_lsp()
  lsp_all = nil
  lsp_buf = {}
end

function M.forget(buf)
  files[buf], gits[buf], diags[buf], lsp_buf[buf] = nil, nil, nil, nil
end

return M
