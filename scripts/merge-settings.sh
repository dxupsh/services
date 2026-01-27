#!/usr/bin/env bash
# Merge defaults.json and overrides.json into settings.json for each service.
# For overridden settings, replaces the "default" field with the override "value",
# discarding the "rationale".
# Usage: ./scripts/merge-settings.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICES_DIR="${ROOT_DIR}/services"

echo "=== Merge Service Settings ==="
echo ""

TOTAL=0
SUCCESS=0
FAILED=0

for service_dir in "${SERVICES_DIR}"/*/; do
    service="$(basename "$service_dir")"
    TOTAL=$((TOTAL + 1))

    DEFAULTS="${service_dir}defaults.json"
    OVERRIDES="${service_dir}overrides.json"
    OUTPUT="${service_dir}settings.json"

    printf "[%2d] Merging %-30s ... " "$TOTAL" "$service"

    if [[ ! -f "$DEFAULTS" ]]; then
        echo "SKIP (no defaults.json)"
        FAILED=$((FAILED + 1))
        continue
    fi

    if [[ ! -f "$OVERRIDES" ]]; then
        echo "SKIP (no overrides.json)"
        FAILED=$((FAILED + 1))
        continue
    fi

    if jq -s '
        .[0] as $defaults |
        .[1].settings as $overrides |
        $defaults |
        .settings |= (
            to_entries | map(
                if $overrides[.key] then
                    .value.default = $overrides[.key].value
                else
                    .
                end
            ) | from_entries
        )
    ' "$DEFAULTS" "$OVERRIDES" > "$OUTPUT"; then
        OVERRIDDEN=$(jq '.settings | length' "$OVERRIDES")
        echo "OK (${OVERRIDDEN} overrides applied)"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== Summary ==="
echo "Total:   ${TOTAL}"
echo "Success: ${SUCCESS}"
echo "Failed:  ${FAILED}"
echo ""
echo "Output files in: ${SERVICES_DIR}/"
