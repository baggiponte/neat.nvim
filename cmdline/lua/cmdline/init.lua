-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline popup is left; no notify source, LSP, redirect or
-- message routing. Options can come from `vim.g.cmdline`; the `:Cmdline`
-- command lives in plugin/cmdline.lua and the health check in cmdline.health.
local require = require("cmdline.util.lazy")

local Config = require("cmdline.config")

local M = {}

--- Options from `setup(opts)`, else `vim.g.cmdline` (a table or a function returning one).
---@param opts? cmdline.Opts
---@return cmdline.Opts
local function resolve(opts)
  if opts then
    return opts
  end
  local g = vim.g.cmdline
  if type(g) == "function" then
    g = g()
  end
  return type(g) == "table" and g or {}
end

---@return boolean ok
local function check()
  if vim.fn.has("nvim-0.12") ~= 1 then
    vim.notify("cmdline.nvim needs Neovim >= 0.12", vim.log.levels.ERROR)
    return false
  end
  if not pcall(_G.require, "nui.object") then
    vim.notify("cmdline.nvim needs nui.nvim (MunifTanjim/nui.nvim)", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Configure and start cmdline.nvim. It stays off until this is called (or
--- `vim.g.cmdline` is set before startup), because it takes over the cmdline UI.
---@param opts? cmdline.Opts defaults to `vim.g.cmdline`
function M.setup(opts)
  if not check() then
    return
  end
  opts = resolve(opts)

  local function load()
    require("cmdline.util").try(function()
      require("cmdline.config").setup(opts)
      M.enable()
    end)
  end

  if vim.v.vim_did_enter == 0 then
    -- Schedule loading after VimEnter. Get the UI up and running first.
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("cmdline.setup", { clear = true }),
      once = true,
      callback = load,
    })
  else
    -- Schedule on the event loop
    vim.schedule(load)
  end
end

function M.disable()
  if not Config.is_running() then
    return
  end
  Config._running = false
  require("cmdline.render").disable()
  require("cmdline.ui").disable()
  require("cmdline.ui2").restore()
  require("cmdline.pager").restore()
  require("cmdline.confirm").restore()
end

function M.enable()
  if Config.is_running() then
    return
  end
  if not Config.options.cmdline then
    -- `:Cmdline enable` before setup(): configure from vim.g.cmdline
    if not check() then
      return
    end
    Config.setup(resolve())
  end
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

function M.toggle()
  if Config.is_running() then
    M.disable()
  else
    M.enable()
  end
end

return M
