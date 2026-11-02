-- Luca's picks from the 2026-11-02 review: snacks notifier toasts + blink.indent guides
return {
  dir = '~/dev/projs/ui.nvim',
  name = 'ui.nvim',
  lazy = false,
  priority = 1000,
  dependencies = { { 'saghen/blink.indent', version = '*' } },
  opts = {
    select = {},
    input = {},
    notify = { backend = 'snacks', snacks = { top_down = false } },
    indent = {
      backend = 'blink',
      blink = {
        -- no textobjects or motions: the snacks setup this replaces had none
        mappings = { object_scope = '', object_scope_with_border = '', goto_top = '', goto_bottom = '' },
        static = { char = '┊' },
        scope = { char = '┊', highlights = { 'BlinkIndentScope' } },
      },
    },
  },
}
