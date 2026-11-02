# nvim-plugins

Three small Neovim plugins, each in its own folder:

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
local src = 'https://github.com/baggiponte/nvim-plugins'
vim.pack.add({
  { src = src, version = 'cmdline', name = 'cmdline.nvim' },
  { src = src, version = 'ui', name = 'ui.nvim' },
  { src = src, version = 'statusline', name = 'statusline.nvim' },
})
```

Each branch holds only that plugin's files, with its full history.

## Develop

Work on `main`. To rebuild the per-plugin branches locally, run
`scripts/split.sh` (add `--push` to publish them).
