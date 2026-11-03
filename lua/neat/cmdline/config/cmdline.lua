-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: formats are looked up directly by cmdline.render instead of
-- being turned into routes.
local lazy = require("neat.cmdline.util.lazy")

---@module "neat.cmdline.config"
local Config = lazy("neat.cmdline.config")
---@module "neat.cmdline.config.highlights"
local Highlights = lazy("neat.cmdline.config.highlights")

local M = {}

--- Fill in each cmdline format (name, highlights, view options) and drop
--- the ones set to false.
function M.setup()
  local formats = Config.options.cmdline.format
  for name, format in pairs(formats) do
    if format == false then
      formats[name] = nil
    else
      local kind = format.kind or name
      local kind_cc = kind:sub(1, 1):upper() .. kind:sub(2)

      local hl_group_icon = "CmdlineIcon" .. kind_cc
      Highlights.add(hl_group_icon, "NoiceCmdlineIcon")

      local hl_group_border = "CmdlinePopupBorder" .. kind_cc
      Highlights.add(hl_group_border, "NoiceCmdlinePopupBorder")

      local hl_group_title = "CmdlinePopupTitle" .. kind_cc
      Highlights.add(hl_group_title, "Noice" .. hl_group_border)

      format = vim.tbl_deep_extend("force", {
        name = name,
        conceal = format.conceal ~= false,
        kind = name,
        icon_hl_group = "Noice" .. hl_group_icon,
        view = Config.options.cmdline.view,
        lang = format.lang,
        opts = {
          ---@diagnostic disable-next-line: undefined-field
          border = {
            text = {
              top = format.title or (" " .. kind_cc .. " "),
            },
          },
          win_options = {
            winhighlight = {
              FloatBorder = "Noice" .. hl_group_border,
              FloatTitle = "Noice" .. hl_group_title,
            },
          },
        },
      }, { opts = vim.deepcopy(Config.options.cmdline.opts) }, format)
      formats[name] = format
    end
  end
end

return M
