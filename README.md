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

## Develop

Work on `main`. To rebuild the per-plugin branches locally, run
`scripts/split.sh` (add `--push` to publish them).

## Credits

`cmdline.nvim` is a trimmed copy of [noice.nvim](https://github.com/folke/noice.nvim)
by Folke Lemaitre: the cmdline popup, its views and text rendering are noice's
work. `ui.nvim` adapts parts of [snacks.nvim](https://github.com/folke/snacks.nvim)
and [dressing.nvim](https://github.com/stevearc/dressing.nvim), and
`statusline.nvim` adapts [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim).
Licences and notices for the adapted code are in each plugin's `LICENSES/` and
`NOTICE`.
