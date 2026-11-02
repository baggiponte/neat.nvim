-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: defaults match the original noice setup (notify/LSP off), removed
-- presets, LSP, markdown, health and picker integrations; added `ui2`.
---@diagnostic disable: missing-fields
local require = require("cmdline.util.lazy")

local Routes = require("cmdline.config.routes")

local M = {}

M.ns = vim.api.nvim_create_namespace("noice")

function M.defaults()
  ---@class NoiceConfig
  local defaults = {
    cmdline = {
      enabled = true, -- enables the Noice cmdline UI
      view = "cmdline_popup", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
      opts = {}, -- global options for the cmdline. See section on views
      ---@type table<string, CmdlineFormat>
      format = {
        -- conceal: (default=true) This will hide the text in the cmdline that matches the pattern.
        -- view: (default is cmdline view)
        -- opts: any options passed to the view
        -- icon_hl_group: optional hl_group for the icon
        -- title: set to anything or empty string to hide
        cmdline = { pattern = "^:", icon = "", lang = "vim" },
        search_down = { kind = "search", pattern = "^/", icon = " ", lang = "regex" },
        search_up = { kind = "search", pattern = "^%?", icon = " ", lang = "regex" },
        filter = { pattern = "^:%s*!", icon = "$", lang = "bash" },
        lua = { pattern = { "^:%s*lua%s+", "^:%s*lua%s*=%s*", "^:%s*=%s*" }, icon = "", lang = "lua" },
        help = { pattern = "^:%s*he?l?p?%s+", icon = "" },
        calculator = { pattern = "^=", icon = "", lang = "vimnormal" },
        input = { view = "cmdline_input", icon = "󰥻 " }, -- Used by input()
        -- lua = false, -- to disable a format, set to `false`
      },
    },
    messages = {
      -- NOTE: If you enable messages, then the cmdline is enabled automatically.
      -- This is a current Neovim limitation.
      enabled = true, -- enables the Noice messages UI
      view = "notify", -- default view for messages
      view_error = "notify", -- view for errors
      view_warn = "notify", -- view for warnings
      view_history = "messages", -- view for :messages
      view_search = "virtualtext", -- view for search count messages. Set to `false` to disable
    },
    popupmenu = {
      enabled = true, -- enables the Noice popupmenu UI
      ---@type 'nui'|'cmp'
      backend = "nui", -- backend to use to show regular cmdline completions
      ---@type NoicePopupmenuItemKind|false
      -- Icons for completion item kinds (see defaults at noice.config.icons.kinds)
      kind_icons = {}, -- set to `false` to disable icons
    },
    -- default options for require('noice').redirect
    -- see the section on Command Redirection
    ---@type NoiceRouteConfig
    redirect = {
      view = "popup",
      filter = { event = "msg_show" },
    },
    -- You can add any custom commands below that will be available with `:Noice command`
    ---@type table<string, NoiceCommand>
    commands = {
      history = {
        -- options for the message history that you get with `:Noice`
        view = "split",
        opts = { enter = true, format = "details" },
        filter = {
          any = {
            { event = "notify" },
            { error = true },
            { warning = true },
            { event = "msg_show", kind = { "" } },
          },
        },
      },
      -- :Noice last
      last = {
        view = "popup",
        opts = { enter = true, format = "details" },
        filter = {
          any = {
            { event = "notify" },
            { error = true },
            { warning = true },
            { event = "msg_show", kind = { "" } },
          },
        },
        filter_opts = { count = 1 },
      },
      -- :Noice errors
      errors = {
        -- options for the message history that you get with `:Noice`
        view = "popup",
        opts = { enter = true, format = "details" },
        filter = { error = true },
        filter_opts = { reverse = true },
      },
      all = {
        -- options for the message history that you get with `:Noice`
        view = "split",
        opts = { enter = true, format = "details" },
        filter = {},
      },
    },
    notify = {
      -- vim.notify is NOT overridden (snacks.notifier owns it). The view is
      -- still used for internal debug/stats messages.
      view = "notify",
    },
    -- Coexistence with Neovim's experimental ui2 (vim._core.ui2).
    ui2 = {
      -- When ui2 is enabled, stop it from drawing the cmdline (cmdline.nvim
      -- draws it) while ui2 keeps handling messages.
      disable_cmdline = true,
    },
    throttle = 1000 / 30, -- how frequently does Noice need to check for ui updates? This has no effect when in blocking mode.
    ---@type NoiceConfigViews
    views = {}, ---@see section on views
    ---@type NoiceRouteConfig[]
    routes = {}, --- @see section on routes
    ---@type NoiceFormatOptions
    format = {}, --- @see section on formatting
    debug = false,
    log = vim.fn.stdpath("state") .. "/cmdline.nvim.log",
    log_max_size = 1024 * 1024 * 2, -- 10MB
  }
  return defaults
end

--- @type NoiceConfig
M.options = {}

M._running = false
function M.is_running()
  return M._running
end

function M.setup(options)
  options = options or {}

  M.fix_legacy(options)

  if options.popupmenu and options.popupmenu.kind_icons == true then
    options.popupmenu.kind_icons = nil
  end

  M.options = vim.tbl_deep_extend("force", {}, M.defaults(), {
    views = require("cmdline.config.views").defaults,
    format = require("cmdline.config.format").defaults,
    popupmenu = {
      kind_icons = require("cmdline.config.icons").kinds,
    },
  })

  M.truncate_log()

  local routes = M.options.routes
  M.options = vim.tbl_deep_extend("force", M.options, options)
  vim.list_extend(M.options.routes, routes)

  if M.options.popupmenu.kind_icons == false then
    M.options.popupmenu.kind_icons = {}
  end

  require("cmdline.config.cmdline").setup()

  M.options.routes = Routes.get(M.options.routes)

  require("cmdline.config.highlights").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      require("cmdline.config.highlights").setup()
    end,
  })

  M._running = true
end

function M.truncate_log()
  local stat = (vim.uv or vim.loop).fs_stat(M.options.log)
  if stat and stat.size > M.options.log_max_size then
    io.open(M.options.log, "w+"):close()
  end
end

---@param opts NoiceConfig
function M.fix_legacy(opts)
  if opts.history then
    opts.commands = opts.commands or {}
    opts.commands.history = opts.history
    opts.history = nil
  end
end

return M
