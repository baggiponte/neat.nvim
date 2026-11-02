-- vim.notify backends and an LSP progress adapter that renders with whichever backend is active.
--
-- * "snacks": the vendored snacks notifier (toasts bottom-right, LSP progress as an updating toast)
-- * "native": leave vim.notify to ui2; LSP progress goes through `nvim_echo{kind='progress'}`
-- * "nvim-notify": rcarriga/nvim-notify, which must be installed separately

local M = {}

---@alias ui.notify.backend "snacks"|"native"|"nvim-notify"

---@class ui.notify.Config
---@field enabled? boolean
---@field backend? ui.notify.backend
---@field lsp_progress? boolean show LSP `$/progress` with the active backend
---@field snacks? table options for the snacks notifier (see ui.notify.notifier)
---@field nvim_notify? table options passed to `require("notify").setup()`
local defaults = {
  backend = "snacks",
  lsp_progress = true,
  snacks = {},
  nvim_notify = {},
}

local config = defaults ---@type ui.notify.Config
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function spin()
  return spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
end

---@class ui.notify.Progress
---@field id string stable id for this progress source
---@field source? string who reports it (native backend); defaults to "ui.nvim"
---@field title string
---@field msg string
---@field percent? integer
---@field done boolean

local renderers = {} ---@type table<ui.notify.backend, fun(p: ui.notify.Progress)>

-- Same look as the snacks.nvim notifier example: one toast per client, spinner icon until done.
function renderers.snacks(p)
  vim.notify(p.msg, vim.log.levels.INFO, {
    id = p.id,
    title = p.title,
    opts = function(notif)
      notif.icon = p.done and " " or spin()
    end,
  })
end

local records = {} ---@type table<string, table>
renderers["nvim-notify"] = function(p)
  local prev = records[p.id]
  records[p.id] = require("notify")(p.msg, vim.log.levels.INFO, {
    title = p.title,
    icon = p.done and " " or spin(),
    replace = prev,
    hide_from_history = not p.done,
    timeout = p.done and 3000 or false,
  })
  if p.done then
    records[p.id] = nil
  end
end

function renderers.native(p)
  -- the progress message already shows the percentage, so drop the "[ 50%] " prefix of each line
  local msg = p.msg:gsub("%[%s*%d+%%%] ", "")
  vim.api.nvim_echo({ { msg } }, false, {
    id = p.id,
    kind = "progress",
    source = p.source or "ui.nvim",
    title = p.title,
    percent = p.percent,
    status = p.done and "success" or "running",
  })
end

--- Report progress through the active backend.
---@param p ui.notify.Progress
function M.progress(p)
  renderers[config.backend](p)
end

---@type table<integer, {token: lsp.ProgressToken, msg: string, done: boolean}[]>
local lsp_progress = vim.defaulttable()

---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
local function on_lsp_progress(ev)
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  local value = ev.data.params.value --[[@as {percentage?: number, title?: string, message?: string, kind: "begin" | "report" | "end"}]]
  if not client or type(value) ~= "table" then
    return
  end

  local p = lsp_progress[client.id]
  for i = 1, #p + 1 do
    if i == #p + 1 or p[i].token == ev.data.params.token then
      p[i] = {
        token = ev.data.params.token,
        msg = ("[%3d%%] %s%s"):format(
          value.kind == "end" and 100 or value.percentage or 100,
          value.title or "",
          value.message and (" **%s**"):format(value.message) or ""
        ),
        done = value.kind == "end",
      }
      break
    end
  end

  local msg = {} ---@type string[]
  lsp_progress[client.id] = vim.tbl_filter(function(v)
    return table.insert(msg, v.msg) or not v.done
  end, p)

  M.progress({
    id = "ui.lsp_progress." .. client.id,
    source = "vim.lsp",
    title = client.name,
    msg = table.concat(msg, "\n"),
    percent = value.kind == "end" and 100 or value.percentage,
    done = #lsp_progress[client.id] == 0,
  })
end

--- Open the notification history of the active backend.
function M.history()
  if config.backend == "snacks" then
    require("ui.notify.notifier").show_history()
  elseif config.backend == "nvim-notify" then
    vim.cmd("Notifications")
  else
    vim.cmd("messages")
  end
end

---@param opts? ui.notify.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", defaults, opts or {})
  assert(renderers[config.backend], "ui.notify: unknown backend " .. tostring(config.backend))

  if config.backend == "snacks" then
    require("ui.util").config.notifier = config.snacks
    vim.notify = require("ui.notify.notifier").notify
  elseif config.backend == "nvim-notify" then
    local notify = require("notify")
    notify.setup(config.nvim_notify)
    vim.notify = function(...)
      return notify(...)
    end
  end

  if config.lsp_progress then
    vim.api.nvim_create_autocmd("LspProgress", {
      group = vim.api.nvim_create_augroup("ui.notify.lsp_progress", { clear = true }),
      callback = on_lsp_progress,
    })
  end

  vim.api.nvim_create_user_command("UiNotifications", M.history, { desc = "Notification history" })
end

return M
