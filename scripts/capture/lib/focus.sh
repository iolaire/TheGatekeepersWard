#!/usr/bin/env bash
# --redact-notifications support: save, enable and restore the Focus state.
# bash 3.2 compatible. Meant to be sourced, not executed.
# Fails closed: when the state cannot be read or set, focus_enable returns 1
# with a message and the caller must stop before the first Scenario.
#
# Environment:
#   CAPTURE_STATE_DIR     state directory (default <repo>/captures/.state)
#   CAPTURE_FOCUS_SCRIPT  AppleScript path (default lib/focus.applescript)
_FOCUS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$_FOCUS_LIB_DIR/common.sh"
# _focus_state_file: path of the saved Focus state.
_focus_state_file() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$_FOCUS_LIB_DIR/../../.." && pwd)}/captures/.state}/focus-state"
}
# _focus_run args...: runs focus.applescript, prints its output.
_focus_run() {
  osascript "${CAPTURE_FOCUS_SCRIPT:-$_FOCUS_LIB_DIR/focus.applescript}" "$@"
}
# focus_read: prints "on" or "off". Returns 1 for anything else.
focus_read() {
  local out
  out="$(_focus_run read 2>/dev/null)" || return 1
  case "$out" in on | off) printf '%s\n' "$out" ;; *) return 1 ;; esac
}
# focus_enable: saves the current state, then turns Focus on.
# Keeps an existing saved state (left by a crashed run) so the original value
# is never overwritten by "on". In dry-run mode prints the planned commands.
focus_enable() {
  local file prior
  file="$(_focus_state_file)"
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "${CAPTURE_FOCUS_SCRIPT:-$_FOCUS_LIB_DIR/focus.applescript}" read
    printf '+ save state to %s\n' "$file"
    ext osascript "${CAPTURE_FOCUS_SCRIPT:-$_FOCUS_LIB_DIR/focus.applescript}" set on
    return 0
  fi
  if [ -f "$file" ]; then
    prior="$(cat "$file")"
  else
    prior="$(focus_read)" || {
      printf '%s\n' "--redact-notifications: cannot read the Focus state (Control Center UI not scriptable or Accessibility not granted). Aborting before any capture." >&2
      return 1
    }
    mkdir -p "$(dirname "$file")" && printf '%s\n' "$prior" >"$file" || {
      printf '%s\n' "--redact-notifications: cannot save the Focus state to $file" >&2
      return 1
    }
  fi
  if ! _focus_run set on >/dev/null 2>&1; then
    printf '%s\n' "--redact-notifications: cannot turn Focus on. Aborting before any capture." >&2
    # Best effort return to the original state; keep the file if that fails.
    if _focus_run set "$prior" >/dev/null 2>&1; then rm -f "$file"; fi
    return 1
  fi
  return 0
}
# focus_restore: puts the saved state back and removes the state file.
# No saved state is a no-op (returns 0). Idempotent. Returns 1 and keeps the
# file when the restore fails, so a later cleanup can retry.
focus_restore() {
  local file saved
  file="$(_focus_state_file)"
  [ -f "$file" ] || return 0
  saved="$(cat "$file")"
  case "$saved" in
    on | off) ;;
    *)
      rm -f "$file"
      printf '%s\n' "focus-state held an invalid value; removed it, check Focus manually" >&2
      return 1
      ;;
  esac
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "${CAPTURE_FOCUS_SCRIPT:-$_FOCUS_LIB_DIR/focus.applescript}" set "$saved"
    return 0
  fi
  if _focus_run set "$saved" >/dev/null 2>&1; then
    rm -f "$file"
    return 0
  fi
  printf '%s\n' "cannot restore Focus to '$saved'; set it manually. State kept in $file" >&2
  return 1
}
