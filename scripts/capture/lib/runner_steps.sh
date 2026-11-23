#!/usr/bin/env bash
# The twelve Capture_Session steps (requirement 12.1). Each step_* function
# returns 0 on success and non-zero on failure, writing its reason to stderr.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Session context, set by run_session (lib/runner.sh) before any step runs:
#   S_PROFILE S_SCENARIO S_MODE S_BUNDLE S_SERVICE S_PROMPT S_PTIMEOUT S_DWELL
#   S_BACKEND S_RESOLVE SESSION_DIR
# State shared between steps:
#   S_RECORDING   1 while the recorder runs
#   S_PAST_RESET  1 once the start-of-session reset step began
#   S_PROMPT_ID / S_PROMPT_RECT / S_HUD_RECT   window number and "x y w h"
#
# In dry-run mode every step prints the quoted text of each command through
# ext and runs nothing: no external binary, no file, no directory.
S_RECORDING=0
S_PAST_RESET=0
S_RESET_AFTER_DONE=0
S_PROMPT_ID=""
S_PROMPT_RECT=""
S_HUD_RECT=""
S_HUD_TIMEOUT=10

# _m_set key value / _m_dry: manifest writes that do nothing in dry-run mode.
_m_set() {
  [ "$CAPTURE_DRY_RUN" = "1" ] && return 0
  manifest_set "$@" 2>/dev/null || true
}

# _row_field row n: field n (1-based) of a tab-separated window row.
_row_field() {
  printf '%s\n' "$1" | awk -F '\t' -v n="$2" '{ print $n; exit }'
}

# _record_window prefix row: manifest <prefix>.detected_at and <prefix>.bounds.*.
_record_window() {
  local prefix="$1" row="$2"
  _m_set "$prefix.detected_at" "$(utc_now_ms)"
  _m_set "$prefix.bounds.x" "$(_row_field "$row" 5)"
  _m_set "$prefix.bounds.y" "$(_row_field "$row" 6)"
  _m_set "$prefix.bounds.w" "$(_row_field "$row" 7)"
  _m_set "$prefix.bounds.h" "$(_row_field "$row" 8)"
}

# _fail_shot name: full-screen evidence screenshot after a detection failure.
_fail_shot() {
  local name="$1"
  if [ -n "$OPT_DISPLAY" ]; then
    ext screencapture -x "-D$OPT_DISPLAY" "$SESSION_DIR/$name" || true
  else
    ext screencapture -x "$SESSION_DIR/$name" || true
  fi
}

# _preflight_perms: the permissions preflight checks, one per line. Full Disk
# Access is left out with --no-restore (12.7).
_preflight_perms() {
  local n
  for n in $PERM_NAMES; do
    if [ "$n" = full-disk-access ] && [ "${OPT_NO_RESTORE:-0}" = "1" ]; then continue; fi
    printf '%s\n' "$n"
  done
}
# step_preflight (step 1): three checks always run (12.7, 12.8), then the
# mode setup (baseline: no Ward running; ward: start or reuse Ward).
step_preflight() {
  local failed="" n missing="" out
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    for n in $(_preflight_perms); do
      if [ "$n" = full-disk-access ]; then
        echo "would check Full Disk Access with a read-only probe of the TCC database"
      else
        ext swift "$CAPTURE_DIR/lib/permcheck.swift" status "$n"
      fi
    done
    ext osascript -l JavaScript "$CAPTURE_DIR/lib/preflight.js" installed "$S_BUNDLE"
    ext osascript -l JavaScript "$CAPTURE_DIR/lib/preflight.js" display
    if [ "$S_MODE" = "ward" ]; then
      ext pgrep -f "$WARD_PROCESS_PATTERN"
      ext "$CAPTURE_REPO_ROOT/scripts/run_ward.sh"
      ext osascript -l JavaScript "$CAPTURE_DIR/lib/windows.js" list
    else
      ext pgrep -f "$WARD_PROCESS_PATTERN"
    fi
    return 0
  fi
  local st unavailable=""
  for n in $(_preflight_perms); do
    st="$(perm_status "$n")"
    if [ "$st" = "unavailable" ]; then
      unavailable="$n"
    elif [ "$st" != "granted" ]; then
      missing="$missing $n"
    fi
  done
  if [ -n "$unavailable" ]; then
    out="$(tcc_probe 2>&1)" || true
    failed="$failed
  - TCC database unavailable: $out"
  fi
  [ -z "$missing" ] || failed="$failed
  - permissions missing:$missing (run capture.sh setup)"
  case "$missing" in
    *full-disk-access*) failed="$failed
  - Full Disk Access: open System Settings > Privacy & Security > Full Disk Access ($(perm_pane_url full-disk-access 2>/dev/null))" ;;
  esac
  out="$(osascript -l JavaScript "$CAPTURE_DIR/lib/preflight.js" installed "$S_BUNDLE" 2>/dev/null)" || out=""
  [ "$out" = "true" ] || failed="$failed
  - target app not installed: $S_BUNDLE"
  out="$(osascript -l JavaScript "$CAPTURE_DIR/lib/preflight.js" display 2>/dev/null)" || out=""
  [ "$out" = "true" ] || failed="$failed
  - display is asleep or the session is locked"
  if [ -n "$failed" ]; then
    printf 'preflight failed:%s\n' "$failed" >&2
    return 1
  fi
  ward_ensure "$S_MODE"
}

# step_reset (step 2): take the TCC snapshot once per run (15.1, 15.7), copy it
# into the session (15.3), then the scoped reset of the Scenario's service only
# (3.8, 3.9). When the snapshot fails no tccutil command runs and S_PAST_RESET
# stays 0, so the failure path does not reset either.
step_reset() {
  # Called even when disabled so the one-time --no-restore notice prints.
  tcc_ensure_snapshot "$S_PROFILE" "${CAPTURE_RUN_TS:-$(run_timestamp)}" || return 1
  if ! _restore_disabled; then
    if [ "$CAPTURE_DRY_RUN" = "1" ]; then
      printf 'tcc-snapshot: %s (dry-run)\n' "$S_BUNDLE"
    else
      tcc_copy_snapshot_to_session "$SESSION_DIR" "$S_PROFILE" || return 1
      printf 'tcc-snapshot: %s\n' "$S_BUNDLE"
    fi
  fi
  S_PAST_RESET=1
  if [ "$OPT_NO_RESET" = "1" ]; then
    echo "reset skipped (--no-reset)"
    return 0
  fi
  reset_run "$S_PROFILE" --service "$S_SERVICE"
}

# step_video_start (step 3): start the recorder (8.1, 8.5, 8.6, 8.9).
step_video_start() {
  if [ "$OPT_NO_VIDEO" = "1" ]; then
    echo "video skipped (--no-video)"
    return 0
  fi
  if [ "$CAPTURE_DRY_RUN" = "1" ] && [ "$S_BACKEND" = "ffmpeg" ] && ! command -v ffmpeg >/dev/null 2>&1; then
    echo "note: ffmpeg was not found; a real run would stop here"
  fi
  video_start "$SESSION_DIR" "$S_BACKEND" "$OPT_DISPLAY" || return 1
  S_RECORDING=1
}

# step_app_launch (step 4): launch the target app and wait for its window.
step_app_launch() {
  app_launch "$S_PROFILE"
}

# _dry_check_paths: dry-run form of app_check_paths.
_dry_check_paths() {
  local path
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    ext test -d "$path"
    ext osascript "$CAPTURE_DIR/lib/ui.applescript" disk-exists "${path#/Volumes/}"
  done <<EOF
$(app_extract_volume_paths "$S_PROMPT")
EOF
}

# step_prompt_send (step 5): path check, prepare_action, focus the input, send, approve.
step_prompt_send() {
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    _dry_check_paths
  else
    app_check_paths "$S_PROMPT" || return 1
  fi
  app_prepare "$S_PROFILE" || return 1
  app_focus_input "$S_PROFILE" || return 1
  app_send "$S_PROFILE" "$S_PROMPT" || return 1
  app_approve "$S_PROFILE"
}

# step_prompt_detection (step 6): poll for the TCC prompt (6.1 to 6.3, 6.7).
step_prompt_detection() {
  local row text match
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript -l JavaScript "$CAPTURE_DIR/lib/windows.js" list
    ext osascript "$CAPTURE_DIR/lib/ui.applescript" read-prompt "$CAPTURE_PROMPT_OWNER"
    return 0
  fi
  row="$(poll_window "$S_PTIMEOUT" match_prompt)" || row=""
  if [ -z "$row" ]; then
    _fail_shot no-prompt.png
    SESSION_OUTCOME_HINT=no_prompt
    printf 'no TCC prompt window appeared within %ss\n' "$S_PTIMEOUT" >&2
    return 1
  fi
  _record_window prompt "$row"
  S_PROMPT_ID="$(_row_field "$row" 1)"
  S_PROMPT_RECT="$(printf '%s\n' "$row" | awk -F '\t' '{ print $5, $6, $7, $8 }')"
  text="$(osascript "$CAPTURE_DIR/lib/ui.applescript" read-prompt "$CAPTURE_PROMPT_OWNER" 2>/dev/null)" || text=""
  match="$(classify_prompt "$text" "$S_SERVICE")"
  _m_set prompt.service_match "$match"
  return 0
}

# _display_rect: "x y w h" of the selected display (main when none given).
_display_rect() {
  windows_displays 2>/dev/null | awk -v i="${OPT_DISPLAY:-1}" '$1 == i { print $2, $3, $4, $5; exit }'
}

# step_screenshots (step 7): screen+prompt first, then HUD polling, hud, pair.
# --no-images skips the captures; HUD polling still runs (6.4 to 6.6).
step_screenshots() {
  local hudrow rect disp
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    if [ "$OPT_NO_IMAGES" != "1" ]; then
      shot_screen "$SESSION_DIR" "$OPT_DISPLAY"
      _shot_capture "$SESSION_DIR" prompt.png screencapture -x -o "-l<prompt window id>"
    fi
    if [ "$S_MODE" = "ward" ]; then
      ext osascript -l JavaScript "$CAPTURE_DIR/lib/windows.js" list
      if [ "$OPT_NO_IMAGES" != "1" ]; then
        _shot_capture "$SESSION_DIR" hud.png screencapture -x -o "-l<hud window id>"
        ext osascript -l JavaScript "$CAPTURE_DIR/lib/windows.js" displays
        _shot_capture "$SESSION_DIR" pair.png screencapture -x "-R<x,y,w,h>"
      fi
    fi
    return 0
  fi
  if [ "$OPT_NO_IMAGES" != "1" ]; then
    shot_screen "$SESSION_DIR" "$OPT_DISPLAY" || true
    shot_window "$SESSION_DIR" "$S_PROMPT_ID" prompt.png || true
  fi
  [ "$S_MODE" = "ward" ] || return 0
  hudrow="$(poll_window "$S_HUD_TIMEOUT" match_hud)" || hudrow=""
  if [ -z "$hudrow" ]; then
    _fail_shot no-hud.png
    SESSION_OUTCOME_HINT=no_hud
    printf 'the Fortress HUD did not appear within %ss\n' "$S_HUD_TIMEOUT" >&2
    return 1
  fi
  _record_window hud "$hudrow"
  S_HUD_RECT="$(printf '%s\n' "$hudrow" | awk -F '\t' '{ print $5, $6, $7, $8 }')"
  [ "$OPT_NO_IMAGES" != "1" ] || return 0
  shot_window "$SESSION_DIR" "$(_row_field "$hudrow" 1)" hud.png || true
  if [ -f "$SESSION_DIR/hud.png" ] && [ -f "$SESSION_DIR/prompt.png" ]; then
    disp="$(_display_rect)"
    rect=""
    [ -z "$disp" ] || rect="$(crop_rect "$S_PROMPT_RECT" "$S_HUD_RECT" 24 "$disp")" || rect=""
    if [ -n "$rect" ]; then
      shot_pair "$SESSION_DIR" "$rect" || true
    else
      printf 'skipped pair.png\n' >&2
    fi
  fi
  return 0
}

# step_dwell (step 8): keep recording while the prompt stays on screen (8.2).
step_dwell() {
  printf 'dwell %ss\n' "$S_DWELL"
  ext sleep "$S_DWELL"
}

# step_resolve (step 9): click the chosen button, check the prompt is gone.
step_resolve() {
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    if [ "$S_RESOLVE" = "none" ]; then
      echo "resolve: --resolve none: leaving the prompt on screen. Resolve it manually."
      return 0
    fi
    resolve_prompt "$S_RESOLVE"
    ext osascript -l JavaScript "$CAPTURE_DIR/lib/windows.js" list
    return 0
  fi
  resolve_prompt "$S_RESOLVE"
}

# session_finalize_video: stop the recorder if one is running and record the
# result. Used by step_video_stop and by the failure path of run_step.
session_finalize_video() {
  local out size dur
  [ "$S_RECORDING" = "1" ] || return 0
  S_RECORDING=0
  if out="$(video_stop)"; then
    size="${out#size=}"
    size="${size%% *}"
    dur="${out##*duration=}"
    _m_set video.status ok
    _m_set video.bytes "$size"
    _m_set video.duration_s "$dur"
    return 0
  fi
  _m_set video.status failed
  return 1
}

# step_video_stop (step 10): SIGINT, wait, verify, record size and duration.
step_video_stop() {
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    [ "$S_RECORDING" = "1" ] && video_stop
    return 0
  fi
  [ "$S_RECORDING" = "1" ] || { echo "video stop skipped (no recording)"; return 0; }
  session_finalize_video || { printf 'video failed: see the messages above\n' >&2; return 1; }
}

# step_reset_after (step 11): scoped reset again (10.7, 10.8).
step_reset_after() {
  local rc=0
  reset_run "$S_PROFILE" --service "$S_SERVICE" || rc=$?
  if [ "$rc" -ne 0 ]; then
    _m_set reset_failed true
    printf 'warning: tccutil reset failed for service %s; reset it manually: tccutil reset %s %s\n' \
      "$S_SERVICE" "$S_SERVICE" "$S_BUNDLE" >&2
    return 1
  fi
  _m_set reset_failed false
}

# _register_artifacts: list every non-empty file in SESSION_DIR except the
# manifest and temporary captures.
_register_artifacts() {
  local f name
  for f in "$SESSION_DIR"/*; do
    [ -f "$f" ] && [ -s "$f" ] || continue
    name="$(basename "$f")"
    case "$name" in manifest.json | *.tmp.png) continue ;; esac
    manifest_add_artifact "$name" 2>/dev/null || true
  done
}

# step_manifest_write (step 12): exactly one manifest.json (11.1, 11.2, 11.5).
step_manifest_write() {
  local ver
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext sw_vers -productVersion
    [ "$S_MODE" != "ward" ] || ext git -C "$CAPTURE_REPO_ROOT" rev-parse HEAD
    ext osascript -l JavaScript "$CAPTURE_DIR/lib/json.js" build "<manifest scratch dir>"
    return 0
  fi
  ver="$(sw_vers -productVersion 2>/dev/null)" || ver=""
  _m_set macos_version "${ver:-unknown}"
  _m_set ended_at "$(utc_now_s)"
  [ -z "$SESSION_FAILED_STEP" ] && _m_set outcome ok
  [ "$S_MODE" != "ward" ] || _m_set ward_commit "$(ward_commit)"
  _register_artifacts
  manifest_write "$SESSION_DIR" || {
    printf 'manifest-write failed for %s\n' "$SESSION_DIR" >&2
    return 1
  }
}
