#!/usr/bin/env bash
# Headless Godot web export for this project (no GPU needed).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-${PROJECT_DIR}/export/web/index.html}"
PRESET="${GODOT_PRESET:-Web}"

GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
    if command -v godot >/dev/null 2>&1; then
        GODOT="godot"
    elif [ -x "$HOME/bin/godot" ]; then
        GODOT="$HOME/bin/godot"
    elif [ -x /usr/local/bin/godot ]; then
        GODOT="/usr/local/bin/godot"
    else
        echo "ERROR: godot binary not found. Install it with:" >&2
        echo "  /home/debian/Programming/mtgfyn/scripts/install-godot-headless.sh" >&2
        exit 1
    fi
fi

if [ ! -f "${PROJECT_DIR}/project.godot" ]; then
    echo "ERROR: no project.godot at ${PROJECT_DIR}" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"

echo ">> Godot: $("$GODOT" --version 2>&1 || echo unknown)"
echo ">> Project: ${PROJECT_DIR}"
echo ">> Preset:  ${PRESET}"
echo ">> Output:  ${OUT}"

"$GODOT" --headless --path "$PROJECT_DIR" --export-release "$PRESET" "$OUT"

echo ">> Exported OK"
