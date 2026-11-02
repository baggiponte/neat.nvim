-- Indent guides with two interchangeable engines:
--
-- * "snacks": the vendored snacks indent + scope guides (ui.indent.snacks)
-- * "blink": saghen/blink.indent, which must be installed separately

local M = {}

---@class ui.indent.Config
---@field enabled? boolean
---@field backend? "snacks"|"blink"
---@field snacks? table options for ui.indent.snacks (same shape as snacks.nvim's `indent`)
---@field blink? table options passed to `require("blink.indent").setup()`
local defaults = {
  backend = "snacks",
  snacks = {},
  blink = {},
}

---@param opts? ui.indent.Config
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", defaults, opts or {})
  if config.backend == "snacks" then
    require("ui.util").config.indent = config.snacks
    require("ui.indent.snacks").enable()
  elseif config.backend == "blink" then
    require("blink.indent").setup(config.blink)
  else
    error("ui.indent: unknown backend " .. tostring(config.backend))
  end
end

return M
