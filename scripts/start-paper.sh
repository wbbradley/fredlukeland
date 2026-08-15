#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
memory=${PAPER_MEMORY:-4G}

cd "$root_dir/.run/paper"
exec java \
  -Dterminal.jline=false \
  -Dterminal.ansi=false \
  -Xms1G \
  -Xmx"$memory" \
  -jar paper.jar \
  --nogui
