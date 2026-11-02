#!/usr/bin/env bash
# Record demo/ui.tape.in against the baseline copy and each variant.
#   demo/record.sh            # all of them
#   demo/record.sh ui-a       # one
set -euo pipefail
cd "$(dirname "$0")"
targets=("${@:-ui-base ui-a ui-b ui-c}")
for t in ${targets[@]}; do
  sed -e "s/@APPNAME@/nvim-$t/" -e "s/@OUT@/$t/" ui.tape.in > "$t.tape"
  timeout 300 vhs "$t.tape"
done
