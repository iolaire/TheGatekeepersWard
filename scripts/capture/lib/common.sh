#!/usr/bin/env bash
# Shared helpers for the permission capture framework.
# bash 3.2 compatible: no associative arrays, no mapfile, no ${var,,}.
# Meant to be sourced, not executed.

# Exit codes (see design.md "Exit codes").
EXIT_OK=0
EXIT_FAIL=1
EXIT_USAGE=2
EXIT_SIGINT=130
EXIT_SIGTERM=143

# When "1", ext prints commands instead of running them.
: "${CAPTURE_DRY_RUN:=0}"

# quote_cmd args...
# Pure. Prints each argument shell-quoted (printf %q), separated by spaces,
# so that evaluating the output in bash yields the original argv.
quote_cmd() {
  local out="" arg
  for arg in "$@"; do
    local q
    q="$(printf '%q' "$arg")"
    # bash 3.2 leaves a leading "~" unescaped, so it would tilde-expand.
    case "$q" in "~"*) q="\\$q" ;; esac
    out="$out$q "
  done
  printf '%s\n' "${out% }"
}

# ext cmd args...
# The single choke point for side effects. In dry-run mode prints
# "+ <quoted command>" and returns 0 without running anything.
# Otherwise runs the command with each argument as one argv element.
ext() {
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    printf '+ %s\n' "$(quote_cmd "$@")"
    return 0
  fi
  "$@"
}

# utc_now_s: UTC ISO-8601 with seconds, e.g. 2026-11-20T15:30:45Z.
utc_now_s() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# utc_now_ms: UTC ISO-8601 with milliseconds. macOS date has no %N, so ask JXA.
utc_now_ms() {
  osascript -l JavaScript -e 'new Date().toISOString()'
}

# log_step name
# Prints "<UTC timestamp> step: <name>" and appends the same line to
# $SESSION_DIR/capture.log. The file write is skipped in dry-run mode and when
# SESSION_DIR is unset or not a directory.
log_step() {
  local line
  line="$(utc_now_s) step: $1"
  printf '%s\n' "$line"
  if [ "$CAPTURE_DRY_RUN" != "1" ] && [ -n "${SESSION_DIR:-}" ] && [ -d "$SESSION_DIR" ]; then
    printf '%s\n' "$line" >>"$SESSION_DIR/capture.log"
  fi
}

# die code msg
# Writes msg to stderr and exits with code.
die() {
  local code="$1"
  shift
  printf '%s\n' "$*" >&2
  exit "$code"
}
