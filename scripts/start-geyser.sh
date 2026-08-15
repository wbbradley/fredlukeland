#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
paper_key="$root_dir/.run/paper/plugins/floodgate/key.pem"
geyser_dir="$root_dir/.run/geyser"

[[ -f "$paper_key" ]] || { echo "Floodgate key does not exist: $paper_key" >&2; exit 1; }
cp "$paper_key" "$geyser_dir/key.pem"

cd "$geyser_dir"
exec java -jar Geyser-Standalone.jar
