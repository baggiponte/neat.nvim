# statusline.nvim

A small statusline for Neovim 0.12+, written to replace lualine in my config
with the same look: same sections, palette, components and extensions (man,
neo-tree, oil, quickfix). Code adapted from lualine.nvim is credited in
`NOTICE` and in each file's header.

![statusline.nvim demo](demo/out/statusline/demo.gif)

Nothing is polled. Each component reads a per-buffer cache that autocmds
invalidate (`DiagnosticChanged`, `GitSignsUpdate`, `LspAttach`, `BufWritePost`,
...), and updates go through a single scheduled `redrawstatus!`.

## Setup

statusline.nvim lives in [neat.nvim](https://github.com/baggiponte/neat.nvim)
and is published on its own `statusline` branch. With `vim.pack`:

```lua
vim.pack.add({
  { src = 'https://github.com/baggiponte/neat.nvim', version = 'statusline', name = 'statusline.nvim' },
})
```

It draws itself at startup with the defaults. To change them, call
`require('statusline').setup({...})` in your config or set `vim.g.statusline`
(a table, or a function returning one) before `vim.pack.add()`. Set
`vim.g.loaded_statusline = true` to turn it off.

Defaults live in `lua/statusline/config.lua`. Sections `a`, `b`, `c`, `x`,
`y`, `z` take built-in component names (`mode`, `branch`, `diff`, `fileicon`,
`filepath`, `filename`, `diagnostics`, `lsp`, `location`, `progress`) or
functions `function(ctx) return string end`. Colours are palette keys, hex
strings or highlight tables; 256-colour fallbacks are derived for terminals
without truecolor. Options are checked with `vim.validate()`.

The highlight groups (`StlA<mode>`, `StlB`, ..., `StlDiagError`) are defined
with `default = true`, so a colorscheme or your config can override any of
them. The default palette is gruvbox-material.

## Commands and health

`:Statusline enable|disable|toggle` takes the statusline over or hands it back
to whatever was there before, and `:Statusline refresh` drops every cache and
redraws.

`:checkhealth statusline` checks that `'statusline'` is still ours, reports
unknown options, `'termguicolors'`, and whether gitsigns.nvim and
nvim-web-devicons are there for the git and icon components.

## Demo

The GIF above walks through normal, insert, visual, replace, command and
terminal modes, LSP diagnostics, splits and the quickfix, neo-tree, oil and man
extensions. One PNG per step is in `demo/out/statusline/frames/`, and the same
steps with lualine are in `demo/out/baseline/` for comparison.

## Review tooling

| Path | What it does |
| --- | --- |
| `review/make-variant.sh` | builds `~/.config/nvim-statusline`: the current config minus lualine, plus this checkout via lazy `dir` |
| `scripts/compare.lua` | renders the statusline in 19 scenarios and dumps text and colours, to diff lualine against this plugin |
| `scripts/bench.sh` | hyperfine: startup, 1,000 `redrawstatus!`, 1,000 full updates |
| `demo/record.sh baseline\|statusline` | records `demo/statusline.tape` with vhs against either config |
| `review/launch.sh` | serves the review page and opens it; `review/launch.sh stop` stops it |

```bash
CMP_FILE=~/.config/Brewfile CMP_OUT=/tmp/lualine.txt NVIM_APPNAME=nvim \
  nvim --headless -c 'luafile scripts/compare.lua'
```
