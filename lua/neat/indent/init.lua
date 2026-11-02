-- Indent guides with two interchangeable engines:
--
-- * "snacks": the vendored snacks indent + scope guides (ui.indent.snacks)
-- * "blink": saghen/blink.indent, which must be installed separately

local M = {}

---@class ui.indent.Config
---@field enabled? boolean
---@field backend? "snacks"|"blink"
---@field snacks? table options for ui.indent.snacks (same shape as snacks.nvim's `indent`)
---@field blink? table options passed to `require("blink.indent").setup()`
local defaults = {
  backend = "snacks",
  snacks = {},
  blink = {},
}

---@type "snacks"|"blink"|nil the active backend, nil before setup()
M.backend = nil

local function enable_snacks()
  require("neat.indent.snacks").enable()
end

---@param opts? ui.indent.Config
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.validate("indent.backend", config.backend, function(v)
    return v == "snacks" or v == "blink"
  end, false, '"snacks" or "blink"')
  vim.validate("indent.snacks", config.snacks, "table")
  vim.validate("indent.blink", config.blink, "table")
  M.backend = config.backend

  -- calling setup() again applies the new options
  local snacks = package.loaded["neat.indent.snacks"]
  if snacks and snacks.enabled then
    snacks.disable()
  end
  pcall(vim.api.nvim_del_augroup_by_name, "ui_indent_load")

  if config.backend == "snacks" then
    require("neat.util").config.indent = config.snacks
    if snacks or vim.v.vim_did_enter == 1 then
      enable_snacks()
    else
      -- Load the engine (about 1,100 lines) with the first file buffer, not at startup.
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
        group = vim.api.nvim_create_augroup("ui_indent_load", { clear = true }),
        once = true,
        callback = enable_snacks,
      })
    end
  else
    require("blink.indent").setup(config.blink)
  end
end

--- Turn the snacks indent guides on or off (`:Neat indent on|off|toggle`).
---@param on? boolean nil toggles
function M.set(on)
  if M.backend == nil then
    -- `:Neat indent` without `indent.enabled`: use neat's `indent.snacks` options
    local o = require("neat").options.indent or {}
    require("neat.util").config.indent = o.snacks or {}
    M.backend = "snacks"
  end
  if M.backend ~= "snacks" then
    vim.notify("neat.nvim: `:Neat indent` controls the snacks backend only", vim.log.levels.WARN)
    return
  end
  local snacks = require("neat.indent.snacks")
  if on == nil then
    on = not snacks.enabled
  end
  if on then
    snacks.enable()
  else
    snacks.disable()
  end
end

return M
