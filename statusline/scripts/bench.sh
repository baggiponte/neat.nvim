#!/usr/bin/env bash
# Startup and redraw benchmarks: lualine (NVIM_APPNAME=nvim) vs statusline.nvim
# (NVIM_APPNAME=nvim-statusline). Results go to review/bench/.
set -euo pipefail

cd "$(dirname "$0")/.."
out=review/bench
mkdir -p "$out"
file="$HOME/.config/Brewfile"
veryLazy='lua vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })'

nv() { echo "env NVIM_APPNAME=$1 timeout 20 nvim --headless"; }

# 1. Startup to the first screen: plugins that load on VeryLazy (lualine or
#    statusline.nvim, among others) are forced, as a UI would.
hyperfine --warmup 5 --runs 50 \
  --command-name lualine "$(nv nvim) -c '$veryLazy' -c 'e $file' +qa" \
  --command-name statusline.nvim "$(nv nvim-statusline) -c '$veryLazy' -c 'e $file' +qa" \
  --export-markdown "$out/startup.md" --export-json "$out/startup.json"

# 2. 1,000 `redrawstatus!` calls. statusline.nvim renders on each one, from cache.
loop='lua for _ = 1, 1000 do vim.cmd("redrawstatus!") end'
hyperfine --warmup 3 --runs 30 \
  --command-name lualine "$(nv nvim) -c '$veryLazy' -c 'e $file' -c '$loop' +qa" \
  --command-name statusline.nvim "$(nv nvim-statusline) -c '$veryLazy' -c 'e $file' -c '$loop' +qa" \
  --export-markdown "$out/redraw.md" --export-json "$out/redraw.json"

# 3. 1,000 full updates: what each plugin does when something changes.
#    lualine rebuilds its statusline; statusline.nvim drops every cache first.
lualine_upd='lua for _ = 1, 1000 do require("lualine").refresh({ force = true, place = { "statusline" } }); vim.cmd("redrawstatus!") end'
stl_upd='lua local c = require("statusline.cache"); for _ = 1, 1000 do c.invalidate_file(); c.invalidate_git(); c.invalidate_diagnostics(); c.invalidate_lsp(); vim.cmd("redrawstatus!") end'
hyperfine --warmup 3 --runs 30 \
  --command-name lualine "$(nv nvim) -c '$veryLazy' -c 'e $file' -c '$lualine_upd' +qa" \
  --command-name statusline.nvim "$(nv nvim-statusline) -c '$veryLazy' -c 'e $file' -c '$stl_upd' +qa" \
  --export-markdown "$out/update.md" --export-json "$out/update.json"
