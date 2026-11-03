-- The `native` notify backend: Neovim's own vim.notify() (the message area,
-- or ui2's message window when ui2 is on).

---@type neat.notify.Backend
return {
  toasts = false,
  notify = function(msg, level, opts)
    return require("neat.notify").original()(msg, level, opts)
  end,
}
