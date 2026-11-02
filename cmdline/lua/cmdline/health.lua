-- :checkhealth cmdline
local M = {}

local health = vim.health

--- Keys in `user` that `defaults` does not have, as dotted paths.
---@param user table
---@param defaults table
---@param prefix string
---@param out string[]
local function unknown_keys(user, defaults, prefix, out)
  for k, v in pairs(user) do
    local path = prefix .. tostring(k)
    if defaults[k] == nil then
      out[#out + 1] = path
    elseif type(v) == "table" and type(defaults[k]) == "table" and not vim.islist(v) then
      unknown_keys(v, defaults[k], path .. ".", out)
    end
  end
  return out
end

function M.check()
  health.start("cmdline.nvim")

  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim >= 0.12 is required")
  end

  if pcall(require, "nui.object") then
    health.ok("nui.nvim is installed")
  else
    health.error("nui.nvim is not installed", "Install https://github.com/MunifTanjim/nui.nvim")
  end

  local Config = require("cmdline.config")
  if Config.is_running() then
    health.ok("cmdline popup is running")
  elseif Config.options.cmdline then
    health.info("cmdline popup is configured but disabled (`:Cmdline enable`)")
  else
    health.info('Not started: call require("cmdline").setup() or set vim.g.cmdline')
  end

  if Config.options.cmdline then
    -- views and format defaults are open-ended maps; only check the fixed options
    local defaults = Config.defaults()
    defaults.views, defaults.format, defaults.cmdline.format = nil, nil, nil
    local user = vim.deepcopy(Config.user_options)
    user.views, user.format = nil, nil
    if type(user.cmdline) == "table" then
      user.cmdline.format = nil
    end
    local unknown = unknown_keys(user, defaults, "", {})
    if #unknown == 0 then
      health.ok("No unknown options")
    else
      health.warn("Unknown options (typos?): " .. table.concat(unknown, ", "))
    end
  end

  health.start("cmdline.nvim: ui2")
  if not package.loaded["vim._core.ui2"] then
    health.info("ui2 is not loaded; nothing to patch (enable it with require('vim._core.ui2').enable({}))")
    return
  end
  if not Config.is_running() then
    health.info("ui2 is loaded; patches apply once cmdline.nvim runs")
    return
  end
  local opts = Config.options
  local function report(name, wanted, patched)
    if not wanted then
      health.info(name .. ": off in config")
    elseif patched then
      health.ok(name .. ": patched")
    else
      health.warn(
        name .. ": not patched",
        "ui2's private module layout may have changed; the popup still works but ui2 may draw the cmdline too"
      )
    end
  end
  report("cmdline handlers", opts.ui2.disable_cmdline, require("cmdline.ui2").is_patched())
  report("pager float", opts.ui2.pager ~= false, require("cmdline.pager").is_patched())
  report("confirm dialog", opts.confirm.style ~= "ui2", require("cmdline.confirm").is_patched())
end

return M
