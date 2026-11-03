-- Adapted from snacks.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Source: lua/snacks/win.lua at folke/snacks.nvim v2.22.0 (5eac729fa290248acfe10916d92a5ed5e5c0f9ed).
-- Changes: kept only the floating-window path used by ui.input and ui.notify. Removed splits,
-- backdrops, the keymap help window, scrolling helpers, `file`, `set_title` and `set_buf`.
-- Highlight groups and filetypes renamed from `Snacks*`/`snacks_*` to `Ui*`/`ui_*`.

local util = require("neat.util")

--- Options for a floating window (snacks.nvim's `win` options, floats only).
--- Styles registered with neat.util.style() fill in what is not given.
---@class neat.win.Config: vim.api.keyset.win_config
---@field style? string a registered style to start from ("float", "minimal", "input", ...)
---@field show? boolean open the window right away (default true)
---@field enter? boolean focus the window when it opens
---@field minimal? boolean apply the "minimal" style
---@field fixbuf? boolean keep other buffers out of the window
---@field position? "float"
---@field width? number|fun(self: neat.win): number columns, or a fraction of the editor when < 1
---@field height? number|fun(self: neat.win): number lines, or a fraction of the editor when < 1
---@field min_width? number
---@field max_width? number
---@field min_height? number
---@field max_height? number
---@field buf? integer show this buffer instead of a scratch one
---@field ft? string filetype of the scratch buffer
---@field scratch_ft? string
---@field text? string|string[]|fun(): (string|string[]) initial buffer text
---@field wo? vim.wo|{} window-local options
---@field bo? vim.bo|{} buffer-local options
---@field b? table<string, any> buffer variables
---@field w? table<string, any> window variables
---@field keys? table<string, false|string|string[]|table> key -> action name(s) or a keymap spec
---@field actions? table<string, neat.win.Action|fun(self: neat.win): any> named actions for `keys`
---@field resize? boolean
---@field on_buf? fun(self: neat.win)
---@field on_win? fun(self: neat.win)
---@field on_close? fun(self: neat.win)

---@class neat.win.Action
---@field action fun(self: neat.win): any
---@field desc? string

---@class neat.win
---@field id number
---@field buf? number
---@field scratch_buf? number
---@field win? number
---@field opts neat.win.Config
---@field augroup? number
---@field keys table[]
---@field events table[]
---@field meta table<string, any>
---@field closed? boolean
local M = setmetatable({}, {
  __call = function(t, ...)
    return t.new(...)
  end,
})
M.__index = M

local defaults = {
  show = true,
  fixbuf = true,
  relative = "editor",
  position = "float",
  minimal = true,
  wo = {
    winhighlight = "Normal:UiNormal,NormalNC:UiNormalNC,WinBar:UiWinBar,WinBarNC:UiWinBarNC",
  },
  bo = {},
  keys = {
    q = "close",
  },
}

util.style("float", {
  position = "float",
  height = 0.9,
  width = 0.9,
  zindex = 50,
})

util.style("minimal", {
  wo = {
    cursorcolumn = false,
    cursorline = false,
    cursorlineopt = "both",
    colorcolumn = "",
    fillchars = "eob: ,lastline:…",
    list = false,
    listchars = "extends:…,tab:  ",
    number = false,
    relativenumber = false,
    signcolumn = "no",
    spell = false,
    winbar = "",
    statuscolumn = "",
    wrap = false,
    sidescrolloff = 0,
  },
})

local win_opts = {
  "anchor",
  "border",
  "bufpos",
  "col",
  "external",
  "fixed",
  "focusable",
  "footer",
  "footer_pos",
  "height",
  "hide",
  "noautocmd",
  "relative",
  "row",
  "style",
  "title",
  "title_pos",
  "width",
  "win",
  "zindex",
}

---@type table<string, string[]>
local borders = {
  left = { "", "", "", "", "", "", "", "│" },
  right = { "", "", "", "│", "", "", "", "" },
  top = { "", "─", "", "", "", "", "", "" },
  bottom = { "", "", "", "", "", "─", "", "" },
  hpad = { "", "", "", " ", "", "", "", " " },
  vpad = { "", " ", "", "", "", " ", "", "" },
}

util.set_hl({
  Normal = "NormalFloat",
  NormalNC = "NormalFloat",
  WinBar = "Title",
  WinBarNC = "UiWinBar",
}, { prefix = "Ui", default = true })

local id = 0
local event_stack = {} ---@type string[]

---@param ... table|string|nil
---@return table
function M.resolve(...)
  local done = {} ---@type table<string, boolean>
  local merge = {} ---@type table[]
  local stack = {}
  for i = 1, select("#", ...) do
    local next = select(i, ...)
    if next then
      table.insert(stack, next)
    end
  end
  while #stack > 0 do
    local next = table.remove(stack)
    next = type(next) == "string" and util.styles()[next] or next
    if next and type(next) == "table" then
      table.insert(merge, 1, next)
      if next.style and not done[next.style] then
        done[next.style] = true
        table.insert(stack, next.style)
      end
    end
  end
  local ret = #merge == 0 and {} or #merge == 1 and merge[1] or vim.tbl_deep_extend("force", {}, unpack(merge))
  ret.style = nil
  return ret
end

---@param opts? table
---@return neat.win
function M.new(opts)
  local self = setmetatable({}, M)
  id = id + 1
  self.id = id
  self.meta = {}
  opts = M.resolve(util.get("win", defaults), opts)
  if opts.minimal then
    opts = M.resolve("minimal", opts)
  end
  opts = M.resolve("float", opts)
  if opts.relative == "win" then
    opts.win = opts.win or vim.api.nvim_get_current_win()
  end

  self.keys = {}
  self.events = {}
  local done = {} ---@type table<string, table>
  for key, spec in pairs(opts.keys) do
    if spec then
      if type(spec) == "string" then
        spec = { key, spec, desc = spec }
      elseif type(spec) == "function" then
        spec = { key, spec }
      elseif type(spec) == "table" and spec[1] and not spec[2] then
        spec = vim.deepcopy(spec) -- deepcopy just in case
        spec[1], spec[2] = key, spec[1]
      end
      local lhs = util.normkey(spec[1] or "")
      local mode = type(spec.mode) == "table" and spec.mode or { spec.mode or "n" }
      mode = #mode == 0 and { "n" } or mode
      for _, m in ipairs(mode) do
        local k = m .. ":" .. lhs
        if done[k] then
          util.notify(("Duplicate key mapping for `%s` mode=%s"):format(lhs, m), vim.log.levels.WARN)
        end
        done[k] = spec
      end
      table.insert(self.keys, spec)
    end
  end

  self:on("WinClosed", self.on_close, { win = true })

  -- update window size when resizing
  self:on("VimResized", self.on_resize)

  self.opts = opts
  if opts.show ~= false then
    self:show()
  end
  return self
end

function M:on_resize()
  if self.opts.resize ~= false then
    self:update()
  end
end

---@param actions string|string[]
---@return any what the action returned
function M:execute(actions)
  return self:action(actions)()
end

---@param actions string|string[]
---@return (fun(): boolean|string?) action, string? desc
function M:action(actions)
  actions = type(actions) == "string" and { actions } or actions
  ---@cast actions string[]
  local desc = {} ---@type string[]
  for a, name in ipairs(actions) do
    desc[a] = name:gsub("_", " ")
    if self.opts.actions and self.opts.actions[name] then
      local action = self.opts.actions[name]
      desc[a] = type(action) == "table" and action.desc and action.desc or desc[a]
    end
  end
  return function()
    for _, name in ipairs(actions) do
      if self.opts.actions and self.opts.actions[name] then
        local a = self.opts.actions[name]
        local fn = type(a) == "function" and a or a.action
        local ret = fn(self)
        if ret then
          return type(ret) == "string" and ret or nil
        end
      elseif self[name] then
        self[name](self)
        return
      else
        return name
      end
    end
  end,
    table.concat(desc, ", ")
end

---@param event string|string[]
---@param cb fun(self: neat.win, ev:vim.api.keyset.create_autocmd.callback_args):boolean?
---@param opts? table
function M:on(event, cb, opts)
  opts = opts or {}
  opts.callback = cb
  table.insert(self.events, vim.tbl_extend("keep", { event = event }, opts))
  if self:valid() then
    self:_on(event, opts)
  end
end

---@param event string|string[]
---@param opts table
function M:_on(event, opts)
  local event_opts = {} ---@type vim.api.keyset.create_autocmd
  local skip = { "buf", "win", "event" }
  for k, v in pairs(opts) do
    if not vim.tbl_contains(skip, k) then
      event_opts[k] = v
    end
  end
  event_opts.group = event_opts.group or self.augroup
  ---@param ev vim.api.keyset.create_autocmd.callback_args
  ---@return any
  event_opts.callback = function(ev)
    table.insert(event_stack, ev.event)
    local ok, err = pcall(opts.callback, self, ev)
    table.remove(event_stack)
    return not ok and error(err) or err
  end
  if event_opts.pattern or event_opts.buffer then
    -- don't alter the pattern or buffer
  elseif opts.win then
    event_opts.pattern = self.win .. ""
  elseif opts.buf then
    event_opts.buffer = self.buf
  end
  vim.api.nvim_create_autocmd(event, event_opts)
end

function M:focus()
  if self:valid() then
    vim.api.nvim_set_current_win(self.win)
  end
end

function M:redraw()
  vim.api.nvim__redraw({ win = self.win, valid = false, flush = true, cursor = false })
end

function M:destroy()
  self:close()
  self.events = {}
  self.keys = {}
  self.meta = {}
end

---@param opts? { buf: boolean }
function M:close(opts)
  opts = opts or {}
  local wipe = opts.buf ~= false and self.buf == self.scratch_buf

  local win = self.win
  local buf = wipe and self.buf
  local scratch_buf = self.scratch_buf ~= self.buf and self.scratch_buf or nil
  self:on_close()

  self.win = nil
  self.scratch_buf = nil
  if buf then
    self.buf = nil
  end

  local close = function()
    if win and vim.api.nvim_win_is_valid(win) then
      local ok, err = pcall(vim.api.nvim_win_close, win, true)
      if not ok and (err and err:find("E444")) then
        -- last window, so creat a split and close it again
        vim.cmd("silent! vsplit")
        pcall(vim.api.nvim_win_close, win, true)
      elseif not ok then
        error(err)
      end
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
      vim.api.nvim_buf_delete(scratch_buf, { force = true })
    end
    if self.augroup then
      pcall(vim.api.nvim_del_augroup_by_id, self.augroup)
      self.augroup = nil
    end
  end
  local retries = 0
  local try_close ---@type fun()
  try_close = function()
    local ok, err = pcall(close)
    if ok or not err then
      return
    end

    -- command window is open
    if err:find("E11") then
      vim.defer_fn(try_close, 200)
      return
    end

    -- text lock
    if err:find("E565") and retries < 20 then
      retries = retries + 1
      vim.defer_fn(try_close, 50)
      return
    end

    if not ok then
      util.notify("Failed to close window: " .. err, vim.log.levels.ERROR)
    end
  end
  -- HACK: WinClosed is not recursive, so we need to schedule it
  -- if we're in a WinClosed event
  if vim.tbl_contains(event_stack, "WinClosed") or not pcall(close) then
    vim.schedule(try_close)
  end
end

function M:hide()
  self:close({ buf = false })
  return self
end

function M:toggle()
  if self:valid() then
    self:hide()
  else
    self:show()
  end
  return self
end

---@private
function M:open_buf()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    -- keep existing buffer
    self.buf = self.buf
  elseif self.scratch_buf and vim.api.nvim_buf_is_valid(self.scratch_buf) then
    -- keep existing scratch buffer
    self.buf = self.scratch_buf
  elseif self.opts.buf then
    self.buf = self.opts.buf
  else
    self:scratch()
  end
  return self.buf
end

function M:scratch()
  if self.buf == self.scratch_buf and self:buf_valid() then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].swapfile = false
  self.scratch_buf = self.buf
  local text = self.opts.text
  if type(text) == "function" then
    text = text()
  end
  if type(text) == "string" then
    text = vim.split(text, "\n")
  end
  ---@cast text string[]?
  if text then
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, text)
  end
  if not self.opts.bo.filetype then
    vim.bo[self.buf].filetype = self.opts.scratch_ft or "ui_win"
    vim.bo[self.buf].syntax = ""
  end
  if self:win_valid() then
    vim.api.nvim_win_set_buf(self.win, self.buf)
  end
end

---@private
function M:open_win()
  local enter = self.opts.enter == nil or self.opts.enter or false
  if self.opts.focusable == false then
    enter = false
  end
  self.win = vim.api.nvim_open_win(self.buf, enter, self:win_opts())
  vim.w[self.win].ui_win = { id = self.id, position = "float", relative = self.opts.relative }
end

function M:update()
  if self:valid() then
    util.bo(self.buf, self.opts.bo)
    util.wo(self.win, self.opts.wo)
    if self:is_floating() then
      local opts = self:win_opts()
      opts.noautocmd = nil
      vim.api.nvim_win_set_config(self.win, opts)
    end
  end
end

function M:on_current_tab()
  return self:win_valid() and vim.api.nvim_get_current_tabpage() == vim.api.nvim_win_get_tabpage(self.win)
end

function M:show()
  if self:valid() then
    self:update()
    return self
  end
  self.augroup = vim.api.nvim_create_augroup("ui_win_" .. self.id, { clear = true })

  self:open_buf()

  -- buffer local variables
  for k, v in pairs(self.opts.b or {}) do
    vim.b[self.buf][k] = v
  end

  -- OPTIM: prevent treesitter or syntax highlighting to attach on FileType if it's not already enabled
  local optim_hl = not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == ""
  vim.b[self.buf].ts_highlight = optim_hl or vim.b[self.buf].ts_highlight
  util.bo(self.buf, self.opts.bo)
  vim.b[self.buf].ts_highlight = not optim_hl and vim.b[self.buf].ts_highlight or nil

  if self.opts.on_buf then
    self.opts.on_buf(self)
  end

  self:open_win()
  self.closed = false
  -- window local variables
  for k, v in pairs(self.opts.w or {}) do
    vim.w[self.win][k] = v
  end
  if util.is_transparent() then
    self.opts.wo.winblend = 0
  end
  util.wo(self.win, self.opts.wo)
  if self.opts.on_win then
    self.opts.on_win(self)
  end

  -- syntax highlighting
  local ft = self.opts.ft or vim.bo[self.buf].filetype
  if ft and not ft:find("^ui_") and not vim.b[self.buf].ts_highlight and vim.bo[self.buf].syntax == "" then
    local lang = vim.treesitter.language.get_lang(ft)
    if not (lang and pcall(vim.treesitter.start, self.buf, lang)) then
      vim.bo[self.buf].syntax = ft
    end
  end

  for _, event in ipairs(self.events) do
    self:_on(event.event, event)
  end

  -- swap buffers when opening a new buffer in the same window
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = self.augroup,
    nested = true,
    callback = function()
      return self:fixbuf()
    end,
  })

  self:map()

  return self
end

function M:fixbuf()
  -- window closes, so delete the autocmd
  if not self:win_valid() then
    return true
  end

  if not self:on_current_tab() then
    return
  end

  local buf = vim.api.nvim_win_get_buf(self.win)

  -- same buffer
  if buf == self.buf then
    return
  end

  -- don't swap if fixbuf is disabled
  if self.opts.fixbuf == false then
    self.buf = buf
    util.wo(self.win, self.opts.wo)
    return
  end

  -- another buffer was opened in this window
  -- find another window to swap with
  local main ---@type number?
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local win_buf = vim.api.nvim_win_get_buf(win)
    local is_float = vim.api.nvim_win_get_config(win).zindex ~= nil
    if win ~= self.win and not is_float then
      if vim.bo[win_buf].buftype == "" then
        main = win
        break
      end
    end
  end

  if main then
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.api.nvim_win_set_buf(main, buf)
    vim.api.nvim_set_current_win(main)
    vim.cmd.stopinsert()
  else
    -- no main window found, so close this window
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.schedule(function()
      vim.cmd.stopinsert()
      vim.cmd("sbuffer " .. buf)
      if self.win and vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
      end
    end)
  end
end

function M:map()
  if not self:buf_valid() then
    return
  end
  for _, spec in pairs(self.keys) do
    local opts = vim.deepcopy(spec)
    opts[1] = nil
    opts[2] = nil
    opts.mode = nil
    opts.buffer = self.buf
    opts.nowait = true
    local rhs = spec[2]
    local is_action = type(rhs) == "string" or type(rhs) == "table"
    if is_action then
      local desc
      rhs, desc = self:action(rhs)
      opts.desc = opts.desc or desc
    else
      rhs = function()
        return spec[2](self)
      end
    end
    spec.desc = spec.desc or opts.desc
    vim.keymap.set(spec.mode or "n", spec[1], rhs, opts)
  end
end

---@private
function M:on_close()
  if self.closed then
    return
  end
  self.closed = true
  if self.opts.on_close then
    self.opts.on_close(self)
  end
  -- Go back to the previous window when closing,
  -- and it's the current window
  if vim.api.nvim_get_current_win() == self.win then
    pcall(vim.cmd.wincmd, "p")
  end
end

function M:add_padding()
  local listchars = vim.split(self.opts.wo.listchars or "", ",")
  listchars = vim.tbl_filter(function(s)
    return not s:find("eol:") and s ~= ""
  end, listchars)
  table.insert(listchars, "eol: ")
  self.opts.wo.listchars = table.concat(listchars, ",")
  self.opts.wo.list = true
  self.opts.wo.statuscolumn = " "
end

function M:is_floating()
  return self:valid() and vim.api.nvim_win_get_config(self.win).zindex ~= nil
end

---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
---@return string[]
function M:lines(from, to)
  return self:buf_valid() and vim.api.nvim_buf_get_lines(self.buf, from and from - 1 or 0, to or -1, false) or {}
end

---@param from? number 1-indexed, inclusive
---@param to? number 1-indexed, inclusive
---@return string
function M:text(from, to)
  return table.concat(self:lines(from, to), "\n")
end

---@return { height: number, width: number }
function M:parent_size()
  return {
    height = self.opts.relative == "win" and vim.api.nvim_win_get_height(self.opts.win) or vim.o.lines,
    width = self.opts.relative == "win" and vim.api.nvim_win_get_width(self.opts.win) or vim.o.columns,
  }
end

---@private
function M:win_opts()
  local opts = {} ---@type vim.api.keyset.win_config
  for _, k in ipairs(win_opts) do
    opts[k] = self.opts[k]
  end

  opts.border = opts.border and (borders[opts.border] or opts.border) or "none"

  if opts.relative == "cursor" then
    self.opts.row = self.opts.row or 0
    self.opts.col = self.opts.col or 0
  end

  local dim = self:dim()
  opts.height, opts.width = dim.height, dim.width
  opts.row, opts.col = dim.row, dim.col

  if opts.title_pos and not opts.title then
    opts.title_pos = nil
  end
  if opts.footer_pos and not opts.footer then
    opts.footer_pos = nil
  end

  if not self:has_border() then
    opts.title, opts.footer = nil, nil
    opts.title_pos, opts.footer_pos = nil, nil
  end
  return opts
end

---@return { height: number, width: number }
function M:size()
  local opts = self:win_opts()
  local height = opts.height
  local width = opts.width
  if self:has_border() then
    height = height + 2
    width = width + 2
  end
  return { height = height, width = width }
end

function M:has_border()
  return self.opts.border and self.opts.border ~= "" and self.opts.border ~= "none"
end

--- Calculate the size of the border
function M:border_size()
  local border = self:has_border() and self.opts.border or { "" }
  border = type(border) == "string" and borders[border] or border
  border = type(border) == "string" and { "x" } or border
  assert(type(border) == "table", "Invalid border type")
  ---@cast border string[]
  while #border < 8 do
    vim.list_extend(border, border)
  end
  -- remove border hl groups
  border = vim.tbl_map(function(b)
    return type(b) == "table" and b[1] or b
  end, border)
  --- 1 if any border char from..to is drawn, else 0.
  ---@param from integer
  ---@param to integer
  ---@return integer
  local function size(from, to)
    for i = from, to do
      if border[i] ~= "" then
        return 1
      end
    end
    return 0
  end
  return {
    top = size(1, 3),
    right = size(3, 5),
    bottom = size(5, 7),
    left = math.max(size(7, 8), size(1, 1)),
  }
end

function M:border_text_width()
  if not self:has_border() then
    return 0
  end
  local ret = 0
  for _, t in ipairs({ "title", "footer" }) do
    local str = self.opts[t] or {}
    str = type(str) == "string" and { str } or str
    ret = math.max(ret, #table.concat(
      vim.tbl_map(function(s)
        return type(s) == "string" and s or s[1]
      end, str),
      ""
    ))
  end
  return ret
end

function M:buf_valid()
  return self.buf and vim.api.nvim_buf_is_valid(self.buf)
end

function M:win_valid()
  return self.win and vim.api.nvim_win_is_valid(self.win)
end

function M:valid()
  return self:win_valid() and self:buf_valid() and vim.api.nvim_win_get_buf(self.win) == self.buf
end

---@param parent? {width: number, height: number}
---@return {width: number, height: number, col: number, row: number, border: boolean}
function M:dim(parent)
  parent = parent or self:parent_size()
  local ret = {
    height = 0,
    width = 0,
    col = 0,
    row = 0,
    border = self:has_border(),
  }

  ---@param s number|(fun(self: neat.win): number)|nil size: 0 is full, < 1 a fraction
  ---@param ps number parent size
  ---@param border_offset number
  ---@return number
  local function size(s, ps, border_offset)
    local n ---@type number
    if type(s) == "function" then
      n = s(self)
    else
      n = s or 0
    end
    if n == 0 then -- full size
      return ps - border_offset
    elseif n < 1 then -- relative size
      return math.floor(ps * n) - border_offset
    end
    return n
  end

  ---@param p number|(fun(self: neat.win): number)|nil position: nil centres, < 0 counts from the end, < 1 a fraction
  ---@param s number size
  ---@param ps number parent size
  ---@param border_from number
  ---@param border_to number
  ---@return number
  local function pos(p, s, ps, border_from, border_to)
    local n ---@type number?
    if type(p) == "function" then
      n = p(self)
    else
      n = p
    end
    if self.opts.relative == "cursor" then
      return n or 0
    end
    if not n then -- center
      return math.floor((ps - s) / 2) - border_from
    end
    if n < 0 then -- negative position
      return ps - s + n - border_from - border_to
    elseif n < 1 and n > 0 then -- relative position
      return math.floor(ps * n) + border_from
    end
    return n
  end

  local border = self:border_size()

  ret.height = size(self.opts.height, parent.height, border.top + border.bottom)
  ret.height = math.max(ret.height, self.opts.min_height or 0, 1)
  ret.height = math.min(ret.height, self.opts.max_height or ret.height, parent.height)
  ret.height = math.max(ret.height, 1)

  ret.width = size(self.opts.width, parent.width, border.left + border.right)
  ret.width = math.max(ret.width, self.opts.min_width or 0, 1)
  ret.width = math.min(ret.width, self.opts.max_width or ret.width, parent.width)
  ret.width = math.max(ret.width, 1)

  ret.row = pos(self.opts.row, ret.height, parent.height, border.top, border.bottom)
  ret.col = pos(self.opts.col, ret.width, parent.width, border.left, border.right)

  return ret
end

return M
