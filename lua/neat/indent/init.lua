-- Indent guides with two interchangeable engines:
--
-- * "builtin": neat's own indent + scope guides (neat.indent.guides). Their
--   code is adapted from snacks.nvim and ships inside neat; snacks.nvim is not
--   needed. "snacks" is accepted as an older name for it.
-- * "blink": saghen/blink.indent, which must be installed separately

local M = {}

---@class ui.indent.Config
---@field enabled? boolean
---@field backend? "builtin"|"blink"|"snacks"
---@field builtin? table options for the builtin guides (same shape as snacks.nvim's `indent`)
---@field snacks? table old name for `builtin`
---@field blink? table options passed to `require("blink.indent").setup()`
local defaults = {
  backend = "builtin",
  builtin = {},
  blink = {},
}

---@type "builtin"|"blink"|nil the active backend, nil before setup()
M.backend = nil

local function enable_builtin()
  require("neat.indent.guides").enable()
end

---@param opts? ui.indent.Config
function M.setup(opts)
  local config = require("neat.util").builtin_alias("indent", vim.tbl_deep_extend("force", defaults, opts or {}))
  vim.validate("indent.backend", config.backend, function(v)
    return v == "builtin" or v == "blink"
  end, false, '"builtin" or "blink"')
  vim.validate("indent.builtin", config.builtin, "table")
  vim.validate("indent.blink", config.blink, "table")
  M.backend = config.backend

  -- calling setup() again applies the new options
  local guides = package.loaded["neat.indent.guides"]
  if guides and guides.enabled then
    guides.disable()
  end
  pcall(vim.api.nvim_del_augroup_by_name, "ui_indent_load")

  if config.backend == "builtin" then
    require("neat.util").config.indent = config.builtin
    if guides or vim.v.vim_did_enter == 1 then
      enable_builtin()
    else
      -- Load the engine (about 1,100 lines) with the first file buffer, not at startup.
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "FileType" }, {
        group = vim.api.nvim_create_augroup("ui_indent_load", { clear = true }),
        once = true,
        callback = enable_builtin,
      })
    end
  else
    require("blink.indent").setup(config.blink)
  end
end

--- Turn the builtin indent guides on or off (`:Neat indent on|off|toggle`).
---@param on? boolean nil toggles
function M.set(on)
  if M.backend == nil then
    -- `:Neat indent` without `indent.enabled`: use neat's `indent.builtin` options
    local o = require("neat.util").builtin_alias("indent", vim.deepcopy(require("neat").options.indent or {}))
    require("neat.util").config.indent = o.builtin or {}
    M.backend = "builtin"
  end
  if M.backend ~= "builtin" then
    vim.notify("neat.nvim: `:Neat indent` controls the builtin backend only", vim.log.levels.WARN)
    return
  end
  local guides = require("neat.indent.guides")
  if on == nil then
    on = not guides.enabled
  end
  if on then
    guides.enable()
  else
    guides.disable()
  end
end

return M
