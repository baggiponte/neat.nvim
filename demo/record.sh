#!/usr/bin/env bash
# Record demo/cmdline.tape against one config.
#   ./record.sh baseline   -> NVIM_APPNAME=nvim (your real config, run with -n -i NONE)
#   ./record.sh cmdline    -> NVIM_APPNAME=nvim-cmdline (the review variant)
# Output: out/<name>/{demo.gif,demo.mp4,frames/*.png}
set -euo pipefail
cd "$(dirname "$0")"
name=${1:?usage: record.sh baseline|cmdline}
case $name in
  baseline) appname=nvim ;;
  *) appname=nvim-$name ;;
esac
out=out/$name
rm -rf "$out" && mkdir -p "$out/frames"
tape=$out/run.tape
# vhs ignores Set commands that follow any other command, so Env goes after
# the tape's Set block (right before its first Hide).
{
  echo "Output $out/demo.gif"
  echo "Output $out/demo.mp4"
  awk -v out="$out" -v app="$appname" '
    !env && /^Hide$/ { print "Env NVIM_APPNAME \"" app "\""; env = 1 }
    { gsub("frames/", out "/frames/"); print }
  ' cmdline.tape
} >"$tape"
timeout 300 vhs "$tape"
