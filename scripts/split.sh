#!/usr/bin/env bash
# Publish each plugin folder as its own branch, so vim.pack can install it with
# `version = '<plugin>'`. The split is deterministic: rerunning it only appends.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
plugins=(cmdline ui statusline)

for p in "${plugins[@]}"; do
  sha=$(git subtree split --prefix="$p" HEAD)
  git branch -f "$p" "$sha"
  echo "$p -> $sha"
done

if [[ "${1:-}" == "--push" ]]; then
  git push origin "${plugins[@]}"
fi
