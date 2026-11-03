-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline popup is left, plus a small kind-based message
-- router on top of ui2 (cmdline.messages); no notify source, LSP or redirect.
-- Started by require("neat").setup({ cmdline = { enabled = true } });
-- `:Neat cmdline` lives in plugin/neat.lua and the health check in neat.cmdline.checks.
local require = require("neat.cmdline.util.lazy")

local Config = require("neat.cmdline.config")

local M = {}

--- Options from `setup(opts)`, else the `cmdline` table given to neat.setup().
---@param opts? cmdline.Opts
---@return cmdline.Opts
local function resolve(opts)
  if opts then
    return opts
  end
  local o = vim.deepcopy(_G.require("neat").options.cmdline or {})
  o.enabled = nil
  return o
end

---@return boolean ok
local function check()
  if vim.fn.has("nvim-0.12") ~= 1 then
    vim.notify("neat.nvim cmdline needs Neovim >= 0.12", vim.log.levels.ERROR)
    return false
  end
  if not pcall(_G.require, "nui.object") then
    vim.notify("neat.nvim cmdline needs nui.nvim (MunifTanjim/nui.nvim)", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Configure and start the cmdline popup (after VimEnter).
---@param opts? cmdline.Opts
function M.setup(opts)
  if not check() then
    return
  end
  opts = resolve(opts)

  -- 'cmdheight' and ui2 right away, so the screen does not change under you
  -- when the popup loads after VimEnter
  local ui2 = type(opts.ui2) == "table" and opts.ui2 or {}
  _G.require("neat.cmdline.ui2").start({
    enable = ui2.enable ~= false,
    cmdheight = ui2.cmdheight == nil and 0 or ui2.cmdheight,
  })

  local function load()
    require("neat.cmdline.util").try(function()
      require("neat.cmdline.config").setup(opts)
      M.enable()
    end)
  end

  if vim.v.vim_did_enter == 0 then
    -- Schedule loading after VimEnter. Get the UI up and running first.
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("neat.cmdline.setup", { clear = true }),
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
  require("neat.cmdline.render").disable()
  require("neat.cmdline.ui").disable()
  require("neat.cmdline.ui2").restore()
  require("neat.cmdline.pager").restore()
  require("neat.cmdline.messages").restore()
  require("neat.cmdline.confirm").restore()
end

function M.enable()
  if Config.is_running() then
    return
  end
  if not Config.options.cmdline then
    -- `:Neat cmdline enable` without `cmdline.enabled`: use neat's `cmdline` options
    if not check() then
      return
    end
    Config.setup(resolve())
  end
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("neat.cmdline.vim_leave_pre", { clear = true }),
    callback = function()
      if Config.is_running() then
        pcall(M.disable)
      end
    end,
  })
  Config._running = true
  require("neat.cmdline.ui2").start(Config.options.ui2)
  require("neat.cmdline.ui2").setup(Config.options.ui2)
  require("neat.cmdline.pager").setup(Config.options.ui2.pager)
  require("neat.cmdline.confirm").setup(Config.options.confirm)
  require("neat.cmdline.messages").setup(Config.options.messages)
  require("neat.cmdline.ui").enable()
  require("neat.cmdline.render").enable()
end

function M.toggle()
  if Config.is_running() then
    M.disable()
  else
    M.enable()
  end
end

return M
