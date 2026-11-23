#!/usr/bin/env bash
# Run-level TCC snapshot and restore wiring: ensure a snapshot once per bundle
# per run, copy it into the session, restore pending snapshots, and the
# `restore` subcommand. The database itself is only reached through tccdb.sh.
# --no-restore is read from OPT_NO_RESTORE or CAPTURE_NO_RESTORE ("1").
# bash 3.2 compatible: no associative arrays, no mapfile, no ${var,,}.
# Meant to be sourced, not executed.
_RESTORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$_RESTORE_LIB_DIR/common.sh"
# shellcheck source=validate.sh
. "$_RESTORE_LIB_DIR/validate.sh"
# shellcheck source=profile.sh
. "$_RESTORE_LIB_DIR/profile.sh"
# shellcheck source=tccdb.sh
. "$_RESTORE_LIB_DIR/tccdb.sh"
# Bundle IDs already ensured in this run (newline separated) and the one-time
# --no-restore notice flag.
_RESTORE_ENSURED=""
_RESTORE_NOTICED=0
# _restore_disabled: true when --no-restore is in effect.
_restore_disabled() {
  [ "${OPT_NO_RESTORE:-0}" = "1" ] || [ "${CAPTURE_NO_RESTORE:-0}" = "1" ]
}
# _restore_load_profiles: loads profiles once so the guards know the bundle IDs.
_restore_load_profiles() {
  if [ "${#CAPTURE_PROFILE_FILES[@]}" -eq 0 ]; then
    profile_load_all "$(profile_dir)" >/dev/null 2>&1 || return 1
  fi
  return 0
}
# _restore_profile_for_bundle bundle: prints the profile file whose bundle_id is bundle.
_restore_profile_for_bundle() {
  local f id
  for f in ${CAPTURE_PROFILE_FILES[@]+"${CAPTURE_PROFILE_FILES[@]}"}; do
    id="$(profile_field "$f" bundle_id)" || continue
    if [ "$id" = "$1" ]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}
# _restore_backup_path bundle: backup path recorded in the snapshot, else the
# newest backup file in the state directory.
_restore_backup_path() {
  local file path newest
  file="$(_tcc_snapshot_file "$1")"
  if [ -f "$file" ]; then
    path="$(sed -n 's/^  "backup": "\(.*\)",$/\1/p' "$file" | head -n 1)"
    if [ -n "$path" ]; then
      printf '%s\n' "$path"
      return 0
    fi
  fi
  newest="$(tcc_newest_backup)"
  printf '%s\n' "${newest:-$(tcc_backup_file_path "")}"
}
# tcc_ensure_snapshot profile run_ts
# Makes sure a snapshot and a backup exist for the profile's bundle, once per
# run. Returns 1 on any failure; the caller must then not start the reset.
tcc_ensure_snapshot() {
  local profile="${1-}" run_ts="${2-}" bundle services svc file have missing probe_out
  local -a svcs=()
  if _restore_disabled; then
    if [ "$_RESTORE_NOTICED" -eq 0 ]; then
      _RESTORE_NOTICED=1
      printf 'notice: --no-restore given; the TCC database is not read or written and no restore will run\n'
    fi
    return 0
  fi
  _restore_load_profiles || { echo "restore: cannot load profiles" >&2; return 1; }
  bundle="$(profile_field "$profile" bundle_id)" || { echo "restore: unknown profile: $profile" >&2; return 1; }
  while IFS= read -r svc; do
    [ -n "$svc" ] && svcs+=("$svc")
  done <<EOF
$(profile_services "$profile")
EOF
  # The memo only holds while the snapshot is still pending: after a failure
  # path restored it (cleanup_all), a later session of the run needs a new one.
  case "
$_RESTORE_ENSURED
" in
    *"
$bundle
"*)
      if [ "$CAPTURE_DRY_RUN" = "1" ] || [ -f "$(_tcc_snapshot_file "$bundle")" ]; then
        return 0
      fi
      ;;
  esac
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    printf 'would snapshot TCC rows for bundle id %s, services: %s\n' "$bundle" "${svcs[*]-}"
    printf 'would back up the TCC database to %s\n' "$(tcc_backup_file_path "$run_ts")"
    _RESTORE_ENSURED="$_RESTORE_ENSURED
$bundle"
    return 0
  fi
  export TCC_DECLARED_SERVICES
  TCC_DECLARED_SERVICES="$(printf '%s\n' ${svcs[@]+"${svcs[@]}"})"
  file="$(_tcc_snapshot_file "$bundle")"
  if [ -f "$file" ]; then
    if ! _tcc_load_snapshot "$bundle"; then
      echo "restore: pending snapshot is unreadable; run capture.sh restore first" >&2
      return 1
    fi
    have="$(printf '%s\n' ${_TS_SERVICES[@]+"${_TS_SERVICES[@]}"})"
    missing=0
    for svc in ${svcs[@]+"${svcs[@]}"}; do
      printf '%s\n' "$have" | grep -Fxq -- "$svc" || missing=1
    done
    if [ "$missing" -eq 1 ]; then
      echo "restore: pending snapshot is older than the profile; run capture.sh restore first" >&2
      return 1
    fi
    printf 'reusing pending snapshot %s\n' "$file"
    _RESTORE_ENSURED="$_RESTORE_ENSURED
$bundle"
    return 0
  fi
  export TCC_RUN_TS="$run_ts"
  local probe_rc=0
  probe_out="$(tcc_probe 2>&1)" || probe_rc=$?
  if [ "$probe_rc" -eq 3 ]; then
    printf '%s\n' "$probe_out" >&2
    return 1
  elif [ "$probe_rc" -ne 0 ]; then
    printf 'cannot read the TCC database: %s\n%s\n' "$probe_out" "$_TCC_FDA_HINT" >&2
    return 1
  fi
  tcc_notice "$bundle" "$run_ts"
  tcc_snapshot "$bundle" ${svcs[@]+"${svcs[@]}"} || return 1
  tcc_backup "$run_ts" || return 1
  _RESTORE_ENSURED="$_RESTORE_ENSURED
$bundle"
  return 0
}
# tcc_copy_snapshot_to_session dir profile
# Copies the snapshot to <dir>/tcc-snapshot.json and lists it as an artifact.
tcc_copy_snapshot_to_session() {
  local dir="${1-}" profile="${2-}" bundle file
  _restore_disabled && return 0
  [ "$CAPTURE_DRY_RUN" = "1" ] && return 0
  _restore_load_profiles || return 1
  bundle="$(profile_field "$profile" bundle_id)" || return 1
  file="$(_tcc_snapshot_file "$bundle")"
  [ -f "$file" ] || { echo "restore: no snapshot to copy for $bundle" >&2; return 1; }
  cp "$file" "$dir/tcc-snapshot.json" || return 1
  if declare -F manifest_add_artifact >/dev/null 2>&1; then
    manifest_add_artifact tcc-snapshot.json || return 1
  fi
  return 0
}
# restore_one bundle
# Restores one pending snapshot, restarts tccd, and marks it restored. Keeps
# the snapshot pending and returns 1 on a verify difference or a write failure.
restore_one() {
  local bundle="${1-}" pfile svc errf out err rc backup
  local -a svcs=()
  _restore_load_profiles || true
  if ! pfile="$(_restore_profile_for_bundle "$bundle")"; then
    printf "restore: refusing pending snapshot for bundle id '%s': it is in no loaded profile\n" "$bundle" >&2
    return 1
  fi
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    printf 'would restore TCC rows for bundle id %s from %s\n' "$bundle" "$(_tcc_snapshot_file "$bundle")"
    return 0
  fi
  while IFS= read -r svc; do
    [ -n "$svc" ] && svcs+=("$svc")
  done <<EOF
$(profile_services "$pfile")
EOF
  export TCC_DECLARED_SERVICES
  TCC_DECLARED_SERVICES="$(printf '%s\n' ${svcs[@]+"${svcs[@]}"})"
  backup="$(_restore_backup_path "$bundle")"
  errf="$(mktemp "${TMPDIR:-/tmp}/restore-err.XXXXXX")" || return 1
  rc=0
  out="$(tcc_restore "$bundle" 2>"$errf")" || rc=$?
  err="$(cat "$errf")"
  rm -f "$errf"
  if [ "$rc" -eq 0 ]; then
    tcc_restart_daemon
    tcc_mark_restored "$bundle" || return 1
    printf 'restored TCC rows for bundle id %s\n' "$bundle"
    return 0
  fi
  if [ -n "$out" ]; then
    printf 'restore verification failed for bundle id %s; differing services:\n%s\n' "$bundle" "$out" >&2
    printf 'the snapshot stays pending; backup of the whole database: %s\n' "$backup" >&2
  else
    printf 'restore could not write the TCC database for bundle id %s\n' "$bundle" >&2
    [ -z "$err" ] || printf '%s\n' "$err" >&2
    printf 'manual fallback: re-enable the permission in System Settings > Privacy & Security\n' >&2
    printf 'backup of the whole database: %s\n' "$backup" >&2
  fi
  return 1
}
# restore_all
# restore_one for every pending snapshot, continuing after a failure.
restore_all() {
  local bundle n=0 failed=0 list
  list="$(tcc_pending)"
  while IFS= read -r bundle; do
    [ -n "$bundle" ] || continue
    n=$((n + 1))
    restore_one "$bundle" || failed=1
  done <<EOF
$list
EOF
  [ "$n" -gt 0 ] || printf 'nothing to restore\n'
  return "$failed"
}
# cmd_restore [profile]
# Restores one profile's pending snapshot, or every pending snapshot.
cmd_restore() {
  local profile="${1-}" bundle
  profile_load_all "$(profile_dir)" || exit "$EXIT_USAGE"
  if [ -n "$profile" ]; then
    [ -f "$(profile_file "$profile")" ] || die "$EXIT_USAGE" "unknown profile: $profile"
    bundle="$(profile_field "$profile" bundle_id)" || exit "$EXIT_USAGE"
    if [ ! -f "$(_tcc_snapshot_file "$bundle")" ]; then
      printf 'nothing to restore\n'
      return 0
    fi
    restore_one "$bundle" || exit "$EXIT_FAIL"
    return 0
  fi
  restore_all || exit "$EXIT_FAIL"
}
