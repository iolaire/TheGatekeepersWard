#!/usr/bin/env bash
# Ward process control for the permission capture framework: detect, start,
# stop, Marker_File handling, menu bar detection, commit recording.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Requires CAPTURE_REPO_ROOT (set by capture.sh). Sources common.sh and
# windows.sh (match_ward_item, poll_window).

_WARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
. "$_WARD_LIB_DIR/common.sh"
# shellcheck source=windows.sh
. "$_WARD_LIB_DIR/windows.sh"

WARD_PROCESS_PATTERN="GatekeepersWard.app/Contents/MacOS/GatekeepersWardApp"
: "${CAPTURE_WARD_MENUBAR_TIMEOUT:=10}"
: "${CAPTURE_WARD_STOP_TIMEOUT:=5}"

# _ward_repo: repository root.
_ward_repo() {
  printf '%s\n' "${CAPTURE_REPO_ROOT:-$(cd "$_WARD_LIB_DIR/../../.." && pwd)}"
}

# ward_marker_file: path of the Marker_File (ward.pid in the state directory).
ward_marker_file() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-$(_ward_repo)/captures/.state}/ward.pid"
}

# ward_pids: PIDs of running Ward processes, one per line (empty if none).
ward_pids() {
  pgrep -f "$WARD_PROCESS_PATTERN" 2>/dev/null || true
}

# ward_commit
# Prints `git rev-parse HEAD` of the checkout when it is 40 lowercase hex
# characters, otherwise "unknown". (When an already running Ward is reused this
# is the checkout HEAD, which may differ from the running build.)
ward_commit() {
  local sha
  sha="$(git -C "$(_ward_repo)" rev-parse HEAD 2>/dev/null)" || sha=""
  if printf '%s' "$sha" | grep -Eq '^[0-9a-f]{40}$'; then
    printf '%s\n' "$sha"
  else
    echo unknown
  fi
}

# _ward_kill pid
# SIGTERM, wait up to CAPTURE_WARD_STOP_TIMEOUT seconds, then SIGKILL.
_ward_kill() {
  local pid="$1" waited=0 limit=$(( CAPTURE_WARD_STOP_TIMEOUT * 10 ))
  kill -TERM "$pid" 2>/dev/null || return 0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge "$limit" ]; then
      kill -KILL "$pid" 2>/dev/null || true
      break
    fi
    sleep 0.1
    waited=$(( waited + 1 ))
  done
  return 0
}

# ward_stop_if_marked
# If the Marker_File exists, stop the PID it names and delete it. Never touches
# a Ward the framework did not start (no Marker_File, nothing happens).
ward_stop_if_marked() {
  local marker pid
  marker="$(ward_marker_file)"
  [ -f "$marker" ] || return 0
  pid="$(head -n 1 "$marker" 2>/dev/null)"
  if printf '%s' "$pid" | grep -Eq '^[0-9]+$'; then
    _ward_kill "$pid"
  fi
  rm -f "$marker"
  return 0
}

# ward_ensure mode
# mode "baseline": fail (return 1, PID on stderr) if any Ward process exists.
# mode "ward": reuse a running Ward without writing a Marker_File; otherwise run
# scripts/run_ward.sh, take the newest PID, write the Marker_File, and wait up
# to 10 s for the menu bar item (see ward_wait_ready). On timeout stop the Ward it started, delete the
# Marker_File, and return 1.
ward_ensure() {
  local mode="${1:-ward}" pids pid marker
  pids="$(ward_pids | tr '\n' ' ')"
  pids="${pids% }"

  if [ "$mode" = "baseline" ]; then
    if [ -n "$pids" ]; then
      printf '%s\n' "Ward is running (PID $pids); stop it before a baseline run" >&2
      return 1
    fi
    return 0
  fi

  if [ -n "$pids" ]; then
    log_step "ward: reusing running Ward (PID $pids), no Marker_File"
    return 0
  fi

  ext "$(_ward_repo)/scripts/run_ward.sh" || {
    printf '%s\n' "scripts/run_ward.sh failed" >&2
    return 1
  }
  [ "$CAPTURE_DRY_RUN" = "1" ] && return 0

  pid="$(pgrep -n -f "$WARD_PROCESS_PATTERN" 2>/dev/null || true)"
  if [ -z "$pid" ]; then
    printf '%s\n' "Ward process not found after run_ward.sh" >&2
    return 1
  fi

  marker="$(ward_marker_file)"
  mkdir -p "$(dirname "$marker")" || return 1
  printf '%s\n' "$pid" >"$marker"

  if ! ward_wait_ready "$CAPTURE_WARD_MENUBAR_TIMEOUT"; then
    printf '%s\n' "Ward menu bar item not found within ${CAPTURE_WARD_MENUBAR_TIMEOUT}s" >&2
    ward_stop_if_marked
    return 1
  fi
  return 0
}

# ward_wait_ready seconds
# Returns 0 as soon as the Ward's menu bar item is in the on-screen window list
# or, where the system draws status items itself (macOS 26 and later), a Ward
# window of any layer is registered. Returns 1 at the timeout.
ward_wait_ready() {
  local deadline=$((SECONDS + $1))
  while :; do
    if [ -n "$(windows_list 2>/dev/null | match_ward_item)" ] ||
      [ -n "$(windows_list_all 2>/dev/null | match_ward_registered)" ]; then
      return 0
    fi
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep 0.25
  done
}
