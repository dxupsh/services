#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$ROOT_DIR/services.tar.gz"

# Collect settings files
files=()
for f in "$ROOT_DIR"/release/*.json; do
  [ -f "$f" ] && files+=("$f")
done

if [ ${#files[@]} -eq 0 ]; then
  echo "Error: no release/*.json files found" >&2
  exit 1
fi

# Build archive in a temp directory
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/services"

for f in "${files[@]}"; do
  cp "$f" "$tmpdir/services/"
done

COPYFILE_DISABLE=1 tar -czf "$OUTPUT" -C "$tmpdir" services

echo "Created $OUTPUT with ${#files[@]} service(s)"
