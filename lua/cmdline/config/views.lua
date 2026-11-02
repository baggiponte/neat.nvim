-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline views are left.
local require = require("cmdline.util.lazy")

local Config = require("cmdline.config")
local Util = require("cmdline.util")

local M = {}

---@param view string
---@return NoiceViewOptions
function M.get_options(view)
  if not view then
    Util.panic("View is missing?")
  end

  local opts = { view = view }

  local done = {}
  while opts.view and not done[opts.view] do
    done[opts.view] = true

    local view_opts = vim.deepcopy(Config.options.views[opts.view] or {})
    opts = vim.tbl_deep_extend("keep", opts, view_opts)
    opts.view = view_opts.view
  end

  return opts
end

---@class NoiceConfigViews: table<string, NoiceViewOptions>
M.defaults = {
  cmdline = {
    backend = "popup",
    relative = "editor",
    position = {
      row = "100%",
      col = 0,
    },
    size = {
      height = "auto",
      width = "100%",
    },
    border = {
      style = "none",
    },
    win_options = {
      winhighlight = {
        Normal = "NoiceCmdline",
        IncSearch = "",
        CurSearch = "",
        Search = "",
      },
    },
  },
  cmdline_popup = {
    backend = "popup",
    relative = "editor",
    focusable = false,
    enter = false,
    zindex = 200,
    position = {
      row = "50%",
      col = "50%",
    },
    size = {
      min_width = 60,
      width = "auto",
      height = "auto",
    },
    border = {
      style = "rounded",
      padding = { 0, 1 },
    },
    win_options = {
      winhighlight = {
        Normal = "NoiceCmdlinePopup",
        FloatTitle = "NoiceCmdlinePopupTitle",
        FloatBorder = "NoiceCmdlinePopupBorder",
        IncSearch = "",
        CurSearch = "",
        Search = "",
      },
      winbar = "",
      foldenable = false,
      cursorline = false,
    },
  },
  cmdline_input = {
    view = "cmdline_popup",
    border = {
      style = "rounded",
      padding = { 0, 1 },
    },
  },
}

return M
