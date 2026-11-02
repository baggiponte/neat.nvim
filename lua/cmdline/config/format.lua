-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the `default` format and the `message`/`text` formatters are
-- left; the cmdline message never carries a level, title, date or progress.
local M = {}

---@type table<string, NoiceFormat>
M.builtin = {
  default = { "{message}" },
}

---@class NoiceFormatOptions
M.defaults = {
  ---@class NoiceFormatOptions.text
  text = {
    text = nil,
    hl_group = nil,
  },
  ---@class NoiceFormatOptions.message
  message = {
    hl_group = nil, -- if set, then the hl_group will be used instead of the message highlights
  },
}

return M
