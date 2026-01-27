#!/usr/bin/env bash
# Build the complete settings pipeline: extract, merge, package.
# Usage: ./scripts/build-settings.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Build Settings Pipeline ==="
echo ""

echo "--- Step 1/3: Extract options ---"
"$SCRIPT_DIR/extract-options.sh"

echo "--- Step 2/3: Merge settings ---"
"$SCRIPT_DIR/merge-settings.sh"

echo "--- Step 3/3: Package settings ---"
"$SCRIPT_DIR/package-settings.sh"

echo ""
echo "=== Build Settings Complete ==="
