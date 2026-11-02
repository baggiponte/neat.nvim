-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline options are left (no messages, popupmenu, notify,
-- LSP, routes, commands, redirect, presets or log file); added `ui2`,
-- validation and the user-facing `cmdline.Opts` type.
---@diagnostic disable: missing-fields
local require = require("cmdline.util.lazy")

local M = {}

-- Keep noice's namespace name: highlights and tags in other plugins look for it.
M.ns = vim.api.nvim_create_namespace("noice")

--- Options for `require("cmdline").setup()` or `vim.g.cmdline`. Every field is optional.
---@class cmdline.Opts
---@field cmdline? cmdline.Opts.cmdline
---@field ui2? cmdline.Opts.ui2
---@field confirm? CmdlineConfirmOptions
---@field throttle? number milliseconds between updates when Neovim is not blocking
---@field views? table<string, NoiceViewOptions> override the built-in views, see cmdline.config.views
---@field format? NoiceFormatOptions override formatter options, see cmdline.config.format
---@field debug? boolean append ui events to ./cmdline.nvim.log

---@class cmdline.Opts.cmdline
---@field view? "cmdline_popup"|"cmdline"
---@field opts? NoiceViewOptions
---@field format? table<string, CmdlineFormat|false>

---@class cmdline.Opts.ui2
---@field disable_cmdline? boolean
---@field pager? CmdlinePagerOptions|false

function M.defaults()
  ---@class CmdlineConfig
  local defaults = {
    cmdline = {
      view = "cmdline_popup", -- view for rendering the cmdline. Change to `cmdline` to get a classic cmdline at the bottom
      opts = {}, -- global options for the cmdline. See section on views
      ---@type table<string, CmdlineFormat|false>
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
      -- When ui2 is enabled, stop it from drawing the cmdline (cmdline.nvim
      -- draws it) while ui2 keeps handling messages.
      disable_cmdline = true,
      -- Show ui2's pager (`:messages`, `g<`, long output) as a centred float.
      -- Set to `false` to keep ui2's panel at the bottom.
      ---@type CmdlinePagerOptions|false
      pager = {
        width = 0.8, -- fraction of the editor width, or columns
        height = 0.6, -- maximum fraction of the editor height, or lines
        border = "rounded",
        title = " Messages ",
      },
    },
    -- confirm() and `:s///c` prompts
    ---@type CmdlineConfirmOptions
    confirm = {
      style = "box", -- "box": centred near the top, as in noice; "toast": top-right corner; "ui2": ui2's bottom line
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

--- @type CmdlineConfig
M.options = {}

M._running = false
function M.is_running()
  return M._running
end

--- The options the user passed, before merging (the health check reads them).
---@type cmdline.Opts
M.user_options = {}

---@param o CmdlineConfig
local function validate(o)
  vim.validate("cmdline", o.cmdline, "table")
  vim.validate("cmdline.view", o.cmdline.view, "string")
  vim.validate("cmdline.format", o.cmdline.format, "table")
  vim.validate("confirm", o.confirm, "table")
  vim.validate("confirm.style", o.confirm.style, function(v)
    return v == "box" or v == "toast" or v == "ui2"
  end, false, '"box", "toast" or "ui2"')
  vim.validate("ui2", o.ui2, "table")
  vim.validate("ui2.disable_cmdline", o.ui2.disable_cmdline, "boolean")
  vim.validate("ui2.pager", o.ui2.pager, function(v)
    return v == false or type(v) == "table"
  end, false, "table or false")
  vim.validate("throttle", o.throttle, "number")
  vim.validate("views", o.views, "table")
  vim.validate("format", o.format, "table")
  vim.validate("debug", o.debug, "boolean")
end

--- Merge and validate the options. Errors on a wrong type.
---@param options? cmdline.Opts
function M.setup(options)
  M.user_options = options or {}
  M.options = vim.tbl_deep_extend("force", {}, M.defaults(), {
    views = require("cmdline.config.views").defaults,
    format = require("cmdline.config.format").defaults,
  }, options or {})
  validate(M.options)

  require("cmdline.config.cmdline").setup()

  require("cmdline.config.highlights").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("cmdline.highlights", { clear = true }),
    callback = function()
      require("cmdline.config.highlights").setup()
      local nui = package.loaded["cmdline.util.nui"]
      if nui then
        nui.check_bg()
      end
    end,
  })
end

return M
