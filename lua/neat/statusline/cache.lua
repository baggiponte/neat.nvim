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
local devicons_scheduled = false

--- nvim-web-devicons if it is loaded. The statusline is drawn under textlock,
--- so it must not load anything itself: a plugin manager's require hook may
--- :packadd or wait on async work there and fail with E565. The first time the
--- icons are missing, require them on the next tick instead, then drop the
--- file caches and redraw.
local function get_devicons()
  if devicons ~= nil then
    return devicons
  end
  local mod = package.loaded['nvim-web-devicons']
  if mod then
    devicons = mod
    return mod
  end
  if not devicons_scheduled then
    devicons_scheduled = true
    vim.schedule(function()
      local ok, loaded = pcall(require, 'nvim-web-devicons')
      devicons = ok and loaded or false
      if devicons then
        M.invalidate_file()
        require('neat.statusline').redraw()
      end
    end)
  end
  return false
end

-- Same lookup as lualine's filetype component: by file name, then by
-- filetype, then a generic icon; nothing when the buffer has no filetype.
local function get_icon(buf)
  local ft = vim.bo[buf].filetype
  if ft == '' then
    return ''
  end
  local icons = get_devicons()
  if not icons then
    return ''
  end
  local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':t')
  local icon, group = icons.get_icon(name)
  if icon == nil then
    icon, group = icons.get_icon_by_filetype(ft)
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

-- lsp progress ----------------------------------------------------------------

local SPINNER = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local MAX_WIDTH = 40 -- per client
local progress = {} ---@type table<integer, table<integer|string, {title?: string, message?: string, percentage?: integer}>>
local progress_str ---@type string?
local frame = 0

--- Track `$/progress` from an LspProgress event (`ev.data`).
---@param data {client_id: integer, params: lsp.ProgressParams}
function M.update_progress(data)
  local value = data and data.params and data.params.value
  if type(value) ~= 'table' then
    return
  end
  local token = data.params.token
  local items = progress[data.client_id] or {}
  if value.kind == 'end' then
    items[token] = nil
  else
    local item = items[token] or {}
    item.title = value.title or item.title
    item.message = value.message
    item.percentage = value.percentage or item.percentage
    items[token] = item
  end
  progress[data.client_id] = next(items) and items or nil
  frame = frame % #SPINNER + 1
  progress_str = nil
end

---@param client_id? integer nil clears every client
function M.clear_progress(client_id)
  if client_id then
    progress[client_id] = nil
  else
    progress = {}
  end
  progress_str = nil
end

--- Spinner plus one line per client with work in progress, or ''.
function M.lsp_progress()
  if progress_str then
    return progress_str
  end
  local parts = {}
  for _, items in pairs(progress) do
    local _, item = next(items)
    if item then
      local s = item.title or ''
      if item.message and item.message ~= '' then
        s = s .. (s ~= '' and ' ' or '') .. item.message
      end
      if vim.fn.strchars(s) > MAX_WIDTH then
        s = vim.fn.strcharpart(s, 0, MAX_WIDTH - 1) .. '…'
      end
      if item.percentage then
        s = ('%s %d%%'):format(s, item.percentage)
      end
      parts[#parts + 1] = s
    end
  end
  progress_str = #parts == 0 and '' or esc(SPINNER[frame] .. ' ' .. table.concat(parts, ' | '))
  return progress_str
end

function M.forget(buf)
  files[buf], gits[buf], diags[buf], lsp_buf[buf] = nil, nil, nil, nil
end

return M
