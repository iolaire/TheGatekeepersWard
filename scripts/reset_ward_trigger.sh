#!/usr/bin/env bash
# Clears all TCC decisions scoped to WardTrigger's bundle identifier so the
# next invocation of WardTrigger replays a first-prompt condition.
set -euo pipefail

BUNDLE_ID="com.gatekeepersward.ward-trigger"

for SERVICE in SystemPolicyDocumentsFolder SystemPolicyDesktopFolder \
               SystemPolicyDownloadsFolder AddressBook Calendar Reminders \
               Photos Camera Microphone AppleEvents ScreenCapture; do
    tccutil reset "$SERVICE" "$BUNDLE_ID" || true
done

echo "[reset_trigger] TCC permissions cleared for $BUNDLE_ID."
echo "[reset_trigger] Next invocation of WardTrigger will prompt."

# Clean up the launcher's captured output (recreates a pristine demo state).
TMP_DIR="${TMPDIR:-/tmp}"
rm -f "${TMP_DIR%/}/ward-trigger.out"
