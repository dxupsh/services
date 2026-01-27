#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$ROOT_DIR/services.tar.gz"

# Collect settings files
files=()
for f in "$ROOT_DIR"/services/*/settings.json; do
  [ -f "$f" ] && files+=("$f")
done

if [ ${#files[@]} -eq 0 ]; then
  echo "Error: no services/*/settings.json files found" >&2
  exit 1
fi

# Build archive in a temp directory
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/services"

for f in "${files[@]}"; do
  service="$(basename "$(dirname "$f")")"
  cp "$f" "$tmpdir/services/${service}.json"
done

COPYFILE_DISABLE=1 tar -czf "$OUTPUT" -C "$tmpdir" services

echo "Created $OUTPUT with ${#files[@]} service(s)"
