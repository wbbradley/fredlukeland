#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
memory=${PAPER_MEMORY:-4G}

exec 9> "$root_dir/.world.lock"
if ! flock -n 9; then
  echo "The world is locked by another Paper or reset process." >&2
  exit 1
fi

cd "$root_dir/.run/paper"
exec java \
  -Dterminal.jline=false \
  -Dterminal.ansi=false \
  -Xms1G \
  -Xmx"$memory" \
  -jar paper.jar \
  --nogui
