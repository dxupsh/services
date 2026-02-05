#!/usr/bin/env bash
# Merge defaults.json, overrides.json, and app.json into settings.json for each service.
# For overridden settings, replaces the "default" field with the override "value",
# discarding the "rationale". Includes app configuration sections from app.json.
# Usage: ./scripts/merge-settings.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFINITIONS_DIR="${ROOT_DIR}/definitions"
RELEASE_DIR="${ROOT_DIR}/release"

mkdir -p "${RELEASE_DIR}"

echo "=== Merge Service Settings ==="
echo ""

TOTAL=0
SUCCESS=0
SKIPPED=0
FAILED=0

for service_dir in "${DEFINITIONS_DIR}"/*/; do
    service="$(basename "$service_dir")"
    TOTAL=$((TOTAL + 1))

    DEFAULTS="${service_dir}defaults.json"
    OVERRIDES="${service_dir}overrides.json"
    APP="${service_dir}app.json"
    OUTPUT="${RELEASE_DIR}/${service}.json"

    printf "[%2d] Merging %-30s ... " "$TOTAL" "$service"

    # Skip if any required file is missing
    if [[ ! -f "$DEFAULTS" ]]; then
        echo "SKIP (no defaults.json)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ ! -f "$OVERRIDES" ]]; then
        echo "SKIP (no overrides.json)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [[ ! -f "$APP" ]]; then
        echo "SKIP (no app.json)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if jq -s '
        .[0] as $defaults |
        .[1].settings as $overrides |
        .[2] as $app |

        # Extract version from nixpkgsRevision (e.g., "25.11pre-git" -> "25.11")
        ($defaults.metadata.nixpkgsRevision | split("-")[0] | split("pre")[0]) as $nixver |

        {
            version: "1",
            service: $defaults.service,
            metadata: {
                sources: {
                    nixpkgs: ("github:nixos/nixpkgs/nixos-" + $nixver)
                }
            },
            package: (
                if $defaults.package then
                    $defaults.package + { source: "nixpkgs" }
                else
                    null
                end
            ),
            settings: (
                $defaults.settings | to_entries | map(
                    if $overrides[.key] then
                        .value.default = $overrides[.key].value
                    else
                        .
                    end
                ) | from_entries
            )
        }
        + (if $app.app then { app: $app.app } else {} end)
        + (if $app.secrets then { secrets: $app.secrets } else {} end)
        + (if $app.configFiles then { configFiles: $app.configFiles } else {} end)
        + (if $app.cmd then { cmd: $app.cmd } else {} end)
        + (if $app.dataVolume then { dataVolume: $app.dataVolume } else {} end)
        + (if $app.healthCheck then { healthCheck: $app.healthCheck } else {} end)
    ' "$DEFAULTS" "$OVERRIDES" "$APP" > "$OUTPUT"; then
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
echo "Skipped: ${SKIPPED}"
echo "Failed:  ${FAILED}"
echo ""
echo "Output files in: ${RELEASE_DIR}/"
