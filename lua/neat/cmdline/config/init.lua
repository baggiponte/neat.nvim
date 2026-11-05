-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline options are left (no messages, popupmenu, notify,
-- LSP, routes, commands, redirect, presets or log file); added `ui2`,
-- validation and the user-facing `neat.cmdline.Config` type.
---@diagnostic disable: missing-fields
local lazy = require("neat.cmdline.util.lazy")

local M = {}

-- Keep noice's namespace name: highlights and tags in other plugins look for it.
M.ns = vim.api.nvim_create_namespace("noice")

--- `cmdline` options for `require("neat").setup()`. Every field is optional.
---@class neat.cmdline.Config
---@field cmdline? neat.cmdline.Config.cmdline
---@field ui2? neat.cmdline.Config.ui2
---@field confirm? neat.cmdline.ConfirmConfig
---@field messages? neat.cmdline.MessagesConfig
---@field throttle? number milliseconds between updates when Neovim is not blocking
---@field views? table<string, NoiceViewOptions> override the built-in views, see cmdline.config.views
---@field format? NoiceFormatOptions override formatter options, see cmdline.config.format
---@field debug? boolean append ui events to ./cmdline.nvim.log

---@class neat.cmdline.Config.cmdline
---@field view? "cmdline_popup"|"cmdline"
---@field opts? NoiceViewOptions
---@field format? table<string, neat.cmdline.Format|false>

---@class neat.cmdline.Config.ui2
---@field disable_cmdline? boolean
---@field pager? neat.cmdline.PagerConfig|false

function M.defaults()
  ---@class neat.cmdline.Options
  local defaults = {
    cmdline = {
      view = "cmdline_popup", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
      opts = {}, -- global options for the cmdline. See section on views
      ---@type table<string, neat.cmdline.Format|false>
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
    -- Coexistence with Neovim's experimental ui2 (vim._core.ui2).
    ui2 = {
      -- neat never turns ui2 on or sets 'cmdheight': both are yours to set
      -- (see :h neat-cmdline). :checkhealth neat warns when they don't suit
      -- the popup.
      -- When ui2 is enabled, stop it from drawing the cmdline (cmdline.nvim
      -- draws it) while ui2 keeps handling messages.
      disable_cmdline = true,
      -- Show ui2's pager (`:messages`, `g<`, long output) as a centred float.
      -- Set to `false` to keep ui2's panel at the bottom.
      ---@type neat.cmdline.PagerConfig|false
      pager = {
        width = 0.8, -- fraction of the editor width, or columns
        height = 0.6, -- maximum fraction of the editor height, or lines
        border = "rounded",
        title = " Messages ",
      },
    },
    -- Where ui2's messages go, by `msg_show` kind (see :h ui-messages).
    -- "notify": vim.notify() toasts (needs neat's notify module with the
    -- builtin or nvim-notify backend, else falls back to ui2); "pager": ui2's
    -- pager; "auto": the pager above `pager_lines` lines, else a toast; "ui2"
    -- or unlisted: ui2's own target. Set a kind to false to leave it to ui2.
    ---@type neat.cmdline.MessagesConfig
    messages = {
      enabled = true,
      pager_lines = 5,
      padding = 1, -- spaces on each side of the text in ui2's "msg" window
      routes = {
        [""] = "auto",
        echo = "auto",
        echomsg = "auto",
        lua_print = "auto",
        list_cmd = "auto",
        emsg = "notify",
        echoerr = "notify",
        lua_error = "notify",
        rpc_error = "notify",
        wmsg = "notify",
        shell_cmd = "pager",
        shell_out = "pager",
        shell_err = "pager",
        shell_ret = "pager",
      },
    },
    -- confirm() and `:s///c` prompts
    ---@type neat.cmdline.ConfirmConfig
    confirm = {
      style = "center", -- "center": middle of the editor; "box": centred near the top, as in noice; "toast": top-right corner; "ui2": ui2's bottom line
      title = " Confirm ",
    },
    throttle = 1000 / 30, -- how often to check for updates when Neovim is not blocking
    ---@type table<string, NoiceViewOptions>
    views = {}, -- override the built-in views, see cmdline.config.views
    ---@type NoiceFormatOptions
    format = {}, -- override formatter options, see cmdline.config.format
    debug = false, -- append ui events to ./cmdline.nvim.log
  }
  return defaults
end

---@type neat.cmdline.Options
M.options = {}

M._running = false
function M.is_running()
  return M._running
end

--- The options the user passed, before merging (the health check reads them).
---@type neat.cmdline.Config
M.user_options = {}

---@param o neat.cmdline.Options
local function validate(o)
  vim.validate("cmdline", o.cmdline, "table")
  vim.validate("neat.cmdline.view", o.cmdline.view, "string")
  vim.validate("neat.cmdline.format", o.cmdline.format, "table")
  vim.validate("confirm", o.confirm, "table")
  vim.validate("confirm.style", o.confirm.style, function(v)
    return v == "center" or v == "box" or v == "toast" or v == "ui2"
  end, false, '"center", "box", "toast" or "ui2"')
  vim.validate("ui2", o.ui2, "table")
  vim.validate("ui2.disable_cmdline", o.ui2.disable_cmdline, "boolean")
  vim.validate("messages", o.messages, "table")
  vim.validate("messages.enabled", o.messages.enabled, "boolean")
  vim.validate("messages.pager_lines", o.messages.pager_lines, "number")
  vim.validate("messages.padding", o.messages.padding, "number")
  vim.validate("messages.routes", o.messages.routes, "table")
  for kind, route in pairs(o.messages.routes) do
    vim.validate("messages.routes[" .. vim.inspect(kind) .. "]", route, function(v)
      return v == false or v == "notify" or v == "pager" or v == "auto" or v == "ui2"
    end, false, '"notify", "pager", "auto", "ui2" or false')
  end
  vim.validate("ui2.pager", o.ui2.pager, function(v)
    return v == false or type(v) == "table"
  end, false, "table or false")
  vim.validate("throttle", o.throttle, "number")
  vim.validate("views", o.views, "table")
  vim.validate("format", o.format, "table")
  vim.validate("debug", o.debug, "boolean")
end

--- Merge and validate the options. Errors on a wrong type.
---@param options? neat.cmdline.Config
function M.setup(options)
  M.user_options = options or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults(), {
    views = require("neat.cmdline.config.views").defaults,
    format = require("neat.cmdline.config.format").defaults,
  }, options or {})
  validate(M.options)

  require("neat.cmdline.config.cmdline").setup()

  require("neat.cmdline.config.highlights").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("neat.cmdline.highlights", { clear = true }),
    callback = function()
      require("neat.cmdline.config.highlights").setup()
      local nui = package.loaded["neat.cmdline.util.nui"]
      if nui then
        nui.check_bg()
      end
    end,
  })
end

return M
