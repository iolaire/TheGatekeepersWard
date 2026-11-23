#!/usr/bin/env bash
# Teardown actions and signal traps for the permission capture framework.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# cleanup_all is idempotent and reads only the state directory
# (captures/.state), so it works from a fresh shell after a crash. Helpers in
# video.sh, ward.sh, app.sh, focus.sh and setup.sh are called only when
# defined (declare -F); missing libraries are sourced on demand.
#
# Test hooks: CAPTURE_STATE_DIR, CAPTURE_QUIT_TIMEOUT (default 10 seconds).

_CLEANUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
. "$_CLEANUP_LIB_DIR/common.sh"

: "${CAPTURE_QUIT_TIMEOUT:=10}"

# Set to 1 by the session runner while a Capture_Session is in progress and to
# 0 when it finishes normally. The EXIT trap cleans up only when it is 1.
CAPTURE_SESSION_ACTIVE="${CAPTURE_SESSION_ACTIVE:-0}"
_CLEANUP_RUNNING=0
_CLEANUP_RC=0

# _cleanup_state_dir: runtime state directory.
_cleanup_state_dir() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$_CLEANUP_LIB_DIR/../../.." && pwd)}/captures/.state}"
}

# _cleanup_has fn: true when the shell function fn is defined.
_cleanup_has() {
  declare -F "$1" >/dev/null 2>&1
}

# _cleanup_load_libs: source driver libraries that are not loaded yet.
_cleanup_load_libs() {
  local lib fn
  for lib in video:video_stop ward:ward_stop_if_marked app:_app_clipboard_restore \
    focus:focus_restore setup:perm_pane restore:restore_all; do
    fn="${lib#*:}"
    _cleanup_has "$fn" && continue
    # shellcheck disable=SC1090
    [ -f "$_CLEANUP_LIB_DIR/${lib%%:*}.sh" ] && . "$_CLEANUP_LIB_DIR/${lib%%:*}.sh" 2>/dev/null
  done
  return 0
}

# _cleanup_warn msg: print a warning and mark the cleanup as not clean.
_cleanup_warn() {
  printf '%s\n' "$*" >&2
  _CLEANUP_RC=1
}

# _cleanup_clipboard state: restore the pasteboard from clipboard.snap.
_cleanup_clipboard() {
  local snap="$1/clipboard.snap"
  [ -f "$snap" ] || return 0
  if _cleanup_has _app_clipboard_restore; then
    _app_clipboard_restore "$snap" || _CLEANUP_RC=1
  elif osascript -l JavaScript "$_CLEANUP_LIB_DIR/clipboard.js" restore "$snap" >/dev/null 2>&1; then
    rm -f "$snap"
  else
    _cleanup_warn "warning: could not restore clipboard from $snap"
  fi
  printf '%s\n' "teardown: clipboard restored"
}

# _cleanup_recorder state: stop the recorder and check the video is playable.
_cleanup_recorder() {
  local state="$1" file=""
  [ -f "$state/recorder.pid" ] || [ -f "$state/recorder.path" ] || return 0
  [ -f "$state/recorder.path" ] && file="$(cat "$state/recorder.path" 2>/dev/null)"
  if _cleanup_has video_stop; then
    video_stop "$file" >/dev/null || true
  else
    local pid
    pid="$(cat "$state/recorder.pid" 2>/dev/null)"
    case "$pid" in '' | *[!0-9]*) ;; *) kill -INT "$pid" 2>/dev/null || true ;; esac
  fi
  rm -f "$state/recorder.pid" "$state/recorder.path"
  printf '%s\n' "teardown: recorder stopped"
  [ -n "$file" ] || return 0
  if [ -s "$file" ] && _cleanup_has video_playable && video_playable "$file"; then
    printf '%s\n' "teardown: video playable: $file"
  else
    _cleanup_warn "warning: video file is unplayable or missing: $file"
  fi
}

# _cleanup_ward state: stop the Ward named in the Marker_File, then delete it.
_cleanup_ward() {
  local marker="$1/ward.pid"
  [ -f "$marker" ] || return 0
  if _cleanup_has ward_stop_if_marked; then
    ward_stop_if_marked
  else
    local pid
    pid="$(head -n 1 "$marker" 2>/dev/null)"
    case "$pid" in
      '' | *[!0-9]*) ;;
      *)
        if kill -TERM "$pid" 2>/dev/null; then
          local i=0
          while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
          kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
        fi
        ;;
    esac
  fi
  rm -f "$marker"
  printf '%s\n' "teardown: Ward stopped"
}

# _cleanup_app_running bundle: true when System Events lists the bundle ID.
_cleanup_app_running() {
  local out
  out="$(osascript -e 'on run argv' \
    -e 'tell application "System Events" to return (bundle identifier of every process) contains (item 1 of argv)' \
    -e 'end run' "$1" 2>/dev/null)" || return 1
  [ "$out" = "true" ]
}

# _cleanup_apps state: quit each app in launched.txt. Never force-kills.
_cleanup_apps() {
  local list="$1/launched.txt" bundle seen=" " waited limit
  [ -f "$list" ] || return 0
  while IFS= read -r bundle || [ -n "$bundle" ]; do
    case "$bundle" in '' | *[!A-Za-z0-9._-]*) continue ;; esac
    case "$seen" in *" $bundle "*) continue ;; esac
    seen="$seen$bundle "
    _cleanup_app_running "$bundle" || continue
    osascript -e 'on run argv' -e 'tell application id (item 1 of argv) to quit' \
      -e 'end run' "$bundle" >/dev/null 2>&1 || true
    waited=0
    limit=$((CAPTURE_QUIT_TIMEOUT * 2))
    while _cleanup_app_running "$bundle" && [ "$waited" -lt "$limit" ]; do
      sleep 0.5
      waited=$((waited + 1))
    done
    if _cleanup_app_running "$bundle"; then
      _cleanup_warn "warning: $bundle did not quit within ${CAPTURE_QUIT_TIMEOUT}s; left running"
    else
      printf '%s\n' "teardown: quit $bundle"
    fi
  done <"$list"
  rm -f "$list"
}

# _cleanup_pending: pending snapshot bundle IDs (empty when none or unknown).
_cleanup_pending() {
  _cleanup_has tcc_pending || return 0
  tcc_pending 2>/dev/null
}
# _cleanup_restore: restore every pending TCC snapshot. Runs after the apps
# quit and before the Focus restore; a failure marks the cleanup as not clean
# but never stops the later steps. restore_all prints the cause and backup path.
_cleanup_restore() {
  _cleanup_has restore_all || return 0
  if _cleanup_has _restore_disabled && _restore_disabled; then
    return 0
  fi
  [ -n "$(_cleanup_pending)" ] || return 0
  restore_all || {
    printf '%s\n' "teardown: TCC restore failed; the snapshot stays pending (run capture.sh restore)" >&2
    _CLEANUP_RC=1
  }
  return 0
}
# _cleanup_focus: restore the saved Focus state.
_cleanup_focus() {
  [ -f "$1/focus-state" ] || return 0
  if _cleanup_has focus_restore; then
    focus_restore || _CLEANUP_RC=1
    printf '%s\n' "teardown: Focus restore attempted"
  else
    _cleanup_warn "warning: cannot restore Focus; set it manually (state in $1/focus-state)"
  fi
}

# _cleanup_guidance state: one line per permission recorded as missing.
_cleanup_guidance() {
  local file="$1/setup.json" name val pane names
  [ -f "$file" ] || return 0
  names="${PERM_NAMES:-accessibility screen-recording automation-system-events automation-finder}"
  for name in $names; do
    val="$(sed -n -E "s/^[[:space:]]*\"$name\"[[:space:]]*:[[:space:]]*(true|false).*/\\1/p" "$file" | head -n 1)"
    [ "$val" = "false" ] || continue
    pane=""
    _cleanup_has perm_pane && pane="$(perm_pane "$name" 2>/dev/null)"
    printf 'revoke %s in System Settings: %s\n' "$name" "${pane:-Privacy & Security}"
  done
}

# _cleanup_anything state: true when any teardown input exists.
_cleanup_anything() {
  local f
  for f in ward.pid recorder.pid recorder.path launched.txt focus-state clipboard.snap setup.json; do
    [ -e "$1/$f" ] && return 0
  done
  return 1
}

# cleanup_all
# Idempotent. Runs every teardown action in design order. Returns 0 when all
# succeeded or nothing existed, 1 when any action reported a warning.
cleanup_all() {
  local state
  state="$(_cleanup_state_dir)"
  _CLEANUP_RC=0
  _cleanup_load_libs
  if ! _cleanup_anything "$state"; then
    if [ -z "$(_cleanup_pending)" ] || { _cleanup_has _restore_disabled && _restore_disabled; }; then
      printf '%s\n' "teardown: nothing needed to be torn down"
      return 0
    fi
    _cleanup_restore
    return "$_CLEANUP_RC"
  fi
  _cleanup_clipboard "$state"
  _cleanup_recorder "$state"
  _cleanup_ward "$state"
  _cleanup_apps "$state"
  _cleanup_restore
  _cleanup_focus "$state"
  _cleanup_guidance "$state"
  return "$_CLEANUP_RC"
}

# cmd_teardown: the `teardown` subcommand.
cmd_teardown() {
  cleanup_all
}

# _cleanup_on_signal code: run cleanup once, then exit with code.
_cleanup_on_signal() {
  local code="$1"
  trap '' INT TERM
  if [ "$_CLEANUP_RUNNING" != "1" ]; then
    _CLEANUP_RUNNING=1
    cleanup_all >&2 || true
  fi
  CAPTURE_SESSION_ACTIVE=0
  exit "$code"
}

# _cleanup_on_exit: EXIT trap; cleans up only an unfinished session.
_cleanup_on_exit() {
  local rc=$?
  if [ "$CAPTURE_SESSION_ACTIVE" = "1" ] && [ "$_CLEANUP_RUNNING" != "1" ]; then
    _CLEANUP_RUNNING=1
    cleanup_all >&2 || true
  fi
  return "$rc"
}

# install_cleanup_traps: INT -> exit 130, TERM -> exit 143, EXIT -> cleanup of
# an unfinished session.
install_cleanup_traps() {
  trap '_cleanup_on_signal 130' INT
  trap '_cleanup_on_signal 143' TERM
  trap '_cleanup_on_exit' EXIT
}
