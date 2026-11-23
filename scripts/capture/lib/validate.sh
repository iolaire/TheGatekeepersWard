#!/usr/bin/env bash
# Pure option validators for the capture framework. No I/O, no side effects.
# bash 3.2 compatible. Meant to be sourced, not executed.

# Documented defaults and ranges (seconds unless noted).
CAPTURE_DEFAULT_LAUNCH_TIMEOUT=20
CAPTURE_DEFAULT_PROMPT_TIMEOUT=45
CAPTURE_DEFAULT_DWELL=4
CAPTURE_DEFAULT_RESOLVE=deny
CAPTURE_DEFAULT_DISPLAY=1   # main display
CAPTURE_TIMEOUT_MIN=1
CAPTURE_TIMEOUT_MAX=300
CAPTURE_DWELL_MIN=1
CAPTURE_DWELL_MAX=60

# _valid_uint v
# Returns 0 when v is 1 to 18 ASCII digits only (no sign, spaces, or newline).
_valid_uint() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "${#1}" -le 18 ]
}

# valid_resolve v
# Returns 0 only for exactly allow, deny, or none.
valid_resolve() {
  case "$1" in
    allow|deny|none) return 0 ;;
  esac
  return 1
}

# valid_range v lo hi
# Returns 0 when v is an unsigned decimal integer with lo <= v <= hi.
valid_range() {
  _valid_uint "$1" || return 1
  [ "$#" -eq 3 ] || return 1
  _valid_uint "$2" || return 1
  _valid_uint "$3" || return 1
  [ "$((10#$1))" -ge "$((10#$2))" ] && [ "$((10#$1))" -le "$((10#$3))" ]
}

# valid_display idx count
# Returns 0 when idx is a decimal integer with 1 <= idx <= count.
valid_display() {
  [ "$#" -eq 2 ] || return 1
  _valid_uint "$2" || return 1
  valid_range "$1" 1 "$2"
}

# with_default v dflt
# Prints v when non-empty, otherwise dflt.
with_default() {
  if [ -n "$1" ]; then
    printf '%s\n' "$1"
  else
    printf '%s\n' "$2"
  fi
}
