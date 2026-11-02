-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline popup is left; no health checks, notify source,
-- LSP, commands, redirect or message routing.
local require = require("cmdline.util.lazy")

local Config = require("cmdline.config")

local M = {}

---@param opts? CmdlineConfig
function M.setup(opts)
  if vim.fn.has("nvim-0.11") ~= 1 then
    return vim.notify("cmdline.nvim needs Neovim >= 0.11", vim.log.levels.ERROR)
  end
  if not pcall(_G.require, "nui.object") then
    return vim.notify("cmdline.nvim needs nui.nvim (MunifTanjim/nui.nvim)", vim.log.levels.ERROR)
  end

  local function load()
    require("cmdline.util").try(function()
      require("cmdline.config").setup(opts)
      M.enable()
    end)
  end

  if vim.v.vim_did_enter == 0 then
    -- Schedule loading after VimEnter. Get the UI up and running first.
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = load,
    })
  else
    -- Schedule on the event loop
    vim.schedule(load)
  end
end

function M.disable()
  Config._running = false
  require("cmdline.render").disable()
  require("cmdline.ui").disable()
  require("cmdline.ui2").restore()
  require("cmdline.pager").restore()
  require("cmdline.confirm").restore()
end

function M.enable()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("cmdline.vim_leave_pre", { clear = true }),
    callback = function()
      if Config.is_running() then
        pcall(M.disable)
      end
    end,
  })
  Config._running = true
  require("cmdline.ui2").setup(Config.options.ui2)
  require("cmdline.pager").setup(Config.options.ui2.pager)
  require("cmdline.confirm").setup(Config.options.confirm)
  require("cmdline.ui").enable()
  require("cmdline.render").enable()
end

return M
