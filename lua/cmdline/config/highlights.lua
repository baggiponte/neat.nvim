-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline groups are left. Group names keep the `Noice`
-- prefix so colorschemes that theme noice keep theming the popup.
local M = {}

M.defaults = {
  Cmdline = "MsgArea", -- Normal for the classic cmdline area at the bottom"
  CmdlineIcon = "DiagnosticSignInfo", -- Cmdline icon
  CmdlineIconSearch = "DiagnosticSignWarn", -- Cmdline search icon (`/` and `?`)
  CmdlinePrompt = "Title", -- prompt for input()
  CmdlinePopup = "Normal", -- Normal for the cmdline popup
  CmdlinePopupBorder = "DiagnosticSignInfo", -- Cmdline popup border
  CmdlinePopupTitle = "DiagnosticSignInfo", -- Cmdline popup border
  CmdlinePopupBorderSearch = "DiagnosticSignWarn", -- Cmdline popup border for search
  Cursor = "Cursor", -- Fake Cursor
  Scrollbar = "PmenuSbar", -- Normal for scrollbar
  ScrollbarThumb = "PmenuThumb", -- Scrollbar thumb
}

function M.add(hl_group, link)
  if not M.defaults[hl_group] then
    M.defaults[hl_group] = link
  end
end

function M.get_link(hl_group)
  local ok, opts = pcall(vim.api.nvim_get_hl_by_name, hl_group, true)
  if opts then
    opts[vim.type_idx] = nil
  end
  if not ok or vim.tbl_isempty(opts) then
    opts = { link = hl_group }
  end
  opts.default = true
  return opts
end

function M.setup()
  for hl, link in pairs(M.defaults) do
    if link ~= "none" then
      local opts = { link = link, default = true }

      if vim.tbl_contains({ "IncSearch", "Search" }, link) then
        opts = M.get_link(link)
      end

      vim.api.nvim_set_hl(0, "Noice" .. hl, opts)
    end
  end
end

return M
