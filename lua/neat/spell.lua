-- neat.nvim spell: z= lists spelling suggestions through vim.ui.select, so
-- they open in whatever picker implements it (neat's `select` with its
-- backend, fzf-lua, snacks, mini.pick, ...). With Neovim's own vim.ui.select
-- that is the same numbered list as the builtin z=. A count (3z=) still picks
-- the suggestion directly, as in Vim.
local M = {}

---@class neat.spell.Config
---@field keymap? boolean map z= to `<Plug>(neat-spell-suggest)` unless z= is already mapped (default true)

---@type neat.spell.Config
M.defaults = { keymap = true }

--- The keyword under or after the cursor, like `<cword>`.
---@class neat.spell.Word
---@field buf integer
---@field row integer 0-based
---@field col integer 0-based, inclusive
---@field end_col integer 0-based, exclusive
---@field text string

---@return neat.spell.Word?
local function word_at_cursor()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local start = 0
  while true do
    local match = vim.fn.matchstrpos(line, [[\k\+]], start) ---@type [string, integer, integer]
    local text, s, e = match[1], match[2], match[3]
    if s == -1 then
      return nil
    end
    if e > col then -- the first keyword that ends after the cursor: under it, or the next one
      return { buf = vim.api.nvim_get_current_buf(), row = row - 1, col = s, end_col = e, text = text }
    end
    start = e
  end
end

--- Replace `word` with `text`, if the buffer still has it there. Unlike `ciw`
--- this leaves the registers alone, as the builtin z= does.
---@param word neat.spell.Word
---@param text string
local function replace(word, text)
  if not vim.api.nvim_buf_is_valid(word.buf) then
    return
  end
  local ok, current = pcall(vim.api.nvim_buf_get_text, word.buf, word.row, word.col, word.row, word.end_col, {})
  if not ok or current[1] ~= word.text then
    return
  end
  vim.api.nvim_buf_set_text(word.buf, word.row, word.col, word.row, word.end_col, { text })
  if vim.api.nvim_get_current_buf() == word.buf then
    vim.api.nvim_win_set_cursor(0, { word.row + 1, word.col })
  end
end

--- List suggestions for the word under the cursor through vim.ui.select().
function M.suggest()
  local count = vim.v.count
  local word = count == 0 and word_at_cursor() or nil
  if not word then
    vim.cmd.normal({ (count > 0 and count or "") .. "z=", bang = true })
    return
  end
  local max = tonumber(vim.o.spellsuggest:match("(%d+)")) or 25
  local suggestions = vim.fn.spellsuggest(word.text, max) ---@type string[]
  if #suggestions == 0 then
    vim.notify(("No suggestions for %q"):format(word.text), vim.log.levels.WARN)
    return
  end
  vim.ui.select(
    suggestions,
    { prompt = ('Change "%s" to'):format(word.text), kind = "spell" },
    ---@param choice string?
    function(choice)
      if choice then
        replace(word, choice)
      end
    end
  )
end

--- Map z= to `<Plug>(neat-spell-suggest)` (defined in plugin/neat.lua),
--- unless z= is already mapped or `keymap` is false.
---@param opts? neat.spell.Config
function M.setup(opts)
  local config = vim.tbl_extend("force", M.defaults, opts or {}) ---@type neat.spell.Config
  vim.validate("spell.keymap", config.keymap, "boolean")
  if config.keymap and vim.fn.maparg("z=", "n") == "" then
    vim.keymap.set(
      "n",
      "z=",
      "<Plug>(neat-spell-suggest)",
      { desc = "neat: spelling suggestions through vim.ui.select" }
    )
  end
end

return M
