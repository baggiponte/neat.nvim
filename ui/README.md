# ui.nvim

The UI pieces this Neovim config used from [snacks.nvim](https://github.com/folke/snacks.nvim) and
[dressing.nvim](https://github.com/stevearc/dressing.nvim), copied with attribution (see `NOTICE`) so both
plugins can go. Requires Neovim 0.12.

![ui.nvim: select, input, notify and indent](demo/ui.gif)

## Install

ui.nvim lives in [neat.nvim](https://github.com/baggiponte/neat.nvim) and is
published on its own `ui` branch. With `vim.pack`:

```lua
vim.pack.add({
  { src = 'https://github.com/baggiponte/neat.nvim', version = 'ui', name = 'ui.nvim' },
})
```

## Setup

ui.nvim starts by itself with the defaults below. To change them, either call
`setup()` in your config or set `vim.g.ui` (a table, or a function returning
one) before `vim.pack.add()`. Set `vim.g.loaded_ui = true` to turn it off.

```lua
require('ui').setup({
  select = {},                        -- vim.ui.select as a telescope dropdown (dressing)
  input = {},                         -- vim.ui.input in a float (snacks input, keeps completion + cancelreturn)
  notify = { backend = 'snacks' },    -- 'snacks' | 'native' | 'nvim-notify', plus LSP progress
  indent = { backend = 'snacks' },    -- 'snacks' | 'blink'
})
```

Every module is on unless its table has `enabled = false`. Options are checked
with `vim.validate()`; misspelled keys show up in `:checkhealth ui`.

The heavy parts load on first use, not at startup: the input window on the
first `vim.ui.input()`, the snacks notifier on the first `vim.notify()`, and
the snacks indent engine with the first file buffer.

## Commands and health

| Command | What it does |
| --- | --- |
| `:Ui notifications` | Notification history of the active backend (`:UiNotifications` still works, but is deprecated) |
| `:Ui indent on\|off\|toggle` | Turn the snacks indent guides on or off |

`:checkhealth ui` checks Neovim, the plugins each chosen backend needs
(telescope, nvim-notify, blink.indent), unknown options, and whether another
plugin replaced `vim.notify`, `vim.ui.select` or `vim.ui.input` after ui.nvim.

| Module | What it does |
| --- | --- |
| `select` | Telescope dropdown for `vim.ui.select`, with dressing's code-action layout. Falls back to the builtin when telescope is missing. |
| `input` | snacks' floating input with history and completion (neo-tree's file completion works). |
| `notify` | `snacks`: vendored snacks toasts. `native`: no toasts; ui2 shows messages and LSP progress goes through `nvim_echo{kind='progress'}`. `nvim-notify`: hands `vim.notify` to [nvim-notify](https://github.com/rcarriga/nvim-notify). `lsp_progress = true` (default) renders `$/progress` with whichever is active. `:Ui notifications` opens the matching history. |
| `indent` | `snacks`: vendored indent + scope guides without animation. `blink`: [blink.indent](https://github.com/saghen/blink.indent). |
| `rename` | `require('ui.rename').on_rename_file(from, to)` sends `willRenameFiles`/`didRenameFiles`; wire it to neo-tree's `FILE_MOVED`/`FILE_RENAMED`. |

## Demo

`demo/ui.gif` (above) shows the default setup: telescope `vim.ui.select`, the
floating input, snacks toasts with LSP progress and blink.indent guides. The
other backends are recorded alongside it:

| Recording | Notify | Indent |
| --- | --- | --- |
| [`demo/ui-a.gif`](demo/ui-a.gif) | snacks | snacks |
| [`demo/ui-b.gif`](demo/ui-b.gif) | native (ui2) | blink |
| [`demo/ui-c.gif`](demo/ui-c.gif) | nvim-notify | snacks |
| [`demo/ui-base.gif`](demo/ui-base.gif) | snacks.nvim + dressing.nvim, before this plugin | |

## Review

`review/make-variants.sh` builds `~/.config/nvim-ui-{base,a,b,c}` from `~/.config/nvim` (the real config is only
read). `review/nvim-review <variant>` launches one. `demo/record.sh` records `demo/ui.tape.in` against each.
