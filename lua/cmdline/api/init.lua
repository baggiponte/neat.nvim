-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: removed the statusline API.
local require = require("cmdline.util.lazy")

local Cmdline = require("cmdline.ui.cmdline")

local M = {}

---@return CmdlinePosition?
function M.get_cmdline_position()
  return Cmdline.position and vim.deepcopy(Cmdline.position)
end

return M
