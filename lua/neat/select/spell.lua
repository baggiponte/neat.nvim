-- z= through vim.ui.select (a telescope picker with neat's `select` module),
-- instead of the numbered list and "Type number and <Enter>" prompt.
-- A count (3z=) still picks the suggestion directly, as in Vim, and without
-- telescope (it may load later in the session) z= stays the builtin list.
local M = {}

function M.suggest()
  local count = vim.v.count
  local word = vim.fn.expand("<cword>")
  if count > 0 or word == "" or not require("neat.select.telescope").is_supported() then
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
      -- the picker puts the cursor back on the word before calling back
      vim.cmd.normal({ "ciw" .. choice, bang = true })
    end
  end)
end

return M
