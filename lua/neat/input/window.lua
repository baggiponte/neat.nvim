-- Adapted from snacks.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Source: lua/snacks/input.lua at folke/snacks.nvim v2.22.0 (5eac729fa290248acfe10916d92a5ed5e5c0f9ed).
-- Changes: uses the vendored neat.win/neat.util; `Snacks*` highlights/filetype renamed to `UiInput*`/`ui_input`;
-- cancelling now returns `opts.cancelreturn` (nil by default), like the builtin `vim.ui.input`
-- (snacks always returned nil); health check removed; setup and defaults moved to neat.input.
--
-- The input window. Loaded by neat.input on the first vim.ui.input().

local Win = require("neat.win")
local util = require("neat.util")

local M = {}

util.set_hl({
  Icon = "DiagnosticHint",
  Normal = "Normal",
  Border = "DiagnosticInfo",
  Title = "DiagnosticInfo",
  Prompt = "UiInputTitle",
}, { prefix = "UiInput", default = true })

util.style("input", {
  position = "float",
  border = "rounded",
  title_pos = "center",
  height = 1,
  width = 60,
  relative = "editor",
  noautocmd = true,
  row = 2,
  wo = {
    winhighlight = "NormalFloat:UiInputNormal,FloatBorder:UiInputBorder,FloatTitle:UiInputTitle",
    cursorline = false,
  },
  bo = {
    filetype = "ui_input",
    -- keep `prompt`: neo-tree's file completion (fs_actions.lua) detects external inputs via buftype
    buftype = "prompt",
  },
  --- buffer local variables
  b = {
    completion = false, -- disable blink completions in input
  },
  keys = {
    n_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "n", expr = true },
    i_esc = { "<esc>", { "cmp_close", "stopinsert" }, mode = "i", expr = true },
    i_cr = { "<cr>", { "cmp_accept", "confirm" }, mode = "i", expr = true },
    i_tab = { "<tab>", { "cmp_select_next", "cmp" }, mode = "i", expr = true },
    i_ctrl_w = { "<c-w>", "<c-s-w>", mode = "i", expr = true },
    i_up = { "<up>", { "hist_up" }, mode = { "i", "n" } },
    i_down = { "<down>", { "hist_down" }, mode = { "i", "n" } },
    q = "cancel",
  },
})

local ctx = {} ---@type {opts?: table, win?: neat.win}

---@param opts? neat.input.Opts
---@param on_confirm fun(value?: string)
---@return neat.win
function M.input(opts, on_confirm)
  assert(type(on_confirm) == "function", "`on_confirm` must be a function")

  local history = require("neat.input.history").new("input", {
    filter = function(value)
      return value ~= ""
    end,
  })

  local parent_win = vim.api.nvim_get_current_win()
  local mode = vim.fn.mode()

  local function record(force)
    if not ctx.win then
      return
    end
    if not force and not history:is_current() then
      return
    end
    local text = vim.trim(ctx.win:text())
    if text == "" then
      return
    end
    history:record(text)
  end

  local function confirm(value)
    record()
    ctx.win = nil
    ctx.opts = nil
    vim.cmd.stopinsert()
    vim.schedule(function()
      if vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_set_current_win(parent_win)
        if mode == "i" then
          vim.cmd("startinsert")
        end
      end
      on_confirm(value)
    end)
  end

  opts = util.get("input", require("neat.input").defaults, opts) --[[@as neat.input.Opts]]
  local cancelreturn = opts.cancelreturn
  opts.prompt = opts.prompt or "Input"
  opts.prompt = vim.trim(opts.prompt)
  opts.prompt = opts.prompt_pos == "title" and opts.prompt:gsub(":$", "") or opts.prompt

  local title, statuscolumn = {}, {} ---@type table[], string[]
  local function add(text, hl, pos)
    if pos == "title" then
      table.insert(title, { " " .. text, hl })
    else
      table.insert(statuscolumn, "%#" .. hl .. "#" .. text)
    end
  end

  if opts.icon_pos and (opts.icon or "") ~= "" then
    add(opts.icon, "UiInputIcon", opts.icon_pos)
  end
  add(opts.prompt, "UiInputTitle", opts.prompt_pos)

  if next(title) then
    table.insert(title, { " ", "UiInputTitle" })
  end

  local function set(text)
    text = text or ""
    vim.api.nvim_buf_set_lines(ctx.win.buf, 0, -1, false, { text })
    vim.api.nvim_win_set_cursor(ctx.win.win, { 1, #text })
  end

  opts.win = Win.resolve("input", opts.win, {
    enter = true,
    title = next(title) and title or nil,
    bo = {
      modifiable = true,
      completefunc = "v:lua.require'neat.input.window'.complete",
      omnifunc = "v:lua.require'neat.input.window'.complete",
    },
    wo = {
      statuscolumn = next(statuscolumn) and " " .. table.concat(statuscolumn, " ") .. " " or " ",
    },
    actions = {
      cancel = function(self)
        confirm(cancelreturn)
        self:close()
      end,
      stopinsert = function()
        vim.cmd("stopinsert")
      end,
      confirm = function(self)
        confirm(self:text())
        self:close()
      end,
      hist_up = function()
        record()
        set(history:prev())
      end,
      hist_down = function()
        record()
        set(history:next())
      end,
      cmp = function()
        return vim.fn.pumvisible() == 0 and "<c-x><c-u>"
      end,
      cmp_close = function()
        return vim.fn.pumvisible() == 1 and "<c-e>"
      end,
      cmp_accept = function()
        return vim.fn.pumvisible() == 1 and "<c-y>"
      end,
      cmp_select_next = function()
        return vim.fn.pumvisible() == 1 and "<c-n>"
      end,
      cmp_select_prev = function()
        return vim.fn.pumvisible() == 1 and "<c-p>"
      end,
    },
  })

  local parent_zindex = vim.api.nvim_win_get_config(parent_win).zindex
  opts.win.zindex = parent_zindex and parent_zindex + 1 or opts.win.zindex

  local min_width = opts.win.width or 60
  if opts.expand then
    opts.win.width = function(self)
      local w = type(min_width) == "function" and min_width(self) or min_width --[[@as number]]
      return math.max(w, vim.api.nvim_strwidth(self:text()) + 5)
    end
  end

  local win = Win(opts.win)
  ctx = { opts = opts, win = win }
  vim.fn.prompt_setprompt(win.buf, "")
  vim.cmd.startinsert()
  if opts.default then
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, { opts.default })
    vim.api.nvim_win_set_cursor(win.win, { 1, #opts.default })
  end
  vim.fn.prompt_setcallback(win.buf, function(text)
    confirm(text)
    win:close()
  end)
  vim.fn.prompt_setinterrupt(win.buf, function()
    confirm(cancelreturn)
    win:close()
  end)

  win:on({ "TextChangedI", "TextChanged" }, function()
    if not win:valid() then
      return
    end
    vim.bo[win.buf].modified = false
    if opts.expand then
      if vim.api.nvim_win_is_valid(parent_win) then
        vim.api.nvim_win_call(parent_win, function()
          win:update()
        end)
      end
      vim.api.nvim_win_call(win.win, function()
        vim.fn.winrestview({ leftcol = 0 })
      end)
    end
  end, { buf = true })
  return win
end

--- `completefunc` for the input buffer: delegates to `getcompletion(base, opts.completion)`,
--- so `file`, `dir`, `custom,…`/`customlist,…` (e.g. neo-tree's file completion) all work.
---@param findstart number
---@param base string
function M.complete(findstart, base)
  local completion = ctx.opts and ctx.opts.completion
  if findstart == 1 then
    return 0
  end
  if not completion then
    return {}
  end
  local ok, results = pcall(vim.fn.getcompletion, base, completion)
  return ok and results or {}
end

return M
