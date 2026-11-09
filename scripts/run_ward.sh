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
    if ! pkill -f "$EXE_PATTERN"; then
        echo "[run_ward] not running."
        exit 0
    fi
    # SIGTERM triggers a clean quit; confirm the process actually exits.
    for _ in $(seq 1 30); do
        pgrep -f "$EXE_PATTERN" >/dev/null || { echo "[run_ward] stopped."; exit 0; }
        sleep 0.1
    done
    echo "[run_ward] still running after 3 s; force-killing." >&2
    pkill -9 -f "$EXE_PATTERN" || true
    pkill -f "log stream --style ndjson --level info --predicate subsystem == \"com.apple.TCC\"" || true
    exit 1
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
