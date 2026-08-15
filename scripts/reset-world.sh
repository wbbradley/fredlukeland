#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
worlds_dir="$root_dir/worlds"
world_dir="$worlds_dir/world"
seed=${WORLD_SEED:?WORLD_SEED is required}
difficulty=${WORLD_DIFFICULTY:?WORLD_DIFFICULTY is required}

if [[ ! "$seed" =~ ^-?[0-9]+$ ]]; then
  echo "Seed must be a signed decimal integer; received: $seed" >&2
  exit 1
fi

case "$difficulty" in
  peaceful|easy|normal|hard) ;;
  *)
    echo "Difficulty must be peaceful, easy, normal, or hard; received: $difficulty" >&2
    exit 1
    ;;
esac

for command_name in flock ss; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

exec 9> "$root_dir/.world.lock"
if ! flock -n 9; then
  echo "Cannot reset while Paper or another reset process holds the world lock." >&2
  exit 1
fi

# The port check also catches a Paper process started before world locking was added.
if ss -H -ltn | awk '$4 ~ /:25565$/ { found = 1 } END { exit !found }'; then
  echo "Cannot reset while a server is listening on TCP port 25565." >&2
  exit 1
fi

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
backup_dir="$worlds_dir/backups/$timestamp"
if [[ -e "$backup_dir" ]]; then
  echo "Backup destination already exists: $backup_dir" >&2
  exit 1
fi

mkdir -p "$worlds_dir/backups"
if [[ -e "$world_dir" ]]; then
  mkdir "$backup_dir"
  mv "$world_dir" "$backup_dir/world"
fi

mkdir "$world_dir"
printf '%s\n' "$seed" > "$world_dir/.fredlukeland-seed"
printf '%s\n' "$difficulty" > "$world_dir/.fredlukeland-difficulty"

echo "World reset prepared with seed $seed and difficulty $difficulty."
if [[ -d "$backup_dir/world" ]]; then
  echo "Previous world moved to $backup_dir/world"
fi
echo "Start the stack with: procman procman.pman"
