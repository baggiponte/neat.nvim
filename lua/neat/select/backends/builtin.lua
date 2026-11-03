-- The `builtin` select backend: Neovim's own vim.ui.select() (the numbered
-- inputlist() menu, or whatever vim.ui.select was before neat's setup()).

---@type neat.select.Backend
return {
  available = function()
    return true
  end,
  select = function(items, opts, on_choice)
    require("neat.select").original()(items, opts, on_choice)
  end,
}
