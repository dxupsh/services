#!/usr/bin/env bash
# Extract NixOS options for all services listed in services.txt
# Usage: ./scripts/extract-options.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICES_FILE="${ROOT_DIR}/services.txt"
OUTPUT_DIR="${ROOT_DIR}/definitions"
NIX_FILE="${SCRIPT_DIR}/extract-options.nix"

echo "=== NixOS Service Options Extractor ==="
echo "Output directory: ${OUTPUT_DIR}"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Count services
TOTAL=$(wc -l < "${SERVICES_FILE}" | tr -d ' ')
CURRENT=0
SUCCESS=0
FAILED=0

# Process each service
while IFS= read -r service || [[ -n "$service" ]]; do
    # Skip empty lines
    [[ -z "$service" ]] && continue

    CURRENT=$((CURRENT + 1))
    mkdir -p "${OUTPUT_DIR}/${service}"
    OUTPUT_FILE="${OUTPUT_DIR}/${service}/defaults.json"

    printf "[%2d/%2d] Extracting %-30s ... " "$CURRENT" "$TOTAL" "$service"

    if nix eval --json \
        --apply "f: f { serviceName = \"$service\"; }" \
        --file "$NIX_FILE" 2>/dev/null | jq --arg svc "$service" '{service: $svc} + .' > "$OUTPUT_FILE"; then

        # Check if extraction had an error (metadata.error field exists and is not null)
        ERROR_MSG=$(jq -r '.metadata.error // empty' "$OUTPUT_FILE" 2>/dev/null)
        if [[ -n "$ERROR_MSG" ]]; then
            echo "WARNING (${ERROR_MSG})"
            FAILED=$((FAILED + 1))
        else
            echo "OK"
            SUCCESS=$((SUCCESS + 1))
        fi
    else
        # Create empty error JSON
        cat > "$OUTPUT_FILE" <<EOF
{
  "service": "${service}",
  "metadata": {
    "nixpkgsRevision": "unknown",
    "error": "Extraction failed"
  },
  "package": null,
  "settings": {}
}
EOF
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done < "${SERVICES_FILE}"

echo ""
echo "=== Summary ==="
echo "Total:   ${TOTAL}"
echo "Success: ${SUCCESS}"
echo "Failed:  ${FAILED}"
echo ""
echo "Output files in: ${OUTPUT_DIR}/"
