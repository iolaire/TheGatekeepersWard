#!/usr/bin/env bash
# Clears all TCC decisions scoped to WardTrigger's bundle identifier so the
# next invocation of WardTrigger replays a first-prompt condition.
set -euo pipefail

BUNDLE_ID="com.gatekeepersward.ward-trigger"

for SERVICE in SystemPolicyDocumentsFolder SystemPolicyDesktopFolder \
               AddressBook AppleEvents Microphone; do
    tccutil reset "$SERVICE" "$BUNDLE_ID" || true
done

echo "[reset_trigger] TCC permissions cleared for $BUNDLE_ID."
echo "[reset_trigger] Next invocation of WardTrigger will prompt."

# Clean up the launcher's captured output (recreates a pristine demo state).
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -f "$REPO_ROOT/tmp/ward-trigger.out"
rmdir "$REPO_ROOT/tmp" 2>/dev/null || true
