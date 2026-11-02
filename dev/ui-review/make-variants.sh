#!/usr/bin/env bash
# Build the review configs ~/.config/nvim-ui-{a,b,c} from the current ~/.config/nvim.
# The real config and data dir are only read: the config is copied, and the data dir is
# cloned (APFS copy-on-write) so the variants start with the same plugins, parsers and lockfile.
#
#   ui-a: notify = snacks toasts,          indent = snacks
#   ui-b: notify = native progress + ui2,  indent = blink.indent
#   ui-c: notify = nvim-notify,            indent = snacks
#   ui:   the picks from the review: notify = snacks toasts, indent = blink.indent
set -euo pipefail

src_cfg="$HOME/.config/nvim"
src_data="$HOME/.local/share/nvim"
repo="$(cd "$(dirname "$0")/.." && pwd)"

# Baseline: an untouched copy of the real config with its own cloned data dir, so recording
# it never writes to ~/.local/share/nvim.
rm -rf "$HOME/.config/nvim-ui-base"
cp -R "$src_cfg" "$HOME/.config/nvim-ui-base"
[[ -d "$HOME/.local/share/nvim-ui-base" ]] || cp -cR "$src_data" "$HOME/.local/share/nvim-ui-base"

for v in a b c pick; do
  if [[ $v == pick ]]; then name="nvim-ui"; overlay="ui"; else name="nvim-ui-$v"; overlay="ui-$v"; fi
  cfg="$HOME/.config/$name"
  data="$HOME/.local/share/$name"

  rm -rf "$cfg"
  cp -R "$src_cfg" "$cfg"
  if [[ ! -d "$data" ]]; then
    cp -cR "$src_data" "$data"
  fi

  # The old plugins go; ui.nvim comes in from the local checkout.
  rm "$cfg/lua/baggiponte/plugins/ui/snacks.lua" "$cfg/lua/baggiponte/plugins/ui/dressing.lua"
  cp "$repo/review/overlay/$overlay.lua" "$cfg/lua/baggiponte/plugins/ui/ui.lua"

  # neo-tree: Snacks.rename -> ui.rename
  sed -i '' "s/Snacks\.rename\.on_rename_file/require('ui.rename').on_rename_file/" \
    "$cfg/lua/baggiponte/plugins/neo-tree.lua"

  # LSP progress moves into ui.notify's adapter: drop the hand-written autocmd.
  uv run --no-project python - "$cfg/lua/baggiponte/autocmds.lua" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s, n = re.subn(r"-- courtesy of folke: .*?\nvim\.api\.nvim_create_autocmd\('LspProgress', \{.*?\n\}\)\n", "", s, flags=re.S)
assert n == 1, "LspProgress autocmd not found"
p.write_text(s)
PY
done

# ui-b: send progress messages to ui2's msg window (bottom-right) instead of the cmdline.
sed -i '' "s/require('vim._core.ui2').enable({})/require('vim._core.ui2').enable({ msg = { targets = { progress = 'msg' } } })/" \
  "$HOME/.config/nvim-ui-b/lua/baggiponte/options.lua"
sed -i '' "s/callback = require('vim._core.ui2').enable })/callback = function() require('vim._core.ui2').enable({ msg = { targets = { progress = 'msg' } } }) end })/" \
  "$HOME/.config/nvim-ui-b/lua/baggiponte/options.lua"
grep -q "progress = 'msg'" "$HOME/.config/nvim-ui-b/lua/baggiponte/options.lua"

echo "built: nvim-ui-base nvim-ui-a nvim-ui-b nvim-ui-c nvim-ui"
