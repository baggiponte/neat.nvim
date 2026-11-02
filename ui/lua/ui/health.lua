-- :checkhealth ui
local M = {}

local health = vim.health

local known = {
  select = { enabled = true, trim_prompt = true, telescope = true, format_item_override = true },
  input = {
    enabled = true,
    icon = true,
    icon_hl = true,
    icon_pos = true,
    prompt_pos = true,
    win = true,
    expand = true,
  },
  notify = { enabled = true, backend = true, lsp_progress = true, snacks = true, nvim_notify = true },
  indent = { enabled = true, backend = true, snacks = true, blink = true },
}

---@param name string
---@param mod string
---@param why string
local function need(name, mod, why)
  if pcall(require, mod) then
    health.ok(name .. " is installed")
  else
    health.error(name .. " is not installed", why)
  end
end

function M.check()
  health.start("ui.nvim")
  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim >= 0.12 is required")
  end

  local ui = require("ui")
  if not ui.did_setup then
    health.warn("setup() has not run", "plugin/ui.lua runs it at startup unless vim.g.loaded_ui is set")
    return
  end

  local opts = ui.options or {}
  local unknown = {}
  for k, v in pairs(opts) do
    if not known[k] then
      unknown[#unknown + 1] = k
    elseif type(v) == "table" then
      for kk in pairs(v) do
        if not known[k][kk] then
          unknown[#unknown + 1] = k .. "." .. kk
        end
      end
    end
  end
  if #unknown == 0 then
    health.ok("No unknown options")
  else
    table.sort(unknown)
    health.warn("Unknown options (typos?): " .. table.concat(unknown, ", "))
  end

  local function enabled(name)
    return not (type(opts[name]) == "table" and opts[name].enabled == false)
  end

  health.start("ui.nvim: select")
  if not enabled("select") then
    health.info("off")
  else
    if pcall(require, "telescope") then
      health.ok("telescope.nvim is installed")
    else
      health.warn("telescope.nvim is not installed", "vim.ui.select falls back to the builtin menu")
    end
    if vim.ui.select == require("ui.select").select then
      health.ok("vim.ui.select is ui.nvim's")
    else
      health.warn("vim.ui.select was replaced after setup() by another plugin")
    end
  end

  health.start("ui.nvim: input")
  if not enabled("input") then
    health.info("off")
  else
    local input = package.loaded["ui.input"]
    if input and vim.ui.input == input.input then
      health.ok("vim.ui.input is ui.nvim's")
    elseif not input and vim.ui.input ~= ui.original_input() then
      health.ok("vim.ui.input is ui.nvim's (loads on first use)")
    else
      health.warn("vim.ui.input was replaced after setup() by another plugin")
    end
  end

  health.start("ui.nvim: notify")
  if not enabled("notify") then
    health.info("off")
  else
    local notify = require("ui.notify")
    local backend = notify.get_config().backend
    health.info("backend: " .. backend)
    if backend == "nvim-notify" then
      need("nvim-notify", "notify", "Install https://github.com/rcarriga/nvim-notify or use another backend")
    end
    if backend == "native" then
      if package.loaded["vim._core.ui2"] then
        health.ok("ui2 is loaded and shows messages")
      else
        health.info("ui2 is not loaded; messages use the classic message area")
      end
    elseif vim.notify == notify.original() then
      health.warn("vim.notify was replaced after setup() by another plugin")
    else
      health.ok("vim.notify is routed to " .. backend)
    end
  end

  health.start("ui.nvim: indent")
  if not enabled("indent") then
    health.info("off")
  else
    local backend = require("ui.indent").backend
    health.info("backend: " .. tostring(backend))
    if backend == "blink" then
      need("blink.indent", "blink.indent", "Install https://github.com/saghen/blink.indent or use the snacks backend")
    else
      local snacks = package.loaded["ui.indent.snacks"]
      if not snacks then
        health.ok("guides load with the first file buffer")
      elseif snacks.enabled then
        health.ok("guides are on")
      else
        health.info("guides are off (`:Ui indent on`)")
      end
    end
  end
end

return M
