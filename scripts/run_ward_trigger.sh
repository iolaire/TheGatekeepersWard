#!/usr/bin/env bash
# Launches WardTrigger through LaunchServices so TCC attributes the prompt to
# com.gatekeepersward.ward-trigger itself instead of the invoking terminal
# (a terminal child process inherits the terminal's TCC decisions).
#
# Usage: scripts/run_ward_trigger.sh <docs|contacts|mic> [extra demo args...]
# Output is captured to tmp/ward-trigger.out in the repository (staged on the
# system temp dir and relayed — stdout of an `open`-launched app is not
# connected to the terminal).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$(cd "$REPO_ROOT" && swift build --show-bin-path)/WardTrigger"
APP_DIR="$REPO_ROOT/.build/WardTrigger.app"
OUT_LOG="$REPO_ROOT/tmp/ward-trigger.out"
# `open --stdout` refuses paths on external volumes (LS error -10810), so the
# app writes to the system temp dir and a watcher relays it to $OUT_LOG below.
STAGE_LOG="${TMPDIR:-/tmp}/ward-trigger-stage.out"

if [ ! -x "$BIN_PATH" ]; then
    echo "[run_trigger] WardTrigger binary not found at $BIN_PATH — run `swift build` first." >&2
    exit 1
fi

# Assemble/refresh the minimal app wrapper. The bundle's CFBundleIdentifier
# matches the ID embedded in the binary, so `tccutil reset` scoping works.
mkdir -p "$APP_DIR/Contents/MacOS"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>com.gatekeepersward.ward-trigger</string>
	<key>CFBundleName</key>
	<string>WardTrigger</string>
	<key>CFBundleExecutable</key>
	<string>WardTrigger</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>NSDocumentsFolderUsageDescription</key>
	<string>WardTrigger probes the Documents canary file to trigger the Documents folder TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSDesktopFolderUsageDescription</key>
	<string>WardTrigger is reset via tccutil for repeatable Desktop folder TCC prompts during Gatekeeper's Ward testing.</string>
	<key>NSContactsUsageDescription</key>
	<string>WardTrigger requests Contacts access to trigger the Contacts TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>WardTrigger requests microphone access to trigger the Microphone TCC prompt for Gatekeeper's Ward testing.</string>
	<key>LSUIElement</key>
	<false/>
</dict>
</plist>
PLIST
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/WardTrigger"
# Seal the bundle (ad-hoc). tccd will not show TCC prompts for a bundle whose
# resources are not code-sealed — it silently denies instead.
codesign --force --sign - "$APP_DIR" 2>/dev/null || true

mkdir -p "$(dirname "$OUT_LOG")"
rm -f "$STAGE_LOG"
# -n forces a fresh instance (an instance suspended on a pending TCC dialog
# would otherwise swallow the new arguments).
open --stdout "$STAGE_LOG" --stderr "$STAGE_LOG" -n "$APP_DIR" --args "$@"

# Relay the staged output into the repo's tmp/ while the process runs and one
# final time after it exits.
(
    while pgrep -f "WardTrigger.app/Contents/MacOS/WardTrigger" > /dev/null 2>&1; do
        cp "$STAGE_LOG" "$OUT_LOG" 2>/dev/null || true
        sleep 1
    done
    cp "$STAGE_LOG" "$OUT_LOG" 2>/dev/null || true
) &

echo "[run_trigger] launched WardTrigger via LaunchServices."
echo "[run_trigger] stdout/stderr: $OUT_LOG"
echo "[run_trigger] check it with: cat \"$OUT_LOG\" (scripts/reset_ward_trigger.sh removes it)"
