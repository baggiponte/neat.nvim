-- vim.ui.input() in a floating window, with history and completion. Cheap to
-- require: the window (neat.input.window and neat.win, about 1,100 lines)
-- loads on the first vim.ui.input().

local M = {}

---@class neat.input.Config
---@field icon? string
---@field icon_hl? string
---@field icon_pos? "left"|"title"|false
---@field prompt_pos? "title"|"left"|false
---@field win? neat.win.Config window options (`:h neat-input`)
---@field expand? boolean grow the window with the text

--- vim.ui.input() opts merged with neat.input.Config.
---@class neat.input.Opts: neat.input.Config
---@field prompt? string
---@field default? string
---@field completion? string
---@field cancelreturn? any
---@field highlight? function

---@type neat.input.Config
M.defaults = {
  icon = " ",
  icon_hl = "UiInputIcon",
  icon_pos = "left",
  prompt_pos = "title",
  win = { style = "input" },
  expand = true,
}

---@alias neat.input.Input fun(opts?: table, on_confirm: fun(value?: string))

--- vim.ui.input before setup().
local original = vim.ui.input ---@type neat.input.Input

--- vim.ui.input as it was before setup().
---@return neat.input.Input
function M.original()
  return original
end

--- neat's vim.ui.input().
---@param opts? neat.input.Opts
---@param on_confirm fun(value?: string)
function M.input(opts, on_confirm)
  require("neat.input.window").input(opts, on_confirm)
end

---@param c neat.input.Config
local function validate(c)
  vim.validate("input.icon", c.icon, "string", true)
  vim.validate("input.icon_hl", c.icon_hl, "string", true)
  vim.validate("input.icon_pos", c.icon_pos, function(v)
    return v == "left" or v == "title" or v == false
  end, true, '"left", "title" or false')
  vim.validate("input.prompt_pos", c.prompt_pos, function(v)
    return v == "left" or v == "title" or v == false
  end, true, '"left", "title" or false')
  vim.validate("input.win", c.win, "table", true)
  vim.validate("input.expand", c.expand, "boolean", true)
end

--- Set vim.ui.input to neat's.
---@param opts? neat.input.Config
function M.setup(opts)
  opts = opts or {}
  validate(opts)
  require("neat.util").config.input = opts
  M.enable()
end

function M.enable()
  if vim.ui.input ~= M.input then
    original = vim.ui.input
  end
  vim.ui.input = M.input
end

--- Hand vim.ui.input back to what was there before.
function M.disable()
  if vim.ui.input == M.input then
    vim.ui.input = original
  end
end

return M
