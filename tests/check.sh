#!/usr/bin/env sh
# Runs the checks the `check` workflow runs, so they fail before you push.
# prek calls this from .pre-commit-config.yaml; you can call it directly:
#
#   tests/check.sh annotations   # every function documents its parameters
#   tests/check.sh luals         # LuaLS type check at warning level
#   tests/check.sh smoke [scenario...]   # tests/smoke.lua (default: all four)
#
# Needs nvim on $PATH; luals also needs lua-language-server (CI pins 3.18.1,
# see .github/workflows/check.yml). nui.nvim is cloned into deps/ on first use.
set -eu

cd "$(dirname "$0")/.."

need() {
  command -v "$1" >/dev/null 2>&1 && return
  echo "tests/check.sh: '$1' not found on \$PATH. $2" >&2
  exit 1
}

nui() {
  [ -d deps/nui.nvim ] && return
  need git ""
  git clone --quiet --depth 1 https://github.com/MunifTanjim/nui.nvim deps/nui.nvim
}

check=${1:-}
[ $# -gt 0 ] && shift

case $check in
annotations)
  need nvim "Install Neovim stable."
  nvim --headless --clean -l tests/annotations.lua
  ;;
luals)
  need nvim "Install Neovim stable."
  need lua-language-server "Install it (CI uses 3.18.1): https://github.com/LuaLS/lua-language-server/releases"
  nui
  VIMRUNTIME=$(nvim --clean --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c q)
  export VIMRUNTIME
  out=$(mktemp)
  trap 'rm -f "$out"' EXIT
  # --check redraws a progress bar with \r; on failure print only the findings.
  if ! lua-language-server --check "$PWD" --configpath "$PWD/.luarc.json" \
    --checklevel=Warning --logpath "${TMPDIR:-/tmp}/neat-luals" >"$out" 2>&1; then
    tr '\r' '\n' <"$out" | grep -Ev '^[[:space:]]*$|^[[:space:]]*[>=]+ [0-9]+/[0-9]+|^Initializing' >&2
    exit 1
  fi
  ;;
smoke)
  need nvim "Install Neovim stable."
  nui
  [ $# -eq 0 ] && set -- off statusline ui cmdline
  for scenario in "$@"; do
    echo "smoke ($scenario)"
    SMOKE=$scenario nvim --headless --clean \
      --cmd "set rtp^=$PWD/deps/nui.nvim" \
      --cmd "set rtp^=$PWD" \
      --cmd 'luafile tests/smoke.lua'
  done
  ;;
*)
  echo "usage: tests/check.sh annotations|luals|smoke [scenario...]" >&2
  exit 2
  ;;
esac
