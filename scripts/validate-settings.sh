#!/usr/bin/env bash
# Validate all services/**/settings.json against the JSON schema.
# Exits non-zero if any file fails validation.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA="$ROOT_DIR/settings.schema.json"

if [ ! -f "$SCHEMA" ]; then
  echo "error: schema not found at $SCHEMA" >&2
  exit 1
fi

files=("$ROOT_DIR"/services/*/settings.json)

if [ ${#files[@]} -eq 0 ]; then
  echo "error: no settings.json files found" >&2
  exit 1
fi

yajsv -s "$SCHEMA" "${files[@]}"
