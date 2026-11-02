-- review variant C: nvim-notify (top-right, static, compact) + snacks indent guides
return {
  dir = '~/dev/projs/ui.nvim',
  name = 'ui.nvim',
  lazy = false,
  priority = 1000,
  dependencies = { 'rcarriga/nvim-notify' },
  opts = {
    select = {},
    input = {},
    notify = {
      backend = 'nvim-notify',
      nvim_notify = { stages = 'static', render = 'compact', top_down = true },
    },
    indent = {
      backend = 'snacks',
      snacks = { indent = { char = '┊' }, scope = { char = '┊' } },
    },
  },
}
