#!/usr/bin/env bash
# Shared by the stub binaries. Sourced, never executed directly.
# Appends one line per call to $STUB_CALL_LOG:
#   <name><TAB><arg1><TAB><arg2>...
# with backslash, tab and newline in each argument escaped as \\ \t \n.
# Canned behaviour comes from the environment:
#   STUB_<NAME>_OUT   text written to stdout
#   STUB_<NAME>_ERR   text written to stderr
#   STUB_<NAME>_EXIT  exit status (default 0)
stub_log_call() {
  local name="$1" line="$1" a
  shift
  for a in "$@"; do
    a="${a//\\/\\\\}"
    a="${a//$'\t'/\\t}"
    a="${a//$'\n'/\\n}"
    line="$line"$'\t'"$a"
  done
  [ -n "${STUB_CALL_LOG:-}" ] && printf '%s\n' "$line" >>"$STUB_CALL_LOG"
  return 0
}
# stub_finish NAME DEFAULT_OUT: print canned output and exit with canned status.
stub_finish() {
  local up out_var err_var exit_var
  up="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  out_var="STUB_${up}_OUT"
  err_var="STUB_${up}_ERR"
  exit_var="STUB_${up}_EXIT"
  if [ -n "${!out_var+x}" ]; then
    [ -n "${!out_var}" ] && printf '%s\n' "${!out_var}"
  elif [ -n "${2:-}" ]; then
    printf '%s\n' "$2"
  fi
  [ -n "${!err_var:-}" ] && printf '%s\n' "${!err_var}" >&2
  exit "${!exit_var:-0}"
}
