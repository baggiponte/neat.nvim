-- Portions adapted from lualine.nvim (MIT) by hoob3rt and contributors; modified.
-- Source: components/diagnostics (severity order) at nvim-lualine/lualine.nvim 221ce6b2d999187044529f49da6554a92f740a96.
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

local icons ---@type neat.statusline.IconProvider?
--- nil: not loaded yet; true/false: whether `icons.load()` found its plugin.
local icons_loaded ---@type boolean?
local git ---@type neat.statusline.GitProvider?

---@param config statusline.Config
function M.setup(config)
  cfg = config
  local providers = require('neat.statusline.providers')
  local new_icons = providers.icons(config.providers.icons)
  if new_icons ~= icons then
    icons, icons_loaded = new_icons, nil
  end
  git = providers.git(config.providers.git)
  files, gits = {}, {}
end

--- The active git provider (its `events` invalidate the git cache).
---@return neat.statusline.GitProvider?
function M.git_provider()
  return git
end

-- file ----------------------------------------------------------------------

--- The icon provider once its plugin is loaded, else nil. The statusline is
--- drawn under textlock, so loading waits for the next tick; then the file
--- caches are dropped and the statusline redrawn with icons.
---@return neat.statusline.IconProvider?
local function loaded_icons()
  if not icons or icons_loaded == false then
    return nil
  end
  if icons_loaded then
    return icons
  end
  icons_loaded = false -- until load() says otherwise; also stops a second schedule
  local provider = icons
  vim.schedule(function()
    if icons ~= provider then
      return -- setup() ran again with another provider
    end
    icons_loaded = provider.load()
    if icons_loaded then
      M.invalidate_file()
      require('neat.statusline').redraw()
    end
  end)
  return nil
end

---@param buf integer
---@return string statusline text: highlight and icon, or ''
local function get_icon(buf)
  local ft = vim.bo[buf].filetype
  if ft == '' then
    return ''
  end
  local provider = loaded_icons()
  if not provider then
    return ''
  end
  local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ':t')
  local icon, group = provider.get(name, ft)
  if not icon or icon == '' then
    return ''
  end
  return (group and hl.icon(group) or '') .. esc(icon)
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

---@param buf integer
---@return {head: string, diff: string} statusline text for `branch` and `diff`
function M.git(buf)
  local g = gits[buf]
  if g then
    return g
  end
  local st = git and git.status(buf) or {}
  local head = st.head
  if head == nil or head == '' then
    head = fallback_head(buf)
  end
  local symbols = cfg.icons.diff
  local parts = {}
  if (st.added or 0) > 0 then
    parts[#parts + 1] = hl.ref.DiffAdded .. symbols.added .. st.added
  end
  if (st.changed or 0) > 0 then
    parts[#parts + 1] = hl.ref.DiffChanged .. symbols.changed .. st.changed
  end
  if (st.removed or 0) > 0 then
    parts[#parts + 1] = hl.ref.DiffRemoved .. symbols.removed .. st.removed
  end
  g = { head = esc(head), diff = table.concat(parts, ' ') }
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
