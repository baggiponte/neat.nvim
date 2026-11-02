# statusline.nvim

A small statusline for Neovim 0.11+, written to replace lualine in my config
with the same look: same sections, palette, components and extensions (lazy,
man, neo-tree, oil, quickfix). Code adapted from lualine.nvim is credited in
`NOTICE` and in each file's header.

Nothing is polled. Each component reads a per-buffer cache that autocmds
invalidate (`DiagnosticChanged`, `GitSignsUpdate`, `LspAttach`, `BufWritePost`,
...), and updates go through a single scheduled `redrawstatus!`.

## Setup

```lua
{
  'baggiponte/statusline.nvim',
  event = 'VeryLazy',
  opts = {},
}
```

Defaults live in `lua/statusline/config.lua`. Sections `a`, `b`, `c`, `x`,
`y`, `z` take built-in component names (`mode`, `branch`, `diff`, `fileicon`,
`filepath`, `filename`, `diagnostics`, `lsp`, `location`, `progress`) or
functions `function(ctx) return string end`. Colours are palette keys, hex
strings or highlight tables; 256-colour fallbacks are derived for terminals
without truecolor.

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
