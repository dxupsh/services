#!/usr/bin/env bash
# Build the complete settings pipeline: extract, merge, validate, package.
# Usage: ./scripts/build-settings.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Build Settings Pipeline ==="
echo ""

echo "--- Step 1/4: Extract options ---"
"$SCRIPT_DIR/extract-options.sh"

echo "--- Step 2/4: Merge settings ---"
"$SCRIPT_DIR/merge-settings.sh"

echo "--- Step 3/4: Validate settings ---"
"$SCRIPT_DIR/validate-settings.sh"

echo "--- Step 4/4: Package settings ---"
"$SCRIPT_DIR/package-settings.sh"

echo ""
echo "=== Build Settings Complete ==="
