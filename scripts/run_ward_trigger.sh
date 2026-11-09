#!/usr/bin/env bash
# Launches WardTrigger through LaunchServices so TCC attributes the prompt to
# com.gatekeepersward.ward-trigger itself instead of the invoking terminal
# (a terminal child process inherits the terminal's TCC decisions).
#
# Usage: scripts/run_ward_trigger.sh <subcommand> [extra demo args...]
# (run the binary with no arguments for the list of subcommands)
# Output is appended to ward-trigger.out in the per-user temp directory on the
# boot volume ($TMPDIR, i.e. /var/folders/…/T/) — stdout of an `open`-launched
# app is not connected to the terminal, and `open --stdout` rejects paths on
# external volumes such as /Volumes/Gold.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_PATH="$(cd "$REPO_ROOT" && swift build --show-bin-path)/WardTrigger"
APP_DIR="$REPO_ROOT/.build/WardTrigger.app"
OUT_LOG="${TMPDIR:-/tmp}"
OUT_LOG="${OUT_LOG%/}/ward-trigger.out"

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
	<key>NSDownloadsFolderUsageDescription</key>
	<string>WardTrigger lists the Downloads folder to trigger the Downloads folder TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSCalendarsUsageDescription</key>
	<string>WardTrigger requests Calendar access to trigger the Calendar TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSCalendarsFullAccessUsageDescription</key>
	<string>WardTrigger requests Calendar access to trigger the Calendar TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSRemindersUsageDescription</key>
	<string>WardTrigger requests Reminders access to trigger the Reminders TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSRemindersFullAccessUsageDescription</key>
	<string>WardTrigger requests Reminders access to trigger the Reminders TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>WardTrigger requests Photos access to trigger the Photos TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSCameraUsageDescription</key>
	<string>WardTrigger requests camera access to trigger the Camera TCC prompt for Gatekeeper's Ward testing.</string>
	<key>NSAppleEventsUsageDescription</key>
	<string>WardTrigger sends Finder a read-only Apple event to trigger the Automation TCC prompt for Gatekeeper's Ward testing.</string>
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

# Each run appends to $OUT_LOG (reset_ward_trigger.sh clears it), starting with
# a header so runs can be told apart.
printf '\n=== %s  WardTrigger %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$OUT_LOG"
# -n forces a fresh instance (an instance suspended on a pending TCC dialog
# would otherwise swallow the new arguments). The app writes straight to
# $OUT_LOG (`open --stdout` appends), so there is no background relay to race
# or get killed.
open --stdout "$OUT_LOG" --stderr "$OUT_LOG" -n "$APP_DIR" --args "$@"

echo "[run_trigger] launched WardTrigger via LaunchServices."
echo "[run_trigger] stdout/stderr: $OUT_LOG"
echo "[run_trigger] check it with: cat \"$OUT_LOG\" (scripts/reset_ward_trigger.sh removes it)"
