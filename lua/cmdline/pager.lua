-- cmdline.nvim: show ui2's pager (`:messages`, `g<`, long output) as a
-- centred floating window instead of a panel at the bottom of the screen.
--
-- ui2 positions its windows in `ui2.msg.set_pos()`, and repositions the pager
-- on WinEnter/WinResized while it is focused. We wrap `set_pos` and listen to
-- the same events, and move the pager to the centre after ui2 is done. ui2
-- keeps owning the pager's buffer, keymaps (`q`) and lifetime. Like the
-- cmdline patch, this relies on ui2's private module layout; if it changes
-- shape, we do nothing.

local M = {}

local MARK = "__cmdline_nvim_set_pos"

---@class CmdlinePagerOptions
---@field width number fraction of the editor width (<= 1) or columns
---@field height number maximum fraction of the editor height (<= 1) or lines
---@field border string|string[]
---@field title string

---@type CmdlinePagerOptions
M.opts = {
  width = 0.8,
  height = 0.6,
  border = "rounded",
  title = " Messages ",
}

---@param value number
---@param total integer
local function size(value, total)
  return value <= 1 and math.floor(total * value) or math.floor(value)
end

---@return table?
local function get_ui2()
  local ui2 = package.loaded["vim._core.ui2"]
  if type(ui2) == "table" and type(ui2.msg) == "table" and type(ui2.wins) == "table" then
    return ui2
  end
end

function M.float()
  local ui2 = get_ui2()
  local win = ui2 and ui2.wins.pager
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.hide or (cfg.relative == "editor" and cfg.border and cfg.title) then
    return
  end

  local lines, columns = vim.o.lines - vim.o.cmdheight, vim.o.columns
  local width = math.max(math.min(size(M.opts.width, columns), columns - 4), 20)
  -- set the width first: the text height depends on it
  pcall(vim.api.nvim_win_set_config, win, { relative = "editor", row = 0, col = 0, width = width, height = 1 })
  local text = vim.api.nvim_win_text_height(win, {}).all
  local height = math.max(math.min(text, size(M.opts.height, lines), lines - 4), 1)

  pcall(vim.api.nvim_win_set_config, win, {
    relative = "editor",
    row = math.floor((lines - height) / 2) - 1,
    col = math.floor((columns - width) / 2) - 1,
    width = width,
    height = height,
    border = M.opts.border,
    title = M.opts.title,
    title_pos = "center",
    hide = false,
  })
  -- same colours as the cmdline popup
  vim.wo[win].winhighlight = "Normal:NoiceCmdlinePopup,FloatBorder:NoiceCmdlinePopupBorder,FloatTitle:NoiceCmdlinePopupTitle"
end

local function patch()
  local ui2 = get_ui2()
  if not ui2 or type(ui2.msg.set_pos) ~= "function" then
    return false
  end
  if ui2.msg[MARK] then
    return true
  end
  local set_pos = ui2.msg.set_pos
  ui2.msg[MARK] = set_pos
  ui2.msg.set_pos = function(...)
    set_pos(...)
    M.float()
  end
  return true
end

---@param opts? CmdlinePagerOptions|false
function M.setup(opts)
  if opts == false then
    return
  end
  M.opts = vim.tbl_deep_extend("force", M.opts, opts or {})
  patch()
  local group = vim.api.nvim_create_augroup("cmdline.pager", { clear = true })
  vim.api.nvim_create_autocmd("UIEnter", {
    group = group,
    callback = function()
      vim.schedule(patch)
    end,
  })
  -- ui2 moves the focused pager back to the bottom on these events
  vim.api.nvim_create_autocmd({ "WinEnter", "WinResized", "VimResized" }, {
    group = group,
    callback = function()
      vim.schedule(M.float)
    end,
  })
end

function M.restore()
  pcall(vim.api.nvim_del_augroup_by_name, "cmdline.pager")
  local ui2 = get_ui2()
  if ui2 and ui2.msg[MARK] then
    ui2.msg.set_pos = ui2.msg[MARK]
    ui2.msg[MARK] = nil
  end
end

return M
