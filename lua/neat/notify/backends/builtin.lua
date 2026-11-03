-- The `builtin` notify backend: neat's toasts (neat.notify.notifier, adapted
-- from snacks.nvim). The notifier and its window code load on the first message.

---@type neat.notify.Backend
return {
  toasts = true,
  setup = function(opts)
    require("neat.util").config.notifier = opts or {}
  end,
  notify = function(msg, level, opts)
    return require("neat.notify.notifier").notify(msg, level, opts)
  end,
  history = function()
    require("neat.notify.notifier").show_history()
  end,
}
