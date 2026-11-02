-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: only the cmdline options are left (no messages, popupmenu, notify,
-- LSP, routes, commands, redirect, presets or log file); added `ui2`.
---@diagnostic disable: missing-fields
local require = require("cmdline.util.lazy")

local M = {}

-- Keep noice's namespace name: highlights and tags in other plugins look for it.
M.ns = vim.api.nvim_create_namespace("noice")

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

---@param options? CmdlineConfig
function M.setup(options)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults(), {
    views = require("cmdline.config.views").defaults,
    format = require("cmdline.config.format").defaults,
  }, options or {})

  require("cmdline.config.cmdline").setup()

  require("cmdline.config.highlights").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("cmdline.highlights", { clear = true }),
    callback = function()
      require("cmdline.config.highlights").setup()
    end,
  })

  M._running = true
end

return M
