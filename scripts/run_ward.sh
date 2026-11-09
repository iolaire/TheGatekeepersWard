#!/usr/bin/env bash
# Builds Gatekeeper's Ward, wraps it in .build/GatekeepersWard.app, signs it
# ad hoc, and launches it as a menu bar app (no Dock icon).
#
# Usage: scripts/run_ward.sh          # build + launch
#        scripts/run_ward.sh --stop   # quit a running copy
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO_ROOT/.build/GatekeepersWard.app"
EXE_PATTERN="GatekeepersWard.app/Contents/MacOS/GatekeepersWardApp"

if [ "${1:-}" = "--stop" ]; then
    pkill -f "$EXE_PATTERN" && echo "[run_ward] stopped." || echo "[run_ward] not running."
    exit 0
fi

cd "$REPO_ROOT"
swift build --product GatekeepersWardApp
BIN_PATH="$(swift build --show-bin-path)/GatekeepersWardApp"

# Replace any running copy so the new build is what you see.
pkill -f "$EXE_PATTERN" 2>/dev/null || true

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$REPO_ROOT/GatekeepersWardApp/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/GatekeepersWardApp"

# Fail loudly: on exFAT/FAT drives macOS adds ._ files that break signing.
if ! codesign --force --sign - "$APP_DIR" 2>/tmp/run_ward_codesign.err; then
    echo "[run_ward] codesign failed:" >&2
    cat /tmp/run_ward_codesign.err >&2
    echo "[run_ward] If the repo is on an exFAT drive, move it to the internal disk." >&2
    exit 1
fi

open -n "$APP_DIR"
echo "[run_ward] launched. Look for the ghost in the menu bar."
echo "[run_ward] trigger a prompt with: scripts/run_ward_trigger.sh docs"
echo "[run_ward] quit with: scripts/run_ward.sh --stop"
