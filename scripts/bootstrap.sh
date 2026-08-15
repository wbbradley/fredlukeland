#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_dir="$root_dir/.cache/downloads"
paper_cache_dir="$root_dir/.cache/paper-runtime"
run_dir="$root_dir/.run"
worlds_dir="$root_dir/worlds"

paper_url="https://fill-data.papermc.io/v1/objects/bd3a58cf96874e5ea6643f5f6fe9b4f5bf9e34b795fa078c2f0ee8b98b2f907e/paper-26.2-112.jar"
paper_sha="bd3a58cf96874e5ea6643f5f6fe9b4f5bf9e34b795fa078c2f0ee8b98b2f907e"
floodgate_url="https://download.geysermc.org/v2/projects/floodgate/versions/2.2.5/builds/140/downloads/spigot"
floodgate_sha="9f436c42ffd8b1091a437d7a4e16f82181b9d5314f8b1732dfa9d5a4fffb19fe"
geyser_run="30923939558"
geyser_sha="bbcff25c3eb3db227323155cecb3f20857b308808dfea8ec55a94225ce205a6f"
user_agent="fredlukeland/0.1 (local Minecraft server)"

for command_name in curl gh java sha256sum; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done

java_major=$(java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')
if [[ -z "$java_major" || "$java_major" -lt 25 ]]; then
  echo "Paper 26.2 requires Java 25 or newer; found: ${java_major:-unknown}" >&2
  exit 1
fi

mkdir -p \
  "$cache_dir" \
  "$paper_cache_dir/cache" \
  "$paper_cache_dir/libraries" \
  "$paper_cache_dir/versions" \
  "$worlds_dir/world"

verify() {
  local expected=$1
  local path=$2
  [[ -f "$path" ]] && [[ "$(sha256sum "$path" | cut -d' ' -f1)" == "$expected" ]]
}

download() {
  local url=$1
  local expected=$2
  local destination=$3
  local temporary="${destination}.part"

  if verify "$expected" "$destination"; then
    return
  fi

  curl --fail --location --show-error --silent \
    --header "User-Agent: $user_agent" \
    --output "$temporary" "$url"
  if ! verify "$expected" "$temporary"; then
    echo "Checksum mismatch for $url" >&2
    exit 1
  fi
  mv "$temporary" "$destination"
}

download "$paper_url" "$paper_sha" "$cache_dir/paper-26.2-112.jar"
download "$floodgate_url" "$floodgate_sha" "$cache_dir/floodgate-spigot-2.2.5-140.jar"

if ! verify "$geyser_sha" "$cache_dir/Geyser-Standalone-26.40.jar"; then
  artifact_dir=$(mktemp -d "$root_dir/.geyser-artifact.XXXXXX")
  trap 'rm -r -- "$artifact_dir"' EXIT
  gh run download "$geyser_run" \
    --repo GeyserMC/Geyser \
    --name Geyser-Standalone \
    --dir "$artifact_dir"
  if ! verify "$geyser_sha" "$artifact_dir/Geyser-Standalone.jar"; then
    echo "Checksum mismatch for the pinned Geyser artifact" >&2
    exit 1
  fi
  mv "$artifact_dir/Geyser-Standalone.jar" "$cache_dir/Geyser-Standalone-26.40.jar"
  rm -r -- "$artifact_dir"
  trap - EXIT
fi

# The process tree is disposable. Only the world tree above survives.
if [[ -e "$run_dir" ]]; then
  if [[ "$run_dir" != "$root_dir/.run" ]]; then
    echo "Refusing to remove unexpected runtime path: $run_dir" >&2
    exit 1
  fi
  rm -r -- "$run_dir"
fi

mkdir -p "$run_dir/paper/plugins" "$run_dir/geyser"
cp "$cache_dir/paper-26.2-112.jar" "$run_dir/paper/paper.jar"
cp "$cache_dir/floodgate-spigot-2.2.5-140.jar" "$run_dir/paper/plugins/floodgate-spigot.jar"
cp "$cache_dir/Geyser-Standalone-26.40.jar" "$run_dir/geyser/Geyser-Standalone.jar"
cp "$root_dir/config/server.properties" "$run_dir/paper/server.properties"
printf 'eula=true\n' > "$run_dir/paper/eula.txt"

seed_file="$worlds_dir/world/.fredlukeland-seed"
difficulty_file="$worlds_dir/world/.fredlukeland-difficulty"

if [[ -f "$seed_file" ]]; then
  IFS= read -r world_seed < "$seed_file"
  if [[ ! "$world_seed" =~ ^-?[0-9]+$ ]]; then
    echo "Invalid seed marker: $seed_file" >&2
    exit 1
  fi
  printf 'level-seed=%s\n' "$world_seed" >> "$run_dir/paper/server.properties"
fi

if [[ -f "$difficulty_file" ]]; then
  IFS= read -r world_difficulty < "$difficulty_file"
  case "$world_difficulty" in
    peaceful|easy|normal|hard) ;;
    *) echo "Invalid difficulty marker: $difficulty_file" >&2; exit 1 ;;
  esac
  sed -i "s/^difficulty=.*/difficulty=$world_difficulty/" "$run_dir/paper/server.properties"
fi

ln -s "$worlds_dir/world" "$run_dir/paper/world"
ln -s "$paper_cache_dir/cache" "$run_dir/paper/cache"
ln -s "$paper_cache_dir/libraries" "$run_dir/paper/libraries"
ln -s "$paper_cache_dir/versions" "$run_dir/paper/versions"

# Generate Geyser's version-matched configuration, stop it, and switch it to Floodgate.
(
  cd "$run_dir/geyser"
  java -jar Geyser-Standalone.jar > config-generation.log 2>&1 &
  geyser_pid=$!
  for _ in $(seq 1 120); do
    [[ -f config.yml ]] && break
    if ! kill -0 "$geyser_pid" 2>/dev/null; then
      wait "$geyser_pid" || true
      echo "Geyser exited before generating config.yml" >&2
      exit 1
    fi
    sleep 0.25
  done
  kill -TERM "$geyser_pid" 2>/dev/null || true
  wait "$geyser_pid" || true
  [[ -f config.yml ]] || { echo "Timed out generating Geyser config.yml" >&2; exit 1; }
  sed -i 's/^  auth-type: online$/  auth-type: floodgate/' config.yml
)

echo "Bootstrap complete; only $worlds_dir is persistent game state."
