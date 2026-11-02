#!/usr/bin/env bash
# Build the review config ~/.config/nvim-statusline from the current ~/.config/nvim:
# lualine goes, statusline.nvim comes in from this checkout through lazy `dir`.
# The real config and data dir are only read; the data dir is cloned (APFS
# copy-on-write) on first run so the variant starts with the same plugins.
set -euo pipefail

src_cfg="$HOME/.config/nvim"
src_data="$HOME/.local/share/nvim"
cfg="$HOME/.config/nvim-statusline"
data="$HOME/.local/share/nvim-statusline"
repo="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$cfg"
rsync -a --exclude lazy-lock.json --exclude lua/baggiponte/plugins/ui/lualine "$src_cfg/" "$cfg/"
rm -rf "$cfg/lua/baggiponte/plugins/ui/lualine"
grep -v '"lualine.nvim"' "$src_cfg/lazy-lock.json" >"$cfg/lazy-lock.json"
cat >"$cfg/lua/baggiponte/plugins/ui/statusline.lua" <<LUA
return {
  {
    dir = '${repo/#$HOME/~}',
    name = 'statusline.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
LUA
if [[ ! -d $data ]]; then
  cp -cR "$src_data" "$data"
fi
NVIM_APPNAME=nvim-statusline timeout 300 nvim --headless '+Lazy! restore' +qa
echo "built: nvim-statusline"
