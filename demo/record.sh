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
{
  echo "Output $out/demo.gif"
  echo "Output $out/demo.mp4"
  echo "Env NVIM_APPNAME \"$appname\""
  sed "s#frames/#$out/frames/#" cmdline.tape
} >"$tape"
timeout 300 vhs "$tape"
