#!/usr/bin/env bash
# Export (unless SKIP_EXPORT=1) then serve the Godot web build.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if [ "${SKIP_EXPORT:-0}" != "1" ]; then
    echo ">> Exporting Godot web build (set SKIP_EXPORT=1 to skip)..."
    if ! bash scripts/export.sh; then
        echo "!! Export failed. Serving existing build if one exists." >&2
    fi
fi

# Godot web exports require a secure context (HTTPS or localhost).
bash scripts/gen-cert.sh

exec node scripts/serve.mjs
