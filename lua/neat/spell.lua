-- neat.nvim spell: z= lists spelling suggestions through vim.ui.select, so
-- they open in whatever picker implements it (neat's `select` with telescope,
-- fzf-lua, snacks, mini.pick, ...). With Neovim's own vim.ui.select that is
-- the same numbered list as the builtin z=. A count (3z=) still picks the
-- suggestion directly, as in Vim.
local M = {}

function M.suggest()
  local count = vim.v.count
  local word = vim.fn.expand("<cword>")
  if count > 0 or word == "" then
    vim.cmd.normal({ (count > 0 and count or "") .. "z=", bang = true })
    return
  end
  local max = tonumber(vim.o.spellsuggest:match("(%d+)")) or 25
  local suggestions = vim.fn.spellsuggest(word, max)
  if #suggestions == 0 then
    vim.notify(("No suggestions for %q"):format(word), vim.log.levels.WARN)
    return
  end
  vim.ui.select(suggestions, { prompt = ('Change "%s" to'):format(word), kind = "spell" }, function(choice)
    if choice then
      -- pickers put the cursor back on the word before calling back
      vim.cmd.normal({ "ciw" .. choice, bang = true })
    end
  end)
end

--- Map z= in Normal mode, unless something else already did.
---@param opts? table
function M.setup(opts)
  vim.validate("spell", opts, "table", true)
  if vim.fn.maparg("z=", "n") ~= "" then
    return
  end
  vim.keymap.set("n", "z=", M.suggest, { desc = "neat: spelling suggestions through vim.ui.select" })
end

return M
