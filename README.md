# neat.nvim

Three small Neovim plugins, each in its own folder. Each folder has its own
README with setup and options.

| Plugin | Folder | Replaces |
| --- | --- | --- |
| `cmdline.nvim` | [`cmdline/`](cmdline) | noice.nvim (centred cmdline popup on top of ui2) |
| `ui.nvim` | [`ui/`](ui) | snacks.nvim / dressing.nvim (select, input, notify, indent, rename) |
| `statusline.nvim` | [`statusline/`](statusline) | lualine.nvim |

## Install

`vim.pack` installs whole repositories, so every plugin is also published as its
own branch (`cmdline`, `ui`, `statusline`) by the `split` workflow on each push
to `main`. Pick the ones you want by branch and give each a name:

```lua
local src = 'https://github.com/baggiponte/neat.nvim'
vim.pack.add({
  { src = src, version = 'cmdline', name = 'cmdline.nvim' },
  { src = src, version = 'ui', name = 'ui.nvim' },
  { src = src, version = 'statusline', name = 'statusline.nvim' },
})
```

Each branch holds only that plugin's files, with its full history.

`cmdline.nvim` needs [nui.nvim](https://github.com/MunifTanjim/nui.nvim) installed
alongside it.

## Using them

Each plugin follows `:h lua-plugin`: a small `plugin/` file defines its command
and loads nothing else until it is used, options can come from `setup()` or
`vim.g.<name>`, and `:checkhealth <name>` reports problems.

| Plugin | Starts | Command | Turn off |
| --- | --- | --- | --- |
| cmdline.nvim | when you call `setup()` or set `vim.g.cmdline` | `:Cmdline enable\|disable\|toggle` | `vim.g.loaded_cmdline = true` |
| ui.nvim | by itself | `:Ui notifications`, `:Ui indent on\|off\|toggle` | `vim.g.loaded_ui = true` |
| statusline.nvim | by itself | `:Statusline enable\|disable\|toggle\|refresh` | `vim.g.loaded_statusline = true` |

Help is in `:h cmdline.nvim`, `:h ui.nvim` and `:h statusline.nvim`, generated
from each README on every push to `main`.

## Develop

Work on `main`. To rebuild the per-plugin branches locally, run
`scripts/split.sh` (add `--push` to publish them).

The `check` workflow runs on every push and pull request: stylua, a LuaLS
type check (errors only), and `tests/smoke.lua`, which loads each plugin
headless the way `vim.pack` does and runs its command and health check:

```sh
SMOKE=statusline nvim --headless --clean --cmd "set rtp^=$PWD/statusline" -c 'luafile tests/smoke.lua'
```

## Credits

`cmdline.nvim` is a trimmed copy of [noice.nvim](https://github.com/folke/noice.nvim)
by Folke Lemaitre: the cmdline popup, its views and text rendering are noice's
work. `ui.nvim` adapts parts of [snacks.nvim](https://github.com/folke/snacks.nvim)
and [dressing.nvim](https://github.com/stevearc/dressing.nvim), and
`statusline.nvim` adapts [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim).
Licences and notices for the adapted code are in each plugin's `LICENSES/` and
`NOTICE`.
