#!/usr/bin/env bash
# Record a tape against one config.
#   ./record.sh baseline [tape]   -> NVIM_APPNAME=nvim (your real config, run with -n -i NONE)
#   ./record.sh cmdline [tape]    -> NVIM_APPNAME=nvim-cmdline (a review variant)
# tape is cmdline (default) or dialogs.
# Output: out/<name>/{<tape>.gif,<tape>.mp4,frames/*.png}
set -euo pipefail
cd "$(dirname "$0")"
name=${1:?usage: record.sh baseline|cmdline|cmdline-toast|cmdline-ui2 [cmdline|dialogs]}
tapename=${2:-cmdline}
case $name in
  baseline) appname=nvim ;;
  *) appname=nvim-$name ;;
esac
out=out/$name
mkdir -p "$out/frames"
tape=$out/run-$tapename.tape
# vhs ignores Set commands that follow any other command, so Env goes after
# the tape's Set block (right before its first Hide).
{
  out_name=$([[ $tapename == cmdline ]] && echo demo || echo "$tapename")
  echo "Output $out/$out_name.gif"
  echo "Output $out/$out_name.mp4"
  awk -v out="$out" -v app="$appname" '
    !env && /^Hide$/ { print "Env NVIM_APPNAME \"" app "\""; env = 1 }
    { gsub("frames/", out "/frames/"); print }
  ' "$tapename.tape"
} >"$tape"
timeout 300 vhs "$tape"
