#!/usr/bin/env bash
# Scoped TCC reset: bundle-ID guard, reset plan, reset execution.
# Only `tccutil` touches TCC state. Never the TCC database, never bundle ID All.
# bash 3.2 compatible: no associative arrays, no mapfile, no ${var,,}.
# Meant to be sourced, not executed.

# guard_bundle_id id known_ids...
# Pure. Returns 0 only when id is non-empty, is not "All" in any letter case,
# and equals one of known_ids exactly. Otherwise prints
# "refusing tccutil reset for bundle id '<id>'" to stderr and returns 1.
guard_bundle_id() {
  local id="${1-}" lower known
  shift || true
  lower="$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]')"
  if [ -n "$id" ] && [ "$lower" != "all" ]; then
    for known in "$@"; do
      if [ "$id" = "$known" ]; then
        return 0
      fi
    done
  fi
  printf "refusing tccutil reset for bundle id '%s'\n" "$id" >&2
  return 1
}

# reset_plan profile [--service s]
# Pure. Prints one "tccutil reset <service> <bundle>" line per planned command:
# every service the profile lists, in order, or only s. Returns 2 with a message
# naming s and the valid services when s is not listed.
reset_plan() {
  local profile="$1" service="" bundle svc services="" found=0
  shift
  if [ "${1-}" = "--service" ]; then
    service="${2-}"
  fi
  bundle="$(profile_field "$profile" bundle_id)" || return 2
  while IFS= read -r svc; do
    [ -n "$svc" ] || continue
    services="${services:+$services, }$svc"
    if [ -z "$service" ] || [ "$svc" = "$service" ]; then
      found=1
    fi
  done <<EOF
$(profile_services "$profile")
EOF
  if [ -n "$service" ]; then
    if ! profile_services "$profile" | grep -Fxq -- "$service"; then
      printf "invalid service '%s'; profile lists: %s\n" "$service" "$services" >&2
      return 2
    fi
    printf 'tccutil reset %s %s\n' "$service" "$bundle"
    return 0
  fi
  [ "$found" -eq 1 ] || return 0
  while IFS= read -r svc; do
    [ -n "$svc" ] || continue
    printf 'tccutil reset %s %s\n' "$svc" "$bundle"
  done <<EOF
$(profile_services "$profile")
EOF
}

# _reset_known_ids: bundle IDs declared by every loaded profile, one per line.
_reset_known_ids() {
  local f
  if [ "${#CAPTURE_PROFILE_FILES[@]}" -eq 0 ]; then
    profile_load_all "$(profile_dir)" >/dev/null 2>&1 || true
  fi
  for f in ${CAPTURE_PROFILE_FILES[@]+"${CAPTURE_PROFILE_FILES[@]}"}; do
    profile_field "$f" bundle_id
    echo
  done
}

# reset_run profile [--service s] [--dry-run]
# Guards every planned command before running any. Runs each through ext and
# prints "<command> -> exit <n>", continuing after a failure. Returns non-zero
# if any command failed. With --dry-run prints the plan, runs nothing, returns 0.
reset_run() {
  local profile="$1" service="" CAPTURE_DRY_RUN="${CAPTURE_DRY_RUN:-0}"
  local plan rc=0 failed=0 line svc bundle known out ids
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --service) service="${2-}"; shift ;;
      --dry-run) CAPTURE_DRY_RUN=1 ;;
      *) echo "reset: unknown argument '$1'" >&2; return 2 ;;
    esac
    shift
  done
  if [ -n "$service" ]; then
    plan="$(reset_plan "$profile" --service "$service")" || return 2
  else
    plan="$(reset_plan "$profile")" || return 2
  fi
  ids="$(_reset_known_ids)"
  # Guard every command first; run nothing if any is refused.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    read -r _ _ svc bundle <<EOF
$line
EOF
    known=()
    while IFS= read -r out; do
      [ -n "$out" ] && known+=("$out")
    done <<EOF
$ids
EOF
    guard_bundle_id "$bundle" ${known[@]+"${known[@]}"} || return 1
  done <<EOF
$plan
EOF
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    read -r _ _ svc bundle <<EOF
$line
EOF
    if [ "$CAPTURE_DRY_RUN" = "1" ]; then
      ext tccutil reset "$svc" "$bundle"
      continue
    fi
    rc=0
    out="$(ext tccutil reset "$svc" "$bundle" 2>&1)" || rc=$?
    printf '%s -> exit %s\n' "$(quote_cmd tccutil reset "$svc" "$bundle")" "$rc"
    if [ "$rc" -ne 0 ]; then
      failed=1
      [ -z "$out" ] || printf '%s\n' "$out" >&2
    fi
  done <<EOF
$plan
EOF
  return "$failed"
}

# cmd_reset profile [--service s] [--dry-run]: options already parsed by capture.sh.
cmd_reset() {
  local profile="${1-}" rc=0
  [ -n "$profile" ] || die "$EXIT_USAGE" "usage: capture.sh reset <profile> [--service <svc>] [--dry-run]"
  profile_load_all "$(profile_dir)" || exit "$EXIT_USAGE"
  [ -f "$(profile_file "$profile")" ] || die "$EXIT_USAGE" "unknown profile: $profile"
  # Snapshot before the first tccutil call; a failure runs no tccutil (15.7).
  # The snapshot stays pending afterwards: `capture.sh restore` undoes it (D14).
  if declare -F tcc_ensure_snapshot >/dev/null 2>&1; then
    tcc_ensure_snapshot "$profile" "$(date -u +%Y%m%dT%H%M%SZ)" || exit "$EXIT_FAIL"
    if ! { declare -F _restore_disabled >/dev/null 2>&1 && _restore_disabled; }; then
      printf 'tcc-snapshot: %s (left pending; run capture.sh restore to undo)\n' "$(profile_field "$profile" bundle_id)"
    fi
  fi
  if [ -n "${OPT_SERVICE:-}" ]; then
    reset_run "$profile" --service "$OPT_SERVICE" || rc=$?
  else
    reset_run "$profile" || rc=$?
  fi
  [ "$rc" -eq 0 ] || exit "$rc"
}
