-- ui.nvim: the UI pieces this config used from snacks.nvim and dressing.nvim.
--
--   require("ui").setup({
--     select = {},                       -- vim.ui.select via a telescope dropdown
--     input = {},                        -- vim.ui.input in a floating window
--     notify = { backend = "snacks" },   -- vim.notify + LSP progress
--     indent = { backend = "snacks" },   -- indent and scope guides
--   })
--
-- Each module is on unless its table sets `enabled = false`. `require("ui.rename")` needs no setup.

local M = {}

local modules = { "select", "input", "notify", "indent" }

---@class ui.Config
---@field select? ui.select.Config
---@field input? table
---@field notify? ui.notify.Config
---@field indent? ui.indent.Config

---@param opts? ui.Config
function M.setup(opts)
  opts = opts or {}
  for _, name in ipairs(modules) do
    local mod_opts = opts[name] or {}
    if mod_opts.enabled ~= false then
      mod_opts = vim.deepcopy(mod_opts)
      mod_opts.enabled = nil
      if name == "input" then
        require("ui.util").config.input = mod_opts
        require("ui.input").enable()
      else
        require("ui." .. name).setup(mod_opts)
      end
    end
  end
end

return M
