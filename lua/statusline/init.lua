-- statusline.nvim: a small, cached statusline for Neovim >= 0.11.
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

---@param opts? table see statusline.config
function M.setup(opts)
  opts = opts or {}
  cfg = vim.tbl_deep_extend('force', vim.deepcopy(config.defaults), opts)
  -- section lists replace rather than merge index-wise
  if opts.sections then
    cfg.sections = vim.tbl_extend('force', config.defaults.sections, opts.sections)
  end
  if opts.inactive_sections then
    cfg.inactive_sections = opts.inactive_sections
  end
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

  vim.g.qf_disable_statusline = true
  autocmds()

  vim.go.statusline = "%!v:lua.require'statusline'.render()"
  -- drop window-local statuslines set before we loaded (e.g. by ftplugins)
  for _, win in ipairs(api.nvim_list_wins()) do
    if vim.wo[win].statusline ~= '' then
      api.nvim_set_option_value('statusline', '', { scope = 'local', win = win })
    end
  end
  redraw()
end

return M
