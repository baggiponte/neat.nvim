-- Part of :checkhealth neat
local M = {}

local health = vim.health

function M.check()
  health.start("cmdline")
  local Config = require("neat.cmdline.config")
  if not require("neat").enabled("cmdline") and not Config.is_running() then
    health.info("off (set `cmdline = { enabled = true }`)")
    return
  end

  if pcall(require, "nui.object") then
    health.ok("nui.nvim is installed")
  else
    health.error("nui.nvim is not installed", "Install https://github.com/MunifTanjim/nui.nvim")
  end

  if Config.is_running() then
    health.ok("cmdline popup is running")
  elseif Config.options.cmdline then
    health.info("cmdline popup is configured but disabled (`:Neat cmdline enable`)")
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
    -- routes are keyed by message kind, and new kinds may appear
    defaults.messages.routes = nil
    if type(user.messages) == "table" then
      user.messages.routes = nil
    end
    local unknown = require("neat.health").unknown_keys(user, defaults)
    if #unknown == 0 then
      health.ok("No unknown options")
    else
      health.warn("Unknown options (typos?): " .. table.concat(unknown, ", "))
    end
  end

  health.start("cmdline: ui2")
  if not package.loaded["vim._core.ui2"] then
    health.info("ui2 is not loaded; nothing to patch (enable it with require('vim._core.ui2').enable({}))")
    return
  end
  if not Config.is_running() then
    health.info("ui2 is loaded; patches apply once the cmdline popup runs")
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
  report("cmdline handlers", opts.ui2.disable_cmdline, require("neat.cmdline.ui2").is_patched())
  report("pager float", opts.ui2.pager ~= false, require("neat.cmdline.pager").is_patched())
  report(
    "message router and confirm dialog",
    opts.messages.enabled or opts.confirm.style ~= "ui2",
    require("neat.cmdline.messages").is_patched()
  )
  if opts.messages.enabled and not require("neat.cmdline.messages").can_notify() then
    health.info("messages: toasts need neat's `notify` module with a backend that shows toasts; messages stay with ui2")
  end
  if opts.ui2.cmdheight ~= false and vim.o.cmdheight ~= opts.ui2.cmdheight then
    health.warn(
      ("'cmdheight' is %d, neat set %d: something changed it later"):format(vim.o.cmdheight, opts.ui2.cmdheight)
    )
  end
end

return M
