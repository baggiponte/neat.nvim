-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: renamed :Noice to :Cmdline, removed picker integrations.
local require = require("cmdline.util.lazy")

local Config = require("cmdline.config")
local Manager = require("cmdline.message.manager")
local Message = require("cmdline.message")
local Router = require("cmdline.message.router")
local Util = require("cmdline.util")
local View = require("cmdline.view")

---@class NoiceCommand: NoiceRouteConfig
---@field filter_opts NoiceMessageOpts

local M = {}

---@type table<string, fun()>
M.commands = {}

---@param command NoiceCommand
function M.command(command)
  return function()
    local view = View.get_view(command.view, command.opts)
    view:set(Manager.get(
      command.filter,
      vim.tbl_deep_extend("force", {
        history = true,
        sort = true,
      }, command.filter_opts or {})
    ))
    view:display()
  end
end

function M.cmd(cmd)
  if M.commands[cmd] then
    M.commands[cmd]()
  else
    M.commands.history()
  end
end

function M.setup()
  M.commands = {
    debug = function()
      Config.options.debug = not Config.options.debug
    end,
    dismiss = function()
      Router.dismiss()
    end,
    log = function()
      vim.cmd.edit(Config.options.log)
    end,
    enable = function()
      require("cmdline").enable()
    end,
    disable = function()
      require("cmdline").disable()
    end,
    stats = function()
      Manager.add(Util.stats.message())
    end,
    routes = function()
      local message = Message("noice", "debug")
      message:set(vim.inspect(Config.options.routes))
      Manager.add(message)
    end,
    config = function()
      local message = Message("noice", "debug")
      message:set(vim.inspect(Config.options))
      Manager.add(message)
    end,
    viewstats = function()
      local message = Message("noice", "debug")
      message:set(vim.inspect(require("cmdline.message.router").view_stats()))
      Manager.add(message)
    end,
  }

  for name, command in pairs(Config.options.commands) do
    M.commands[name] = M.command(command)
  end

  vim.api.nvim_create_user_command("Cmdline", function(args)
    local cmd = vim.trim(args.args or "")
    M.cmd(cmd)
  end, {
    nargs = "?",
    desc = "cmdline.nvim",
    complete = function(_, line)
      if line:match("^%s*Cmdline %w+ ") then
        return {}
      end
      local prefix = line:match("^%s*Cmdline (%w*)") or ""
      return vim.tbl_filter(function(key)
        return key:find(prefix) == 1
      end, vim.tbl_keys(M.commands))
    end,
  })

  for name in pairs(M.commands) do
    local cmd = "Cmdline" .. name:sub(1, 1):upper() .. name:sub(2)
    vim.api.nvim_create_user_command(cmd, function()
      M.cmd(name)
    end, { desc = "cmdline.nvim " .. name })
  end
end

return M
