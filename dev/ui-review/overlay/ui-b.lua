-- review variant B: no toasts (ui2 messages, native progress) + blink.indent guides
return {
  dir = '~/dev/projs/ui.nvim',
  name = 'ui.nvim',
  lazy = false,
  priority = 1000,
  dependencies = {
    { 'saghen/blink.indent', version = '*' },
  },
  opts = {
    select = {},
    input = {},
    notify = { backend = 'native' },
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
