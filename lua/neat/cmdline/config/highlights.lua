-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline groups are left. neat draws with `Neat*` groups;
-- each links (by default) to the matching `Noice*` group, which links to a
-- builtin group, so colorschemes that theme noice keep theming the popup.
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
  Confirm = "Normal", -- Normal for the confirm float
  ConfirmBorder = "DiagnosticSignInfo", -- Border for the confirm float
  FormatConfirm = "CursorLine", -- confirm buttons
  FormatConfirmDefault = "Visual", -- the default confirm button
  Cursor = "Cursor", -- Fake Cursor
  Scrollbar = "PmenuSbar", -- Normal for scrollbar
  ScrollbarThumb = "PmenuThumb", -- Scrollbar thumb
}

--- Register `Neat<hl_group>` (and its `Noice<hl_group>` fallback) as a default link to `link`.
---@param hl_group string
---@param link string
function M.add(hl_group, link)
  if not M.defaults[hl_group] then
    M.defaults[hl_group] = link
  end
end

---@param hl_group string
---@return vim.api.keyset.get_hl_info
function M.get_link(hl_group)
  local opts = vim.api.nvim_get_hl(0, { name = hl_group, link = false })
  if vim.tbl_isempty(opts) then
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

      vim.api.nvim_set_hl(0, "Noice" .. hl, opts --[[@as vim.api.keyset.highlight]])
    end
    vim.api.nvim_set_hl(0, "Neat" .. hl, { link = "Noice" .. hl, default = true })
  end
end

return M
