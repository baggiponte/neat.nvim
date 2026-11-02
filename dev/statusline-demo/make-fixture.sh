#!/usr/bin/env bash
# Build the demo repo: a committed Lua module, then edits on top so gitsigns
# has added, changed and removed lines and lua_ls has diagnostics to report.
# Prints the fixture path.
set -euo pipefail
dir=${TMPDIR:-/tmp}/statusline-demo
rm -rf "$dir" && mkdir -p "$dir" && cd "$dir"
git init -q -b main
cat >sample.lua <<'LUA'
local M = {}

function M.greet(name)
  return 'hello ' .. name
end

function M.total(xs)
  local sum = 0
  for _, x in ipairs(xs) do
    sum = sum + x
  end
  return sum
end

function M.unused()
  return nil
end

return M
LUA
cat >other.lua <<'LUA'
return { answer = 42 }
LUA
git add . && git -c user.name=demo -c user.email=demo@example.com commit -qm init
cat >sample.lua <<'LUA'
local M = {}

function M.greet(name)
  return 'hello, ' .. name .. '!'
end

function M.total(xs)
  local sum = 0
  for _, x in ipairs(xs) do
    sum = sum + x
  end
  return sum
end

function M.report(xs)
  local unused = 1
  return undefined_thing(M.total(xs))
end

return M
LUA
echo "$dir"
