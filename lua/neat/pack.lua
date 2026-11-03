-- neat.nvim pack: make vim.pack's update flow say what it needs.
-- vim.pack.update() opens a review buffer (filetype "nvim-pack") that only
-- applies the updates on `:w`, and the running Neovim keeps the old code until
-- `:restart`. Neither is said anywhere on screen, so this module:
-- - puts a winbar on the review buffer: `:w` applies, `:q` cancels;
-- - shows a notification after an update: `:restart` loads the new code.
local M = {}

local group = "neat.pack"

M.winbar = table.concat({
  "%#DiagnosticWarn# Nothing is applied yet: ",
  "%#DiagnosticOk#:w%#DiagnosticWarn# applies the updates, ",
  "%#DiagnosticError#:q%#DiagnosticWarn# cancels ",
  "%#Comment# ]] [[ jump between plugins %*",
})

---@type string[]
local updated = {}

--- Text of the notification after `names` were updated.
---@param names string[]
---@return string
function M.restart_message(names)
  return ("vim.pack: updated %s. Run :restart to load the new code."):format(table.concat(names, ", "))
end

---@param ev {data: {kind: string, spec: {name: string}}}
function M.on_changed(ev)
  if ev.data.kind ~= "update" then
    return
  end
  if #updated == 0 then
    -- once per update, after vim.pack's own "Applying updates" progress message
    vim.defer_fn(function()
      local names = updated
      updated = {}
      vim.notify(M.restart_message(names))
    end, 200)
  end
  updated[#updated + 1] = ev.data.spec.name
end

---@param opts? table
function M.setup(opts)
  vim.validate("pack", opts, "table", true)
  local id = vim.api.nvim_create_augroup(group, { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = id,
    pattern = "nvim-pack",
    callback = function()
      vim.wo[0][0].winbar = M.winbar
    end,
  })
  vim.api.nvim_create_autocmd("PackChanged", { group = id, callback = M.on_changed })
end

--- Whether setup() ran.
---@return boolean
function M.is_setup()
  return pcall(vim.api.nvim_get_autocmds, { group = group })
end

return M
