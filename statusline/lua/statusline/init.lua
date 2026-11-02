-- statusline.nvim: a small, cached statusline for Neovim >= 0.12.
local api = vim.api

local M = {}

local config = require('statusline.config')
local hl = require('statusline.highlights')
local cache = require('statusline.cache')
local components = require('statusline.components')

local cfg ---@type table
local extensions = {} ---@type table<string, table>

-- render ----------------------------------------------------------------------

local ORDER = { 'a', 'b', 'c', 'x', 'y', 'z' }
local out = {}
local ctx = { win = 0, buf = 0, active = true, cfg = nil }

local function resolve(item)
  if type(item) == 'function' then
    return item
  end
  local fn = components[item]
  if type(fn) ~= 'function' then
    error(('statusline.nvim: unknown component %q'):format(tostring(item)))
  end
  return fn
end

local function compile(sections)
  local compiled = {}
  for _, s in ipairs(ORDER) do
    local list = sections[s]
    if list and #list > 0 then
      local fns = {}
      for i, item in ipairs(list) do
        fns[i] = resolve(item)
      end
      compiled[s] = fns
    end
  end
  return compiled
end

local compiled_active, compiled_inactive

local function section_ref(s, active, fam)
  if not active then
    return (s == 'a' or s == 'z') and hl.ref.Inactive or hl.ref[s:upper()]
  end
  if s == 'a' or s == 'z' then
    return hl.ref[s:upper() .. fam] or '%*'
  end
  return hl.ref[s:upper()]
end

--- Statusline expression, evaluated per window via `%!`.
---@return string
function M.render()
  local win = vim.g.statusline_winid or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(win) then
    return ''
  end
  local buf = api.nvim_win_get_buf(win)
  local active = win == api.nvim_get_current_win()
  ctx.win, ctx.buf, ctx.active = win, buf, active

  local layout = extensions[vim.bo[buf].filetype]
  if not layout then
    layout = active and compiled_active or compiled_inactive
  end

  local fam = 'normal'
  if active then
    local _
    _, fam = components.mode_info()
  end

  -- Like lualine: '%<' goes before the first non-empty section after b, and
  -- '%=' (in section c's colour) before the first non-empty one after c, or
  -- at the end when x, y and z are all empty.
  local n = 0
  local divided, truncated = false, false
  for _, s in ipairs(ORDER) do
    local fns = layout[s]
    if fns then
      local ref = section_ref(s, active, fam)
      local start = n
      for i = 1, #fns do
        local text = fns[i](ctx)
        if text and text ~= '' then
          n = n + 1
          -- a component that opens with its own colour owns its left padding too
          local lead = text:match('^%%#[^#]+#') or ''
          out[n] = ref .. lead .. ' ' .. text:sub(#lead + 1) .. ' '
        end
      end
      if n > start then
        local prefix = ''
        if not divided and s > 'c' then
          divided = true
          prefix = section_ref('c', active, fam) .. '%='
        end
        if not truncated and s > 'b' then
          truncated = true
          prefix = '%<' .. prefix
        end
        out[start + 1] = prefix .. out[start + 1]
      end
    end
  end
  if not divided then
    n = n + 1
    out[n] = section_ref('c', active, fam) .. '%='
  end
  for i = n + 1, #out do
    out[i] = nil
  end
  return table.concat(out, '', 1, n)
end

-- updates ---------------------------------------------------------------------

local pending = false
local function redraw()
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    vim.cmd('redrawstatus!')
  end)
end
M.redraw = redraw

local diag_dirty = false

local function autocmds()
  local group = api.nvim_create_augroup('statusline.nvim', { clear = true })
  local function au(events, fn, opts)
    opts = opts or {}
    opts.group, opts.callback = group, fn
    api.nvim_create_autocmd(events, opts)
  end

  au('ModeChanged', function()
    if diag_dirty and not api.nvim_get_mode().mode:find('^i') then
      diag_dirty = false
      cache.invalidate_diagnostics()
    end
    -- immediate so command-line mode shows up before the first keystroke
    vim.cmd('redrawstatus')
  end)

  au('DiagnosticChanged', function(args)
    if not cfg.diagnostics_update_in_insert and api.nvim_get_mode().mode:find('^i') then
      diag_dirty = true
      return
    end
    cache.invalidate_diagnostics(args.buf)
    redraw()
  end)

  au('User', function(args)
    local buf = args.data and args.data.buffer
    cache.invalidate_git(buf)
    redraw()
  end, { pattern = { 'GitSignsUpdate', 'GitSignsChanged' } })

  au({ 'FocusGained', 'ShellCmdPost', 'TermLeave' }, function()
    cache.invalidate_git(nil, true)
    redraw()
  end)

  au('DirChanged', function()
    cache.invalidate_file()
    cache.invalidate_git(nil, true)
    redraw()
  end)

  au({ 'BufFilePost', 'FileType', 'BufWritePost' }, function(args)
    cache.invalidate_file(args.buf)
    cache.invalidate_git(args.buf)
    redraw()
  end)

  au({ 'LspAttach', 'LspDetach' }, function()
    cache.invalidate_lsp()
    -- on detach the client is still listed until the callback returns
    vim.schedule(function()
      cache.invalidate_lsp()
      redraw()
    end)
  end)

  au({ 'BufWipeout', 'BufDelete' }, function(args)
    cache.forget(args.buf)
  end)

  au('ColorScheme', function()
    hl.apply()
    cache.invalidate_file()
    cache.invalidate_git()
    cache.invalidate_diagnostics()
    redraw()
  end)
end

-- setup -----------------------------------------------------------------------

local STATUSLINE = "%!v:lua.require'statusline'.render()"

--- True once setup() ran (plugin/statusline.lua then leaves it alone).
M.did_setup = false

--- The options setup() got (read by the health check).
---@type statusline.Config
M.user_options = {}

---@param c statusline.Config
local function validate(c)
  vim.validate('palette', c.palette, 'table')
  vim.validate('colors', c.colors, 'table')
  vim.validate('colors.modes', c.colors.modes, 'table')
  vim.validate('icons', c.icons, 'table')
  vim.validate('lsp_scope', c.lsp_scope, function(v)
    return v == 'all' or v == 'buffer'
  end, false, "'all' or 'buffer'")
  vim.validate('diagnostics_update_in_insert', c.diagnostics_update_in_insert, 'boolean')
  vim.validate('sections', c.sections, 'table')
  vim.validate('inactive_sections', c.inactive_sections, 'table')
  vim.validate('extensions', c.extensions, 'table')
end

--- Configure and draw the statusline. plugin/statusline.lua calls it at
--- startup with `vim.g.statusline` unless init.lua already did.
---@param opts? statusline.Config defaults to `vim.g.statusline`
function M.setup(opts)
  if opts == nil then
    opts = vim.g.statusline
    if type(opts) == 'function' then
      opts = opts()
    end
  end
  opts = opts or {}
  vim.validate('opts', opts, 'table')
  cfg = vim.tbl_deep_extend('force', vim.deepcopy(config.defaults), opts)
  -- section lists replace rather than merge index-wise
  if opts.sections then
    cfg.sections = vim.tbl_extend('force', config.defaults.sections, opts.sections)
  end
  if opts.inactive_sections then
    cfg.inactive_sections = opts.inactive_sections
  end
  validate(cfg)
  M.did_setup = true
  M.user_options = opts
  ctx.cfg = cfg
  M.config = cfg

  hl.setup(cfg)
  cache.setup(cfg)

  compiled_active = compile(cfg.sections)
  compiled_inactive = compile(cfg.inactive_sections)
  extensions = {}
  local ext = vim.tbl_extend('force', require('statusline.extensions').builtin, opts.extensions or {})
  for ft, sections in pairs(ext) do
    if sections then
      extensions[ft] = compile(sections)
    end
  end

  M.enable()
end

--- Whether the statusline is drawn by statusline.nvim right now.
---@return boolean
function M.is_enabled()
  return vim.go.statusline == STATUSLINE
end

local saved ---@type {statusline: string, qf_disable_statusline: any}?

function M.enable()
  if not M.did_setup then
    return M.setup()
  end
  if not M.is_enabled() then
    saved = { statusline = vim.go.statusline, qf_disable_statusline = vim.g.qf_disable_statusline }
  end
  -- the quickfix ftplugin would set its own window-local statusline; we draw the qf extension
  vim.g.qf_disable_statusline = true
  autocmds()

  vim.go.statusline = STATUSLINE
  -- drop window-local statuslines set before we loaded (e.g. by ftplugins)
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.wo[win].statusline ~= '' then
      api.nvim_set_option_value('statusline', '', { scope = 'local', win = win })
    end
  end
  redraw()
end

--- Hand the statusline back to what was there before enable().
function M.disable()
  if not M.is_enabled() then
    return
  end
  pcall(api.nvim_del_augroup_by_name, 'statusline.nvim')
  vim.go.statusline = saved and saved.statusline or ''
  vim.g.qf_disable_statusline = saved and saved.qf_disable_statusline or nil
  redraw()
end

--- Drop every cache and redraw.
function M.refresh()
  if not M.did_setup then
    return
  end
  hl.apply(true)
  cache.invalidate_file()
  cache.invalidate_git(nil, true)
  cache.invalidate_diagnostics()
  cache.invalidate_lsp()
  redraw()
end

return M
