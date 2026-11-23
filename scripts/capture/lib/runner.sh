#!/usr/bin/env bash
# Session driver and the `prompt` and `run` subcommands.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Uses plan.sh for planning and the failure policy, runner_steps.sh for the
# twelve steps, session.sh for run_step and directory handling. Option values
# are validated before any step runs (exit 2, no directory created).

# Ordered "name:function" pairs (requirement 12.1, design "Run flow").
RUNNER_STEPS="preflight:step_preflight reset:step_reset video-start:step_video_start
app-launch:step_app_launch prompt-send:step_prompt_send
prompt-detection:step_prompt_detection screenshots:step_screenshots dwell:step_dwell
resolve:step_resolve video-stop:step_video_stop"

# _runner_on_signal code
# INT/TERM during a real session: same cleanup as teardown, plus the scoped
# reset of the Scenario's service (10.7), then exit with code.
_runner_on_signal() {
  local code="$1"
  trap '' INT TERM
  _CLEANUP_RUNNING=1
  # Scoped reset first, then cleanup_all, whose last TCC action is the restore.
  if [ "$S_PAST_RESET" = "1" ] && [ "$S_RESET_AFTER_DONE" != "1" ]; then
    S_RESET_AFTER_DONE=1
    step_reset_after >&2 || true
  fi
  cleanup_all >&2 || true
  CAPTURE_SESSION_ACTIVE=0
  exit "$code"
}

# _runner_load_session profile scenario mode
# Fills the S_* context from the profile and the parsed options.
_runner_load_session() {
  S_PROFILE="$1"
  S_SCENARIO="$2"
  S_MODE="$3"
  S_BUNDLE="$(profile_field "$S_PROFILE" bundle_id)"
  S_SERVICE="$(profile_field "$S_PROFILE" "scenario.$S_SCENARIO.service")"
  S_PROMPT="$(profile_field "$S_PROFILE" "scenario.$S_SCENARIO.prompt")"
  S_PTIMEOUT="$(with_default "$(profile_field "$S_PROFILE" "scenario.$S_SCENARIO.prompt_timeout")" "$CAPTURE_DEFAULT_PROMPT_TIMEOUT")"
  S_DWELL="$(with_default "$(profile_field "$S_PROFILE" "scenario.$S_SCENARIO.dwell")" "$CAPTURE_DEFAULT_DWELL")"
  S_BACKEND="$(with_default "$OPT_VIDEO_BACKEND" screencapture)"
  S_RESOLVE="$(with_default "$OPT_RESOLVE" "$CAPTURE_DEFAULT_RESOLVE")"
  S_RECORDING=0
  S_PAST_RESET=0
  S_RESET_AFTER_DONE=0
  S_PROMPT_ID=""
  S_PROMPT_RECT=""
  S_HUD_RECT=""
  SESSION_FAILED_STEP=""
  SESSION_OUTCOME_HINT=""
}

# run_session profile scenario mode ts
# Runs the twelve steps for one Capture_Session. Returns 0 when it ended with
# outcome ok, 1 otherwise. Never exits: the caller applies the failure policy.
run_session() {
  local profile="$1" scenario="$2" mode="$3" ts="$4"
  local spec name fn rc=0 root
  root="${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}"
  CAPTURE_RUN_TS="$ts"
  _runner_load_session "$profile" "$scenario" "$mode"
  SESSION_DIR="$(session_path "$root" "$ts" "$profile" "$scenario" "$mode")"
  printf 'session: %s %s %s -> %s\n' "$profile" "$scenario" "$mode" "$SESSION_DIR"
  if [ "$CAPTURE_DRY_RUN" != "1" ]; then
    # A path conflict aborts the session and leaves the directory untouched (11.4).
    ( session_create "$SESSION_DIR" ) || return 1
    manifest_reset
    manifest_set profile_id "$profile"
    manifest_set bundle_id "$S_BUNDLE"
    manifest_set scenario "$scenario"
    manifest_set mode "$mode"
    manifest_set started_at "$(utc_now_s)"
    CAPTURE_SESSION_ACTIVE=1
    trap '_runner_on_signal 130' INT
    trap '_runner_on_signal 143' TERM
  fi
  for spec in $RUNNER_STEPS; do
    name="${spec%%:*}"
    fn="${spec#*:}"
    run_step "$name" "$fn" || { rc=1; break; }
  done
  if [ "$rc" -ne 0 ]; then
    # A failure after the start-of-session reset still gets the end reset (10.6,
    # 10.7); run_step already ran it, before cleanup_all, when a step failed.
    if [ "$S_PAST_RESET" = "1" ] && [ "$S_RESET_AFTER_DONE" != "1" ] && [ "$CAPTURE_DRY_RUN" != "1" ]; then
      log_step reset-after
      step_reset_after || true
    fi
  else
    run_step reset-after step_reset_after || rc=1
    if [ "$rc" -eq 0 ] && [ "$mode" = "ward" ]; then
      if [ "$CAPTURE_DRY_RUN" = "1" ]; then
        ext kill -TERM "<Marker_File pid>"
      else
        ward_stop_if_marked
      fi
    fi
  fi
  log_step manifest-write
  step_manifest_write || rc=1
  if [ "$rc" -eq 0 ] && declare -F publish_session >/dev/null 2>&1; then
    publish_session "$SESSION_DIR" "$profile" "$scenario" "$mode" || rc=1
  fi
  if [ "$CAPTURE_DRY_RUN" != "1" ]; then
    CAPTURE_SESSION_ACTIVE=0
    if declare -F install_cleanup_traps >/dev/null 2>&1; then install_cleanup_traps; fi
  fi
  return "$rc"
}

# _runner_validate_options
# Exits 2 on any invalid option value, before any step or directory.
_runner_validate_options() {
  local count
  case "$OPT_MODE" in
    '' | baseline | ward) ;;
    *) die "$EXIT_USAGE" "invalid --mode '$OPT_MODE'; use baseline or ward" ;;
  esac
  if [ -n "$OPT_RESOLVE" ] && ! valid_resolve "$OPT_RESOLVE"; then
    die "$EXIT_USAGE" "invalid --resolve '$OPT_RESOLVE'; use allow, deny or none"
  fi
  case "$OPT_VIDEO_BACKEND" in
    '' | screencapture | ffmpeg) ;;
    *) die "$EXIT_USAGE" "invalid --video-backend '$OPT_VIDEO_BACKEND'; use screencapture or ffmpeg" ;;
  esac
  if [ -n "$OPT_DISPLAY" ]; then
    if [ "$CAPTURE_DRY_RUN" = "1" ]; then
      valid_range "$OPT_DISPLAY" 1 999 || die "$EXIT_USAGE" "invalid --display '$OPT_DISPLAY'; use a display index of 1 or more"
    else
      count="$(windows_displays 2>/dev/null | grep -c .)" || count=0
      valid_display "$OPT_DISPLAY" "$count" ||
        die "$EXIT_USAGE" "invalid --display '$OPT_DISPLAY'; $count display(s) attached"
    fi
  fi
}

# _runner_catalog profile
# Prints "id<TAB>scenario,scenario" for the profile, or for every loaded
# profile when profile is empty.
_runner_catalog() {
  local want="$1" i id names
  for i in "${!CAPTURE_PROFILE_IDS[@]}"; do
    id="${CAPTURE_PROFILE_IDS[$i]}"
    if [ -n "$want" ] && [ "$id" != "$want" ]; then continue; fi
    names="$(profile_scenarios "${CAPTURE_PROFILE_FILES[$i]}" | tr '\n' ',')"
    printf '%s\t%s\n' "$id" "${names%,}"
  done
}

# _runner_resolve_args sub args...
# Sets R_PROFILE and R_SCENARIO from the positional arguments (exit 2 on misuse).
_runner_resolve_args() {
  local sub="$1" n last=""
  shift
  n=$#
  for last in "$@"; do :; done
  R_PROFILE=""
  R_SCENARIO=""
  if [ "$OPT_ALL_PROFILES" = "1" ]; then
    if [ "$OPT_ALL_SCENARIOS" != "1" ]; then
      [ "$n" -ge 1 ] || die "$EXIT_USAGE" "usage: capture.sh $sub --all-profiles <scenario>"
      R_SCENARIO="$last"
    fi
    return 0
  fi
  [ "$n" -ge 1 ] || die "$EXIT_USAGE" "usage: capture.sh $sub <profile> <scenario>"
  R_PROFILE="$1"
  if [ "$OPT_ALL_SCENARIOS" != "1" ]; then
    [ "$n" -ge 2 ] || die "$EXIT_USAGE" "usage: capture.sh $sub <profile> <scenario>"
    R_SCENARIO="$2"
  fi
}

# _runner_summary_and_report ts rows done_rows
# Writes summary.md for each pair whose two modes both ran (guarded: the
# function belongs to a later task) and reports incomplete pairs (11.7).
_runner_summary_and_report() {
  local ts="$1" rows="$2" done_rows="$3" tab row pair prof scen mode
  tab="$(printf '\t')"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    pair="${row%%"$tab"*}"
    prof="$(_row_field "$row" 2)"
    scen="$(_row_field "$row" 3)"
    mode="$(_row_field "$row" 4)"
    if [ -z "$OPT_MODE" ] && ! printf '%s\n' "$done_rows" | cut -f1,4,5 | grep -Fqx "$pair$tab$mode${tab}ok"; then
      printf 'incomplete: %s %s did not complete\n' "$pair" "$mode" >&2
    fi
    if [ "$mode" = "ward" ] && [ "$CAPTURE_DRY_RUN" != "1" ] && declare -F write_summary >/dev/null 2>&1 &&
      printf '%s\n' "$done_rows" | cut -f1,4 | grep -Fqx "$pair${tab}baseline" &&
      printf '%s\n' "$done_rows" | cut -f1,4 | grep -Fqx "$pair${tab}ward"; then
      write_summary "${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}" "$ts" "$prof" "$scen" || true
    fi
  done <<EOF
$rows
EOF
}

# _runner_publish_epilogue ts done_rows
# After the summaries: publishes each summary.md, then deletes the working
# folder of every session that ended ok (its files are already published).
# A failed session keeps its folder under captures/ for debugging.
_runner_publish_epilogue() {
  local ts="$1" done_rows="$2" root row prof scen mode oc tab sdir
  [ "$CAPTURE_DRY_RUN" != "1" ] || return 0
  declare -F publish_cleanup >/dev/null 2>&1 || return 0
  root="${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}"
  tab="$(printf '\t')"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    prof="$(_row_field "$row" 2)"
    scen="$(_row_field "$row" 3)"
    mode="$(_row_field "$row" 4)"
    oc="${row##*"$tab"}"
    sdir="$root/captures/$ts/$prof/$scen"
    # Only a pair whose two sessions both ended ok gets its summary published.
    if printf '%s\n' "$done_rows" | awk -F '\t' -v p="$prof" -v c="$scen" \
      '$2 == p && $3 == c && $NF == "ok" { n[$4] = 1 } END { exit !(n["baseline"] && n["ward"]) }'; then
      publish_summary "$sdir" "$prof" "$scen" || true
    fi
    if [ "$oc" = ok ] && [ -d "$sdir/$mode" ]; then
      publish_cleanup "$sdir/$mode" || true
    fi
    # Drop the summary once no session folder is left beside it.
    if [ -d "$sdir" ] && [ ! -d "$sdir/baseline" ] && [ ! -d "$sdir/ward" ]; then
      rm -f "$sdir/summary.md"
      rmdir "$sdir" "$root/captures/$ts/$prof" "$root/captures/$ts" 2>/dev/null || true
    fi
  done <<EOF
$done_rows
EOF
  return 0
}

# _runner_restore_epilogue
# Runs once after the last session's reset-after step (16.1). Prints a
# tcc-restore line and sets RUN_RESTORE_STATUS to verified, none, skipped or
# failed. A restore that cleanup_all already did leaves nothing pending.
RUN_RESTORE_STATUS="none"
_runner_restore_epilogue() {
  local bundle
  RUN_RESTORE_STATUS="none"
  if _restore_disabled; then
    RUN_RESTORE_STATUS="skipped"
    printf 'tcc-restore: skipped (--no-restore)\n'
    return 0
  fi
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    while IFS= read -r bundle; do
      [ -n "$bundle" ] || continue
      restore_one "$bundle" || true
    done <<ENSURED
$_RESTORE_ENSURED
ENSURED
    printf 'tcc-restore: would verify (dry-run)\n'
    return 0
  fi
  if [ -z "$(tcc_pending 2>/dev/null)" ]; then
    printf 'tcc-restore: nothing pending\n'
    return 0
  fi
  if restore_all; then
    RUN_RESTORE_STATUS="verified"
    printf 'tcc-restore: verified\n'
  else
    RUN_RESTORE_STATUS="failed"
    printf 'tcc-restore: failed; the snapshot stays pending (run capture.sh restore)\n' >&2
  fi
}
# _runner_main sub args...
# Shared body of cmd_prompt and cmd_run.
_runner_main() {
  local sub="$1" mode_arg catalog rows ts row oc done_rows="" outcomes="" tab
  local prof scen mode names
  shift
  tab="$(printf '\t')"
  _runner_resolve_args "$sub" "$@"
  _runner_validate_options
  profile_load_all "$(profile_dir)" || exit "$EXIT_USAGE"
  [ "${#CAPTURE_PROFILE_IDS[@]}" -gt 0 ] || die "$EXIT_USAGE" "no profiles found in $(profile_dir)"
  if [ -n "$R_PROFILE" ]; then
    case " ${CAPTURE_PROFILE_IDS[*]} " in
      *" $R_PROFILE "*) ;;
      *) die "$EXIT_USAGE" "unknown profile: $R_PROFILE" ;;
    esac
    if [ "$OPT_ALL_SCENARIOS" != "1" ]; then
      names="$(profile_scenarios "$R_PROFILE" | tr '\n' ' ')"
      case " $names" in
        *" $R_SCENARIO "*) ;;
        *) die "$EXIT_USAGE" "unknown scenario '$R_SCENARIO' for profile '$R_PROFILE'; declared: ${names% }" ;;
      esac
    fi
  fi
  if [ "$sub" = "prompt" ]; then mode_arg="${OPT_MODE:-baseline}"; else mode_arg="$OPT_MODE"; fi
  catalog="$(_runner_catalog "$R_PROFILE")"
  rows="$(plan_sessions "$mode_arg" "$OPT_ALL_SCENARIOS" "$R_SCENARIO" <<EOF
$catalog
EOF
)"
  [ -n "$rows" ] || die "$EXIT_USAGE" "unknown scenario '$R_SCENARIO': no loaded profile declares it"
  if [ "$OPT_REDACT" = "1" ]; then
    focus_enable || exit "$EXIT_FAIL"
  fi
  ts="$(run_timestamp)"
  # Keep the display and system awake while recording; caffeinate exits with us.
  if [ "$CAPTURE_DRY_RUN" != "1" ] && command -v caffeinate >/dev/null 2>&1; then
    caffeinate -d -i -w "$$" >/dev/null 2>&1 &
  fi
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    if ! plan_continue "$done_rows" "$row" "$OPT_KEEP_GOING"; then
      printf 'skipping %s %s: an earlier session failed\n' "$(_row_field "$row" 1)" "$(_row_field "$row" 4)" >&2
      continue
    fi
    prof="$(_row_field "$row" 2)"
    scen="$(_row_field "$row" 3)"
    mode="$(_row_field "$row" 4)"
    if run_session "$prof" "$scen" "$mode" "$ts" </dev/null; then oc=ok; else oc=error; fi
    done_rows="$done_rows$row$tab$oc
"
    outcomes="$outcomes $oc"
  done <<EOF
$rows
EOF
  _runner_restore_epilogue
  [ "$OPT_REDACT" != "1" ] || focus_restore || true
  [ "$sub" = "prompt" ] || _runner_summary_and_report "$ts" "$rows" "$done_rows"
  _runner_publish_epilogue "$ts" "$done_rows"
  if plan_exit_code "$outcomes" "$RUN_RESTORE_STATUS"; then exit "$EXIT_OK"; fi
  exit "$EXIT_FAIL"
}

# cmd_prompt <profile> <scenario>: one Capture_Session (baseline unless --mode).
cmd_prompt() {
  _runner_main prompt "$@"
}

# cmd_run <profile> <scenario>: baseline then ward unless --mode.
cmd_run() {
  _runner_main run "$@"
}
