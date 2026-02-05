# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

NixOS service configuration extractor for dxup. Extracts service options from NixOS, merges with manual overrides, validates against a JSON schema, and packages the result for release.

## Build Commands

```bash
bash scripts/build.sh              # Full pipeline: extract → merge → package
bash scripts/extract-options.sh    # Extract NixOS options → definitions/*/defaults.json
bash scripts/merge-settings.sh     # Merge defaults + overrides → release/*.json
bash scripts/package-settings.sh   # Package into services.tar.gz
bash scripts/validate-settings.sh  # Validate release/*.json against settings.schema.json
nixfmt *.nix                       # Format Nix files
```

## Architecture

The pipeline processes 29 services listed in `services.txt`:

1. **Extract** (`extract-options.sh` + `extract-options.nix`): Evaluates NixOS modules via `nix eval` to produce `definitions/*/defaults.json` per service. Maps service names where needed (e.g. `postgres` → `postgresql`, `kafka` → `apache-kafka`). Fetches nixpkgs from `nixos-25.11`.

2. **Merge** (`merge-settings.sh`): Combines `defaults.json` with hand-written `overrides.json` and `app.json` using `jq`. Outputs to `release/*.json`. Overrides replace the `default` field of matched settings.

3. **Package** (`package-settings.sh`): Archives all `release/*.json` into `services.tar.gz` (as `services/{name}.json`).

4. **Validate** (`validate-settings.sh`): Checks every `release/*.json` against `settings.schema.json` using `yajsv`.

### File structure

```
definitions/{name}/
├── defaults.json    # Auto-generated from NixOS (do not edit)
├── overrides.json   # Manual overrides with value + rationale
└── app.json         # Manual app config (optional)

release/{name}.json  # Final computed settings (auto-generated, do not edit)
```

Only `overrides.json` and `app.json` files should be edited by hand. Both `defaults.json` and `release/*.json` are generated artifacts.

### CI/CD

- **update-services.yml**: Runs daily at 00:30 UTC. Extracts, merges, validates, and commits changes.
- **publish.yml**: Runs daily at 01:00 UTC. Creates a tagged release (`v{date}-{sha}`) with `services.tar.gz` if there are new commits.
