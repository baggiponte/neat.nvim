-- review variant A: snacks notifier toasts + snacks indent guides
return {
  dir = '~/dev/projs/ui.nvim',
  name = 'ui.nvim',
  lazy = false,
  priority = 1000,
  opts = {
    select = {},
    input = {},
    notify = { backend = 'snacks', snacks = { top_down = false } },
    indent = {
      backend = 'snacks',
      snacks = { indent = { char = '┊' }, scope = { char = '┊' } },
    },
  },
}
