-- :checkhealth neat
local M = {}

local health = vim.health

local known = {
  select = {
    enabled = true,
    backend = true,
    trim_prompt = true,
    telescope = true,
    builtin = true,
    format_item_override = true,
  },
  spell = { enabled = true, keymap = true },
  input = {
    enabled = true,
    icon = true,
    icon_hl = true,
    icon_pos = true,
    prompt_pos = true,
    win = true,
    expand = true,
  },
  notify = { enabled = true, backend = true, builtin = true, nvim_notify = true },
  indent = { enabled = true, backend = true, builtin = true, blink = true },
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
  health.start("neat.nvim")
  if vim.fn.has("nvim-0.12") == 1 then
    health.ok("Neovim " .. tostring(vim.version()))
  else
    health.error("Neovim >= 0.12 is required")
  end

  local neat = require("neat")
  if not neat.did_setup then
    health.warn("setup() has not run", 'Call require("neat").setup({...}) or set vim.g.neat before startup')
    return
  end

  local opts = neat.options or {}
  local unknown = {}
  for k, v in pairs(opts) do
    if not vim.tbl_contains(neat.modules, k) then
      unknown[#unknown + 1] = k
    elseif known[k] and type(v) == "table" then
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
  local on = vim.tbl_filter(neat.enabled, neat.modules)
  health.info("enabled: " .. (#on > 0 and table.concat(on, ", ") or "none"))

  local function enabled(name)
    return neat.enabled(name)
  end

  require("neat.cmdline.checks").check()
  require("neat.statusline.checks").check()

  health.start("select")
  if not enabled("select") then
    health.info("off (set `enabled = true`)")
  else
    local sel = require("neat.select")
    local backend, name = sel.backend()
    health.info("backend: " .. (name or "your own"))
    if backend.available() then
      health.ok("the backend is available")
    elseif name == "telescope" then
      health.warn("telescope.nvim is not installed: vim.ui.select uses Neovim's menu", {
        "Install https://github.com/nvim-telescope/telescope.nvim",
        "or set `select.backend` (`:h neat-select-backend`)",
      })
    else
      health.warn("the backend is not available: vim.ui.select uses Neovim's menu")
    end
    if vim.ui.select == require("neat.select").select then
      health.ok("vim.ui.select is neat.nvim's")
    else
      health.warn("vim.ui.select was replaced after setup() by another plugin")
    end
  end

  health.start("spell")
  if not enabled("spell") then
    health.info("off (set `enabled = true`)")
  else
    local map = vim.fn.maparg("z=", "n", false, true)
    if map.rhs == "<Plug>(neat-spell-suggest)" then
      health.ok("z= lists suggestions through vim.ui.select")
    elseif (neat.options.spell or {}).keymap == false then
      health.info("`keymap = false`: map <Plug>(neat-spell-suggest) yourself")
    else
      health.warn("z= is mapped by something else", "neat leaves an existing z= mapping alone")
    end
    if enabled("select") and vim.ui.select == require("neat.select").select then
      health.info("vim.ui.select is neat's (`select.backend`)")
    else
      health.info("vim.ui.select is whatever your config set (Neovim's numbered list by default)")
    end
  end

  health.start("input")
  if not enabled("input") then
    health.info("off (set `enabled = true`)")
  else
    local input = package.loaded["neat.input"]
    if input and vim.ui.input == input.input then
      health.ok("vim.ui.input is neat.nvim's")
    elseif not input and vim.ui.input ~= neat.original_input() then
      health.ok("vim.ui.input is neat.nvim's (loads on first use)")
    else
      health.warn("vim.ui.input was replaced after setup() by another plugin")
    end
  end

  health.start("notify")
  if not enabled("notify") then
    health.info("off (set `enabled = true`)")
  else
    local notify = require("neat.notify")
    local name = notify.get_config().backend
    name = type(name) == "string" and name or "your own"
    health.info("backend: " .. name)
    if name == "nvim-notify" then
      need("nvim-notify", "notify", "Install https://github.com/rcarriga/nvim-notify or use another backend")
    end
    if name == "native" then
      if package.loaded["vim._core.ui2"] then
        health.ok("ui2 is loaded and shows messages")
      else
        health.info("ui2 is not loaded; messages use the classic message area")
      end
    end
    local backend = notify.backend()
    if backend and vim.notify == backend.notify then
      health.ok("vim.notify is routed to " .. name)
    else
      health.warn("vim.notify was replaced after setup() by another plugin")
    end
  end

  health.start("indent")
  if not enabled("indent") then
    health.info("off (set `enabled = true`)")
  else
    local backend = require("neat.indent").backend
    health.info("backend: " .. tostring(backend))
    if backend == "blink" then
      need("blink.indent", "blink.indent", "Install https://github.com/saghen/blink.indent or use the builtin backend")
    else
      local guides = package.loaded["neat.indent.guides"]
      if not guides then
        health.ok("guides load with the first file buffer")
      elseif guides.enabled then
        health.ok("guides are on")
      else
        health.info("guides are off (`:Neat indent on`)")
      end
    end
  end
end

return M
