-- Adapted from noice.nvim (Apache-2.0) by Folke Lemaitre; modified.
-- Changes: removed LSP and vim.notify routes.
local require = require("cmdline.util.lazy")

local Config = require("cmdline.config")

local M = {}

---@param routes? NoiceRouteConfig[]
function M.get(routes)
  ---@type NoiceRouteConfig[]
  local ret = {}

  -- add custom routes
  vim.list_extend(ret, routes or {})

  -- add default routes
  vim.list_extend(ret, M.defaults())
  return ret
end

---@return NoiceRouteConfig[]
function M.defaults()
  ---@type NoiceRouteConfig[]
  local ret = {}

  return vim.list_extend(ret, {
    {
      view = Config.options.cmdline.view,
      opts = Config.options.cmdline.opts,
      filter = { event = "cmdline" },
    },
    {
      view = "confirm",
      filter = {
        any = {
          { event = "msg_show", kind = "confirm" },
          { event = "msg_show", kind = "confirm_sub" },
          { event = "msg_show", kind = "number_prompt" },
        },
      },
    },
    {
      view = Config.options.messages.view_history,
      filter = {
        any = {
          { event = "msg_history_show" },
          -- { min_height = 20 },
        },
      },
    },
    {
      view = Config.options.messages.view_search,
      filter = {
        event = "msg_show",
        kind = "search_count",
      },
    },
    {
      filter = {
        any = {
          { event = { "msg_showmode", "msg_showcmd", "msg_ruler" } },
          { event = "msg_show", kind = "search_count" },
        },
      },
      opts = { skip = true },
    },
    {
      view = Config.options.messages.view,
      filter = {
        event = "msg_show",
        kind = { "", "echo", "echomsg", "lua_print", "list_cmd" },
      },
      opts = { replace = true, merge = true, title = "Messages" },
    },
    {
      view = Config.options.messages.view_error,
      filter = { error = true },
      opts = { title = "Error" },
    },
    {
      view = Config.options.messages.view_warn,
      filter = { warning = true },
      opts = { title = "Warning" },
    },
    {
      view = Config.options.notify.view,
      filter = {
        event = "noice",
        kind = { "stats", "debug" },
      },
      opts = { lang = "lua", replace = true, title = "Noice" },
    },
  })
end

return M
