#!/usr/bin/env bash
# Open the statusline.nvim review page, or stop its server.
#   review/launch.sh          start the server (if needed) and open the page
#   review/launch.sh stop     stop the server
# Decisions are saved to review/feedback.json.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pidfile="$here/server.pid"
portfile="$here/server.port"

running() { [[ -f $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

if [[ ${1:-} == stop ]]; then
  running && kill "$(cat "$pidfile")" && echo "stopped"
  exit 0
fi

if ! running; then
  rm -f "$portfile"
  nohup uv run "$here/server.py" >"$here/server.log" 2>&1 &
  for _ in $(seq 50); do
    [[ -s $portfile ]] && break
    sleep 0.1
  done
fi
[[ -s $portfile ]] || { echo "server did not start; see $here/server.log" >&2; exit 1; }

url="http://127.0.0.1:$(cat "$portfile")/"
echo "review page: $url"
echo "try it:      NVIM_APPNAME=nvim-statusline nvim"
echo "baseline:    nvim"
[[ ${NO_OPEN:-} ]] || open "$url"
