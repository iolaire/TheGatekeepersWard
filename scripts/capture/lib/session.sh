#!/usr/bin/env bash
# Session_Directory naming and creation for the permission capture framework.
# bash 3.2 compatible. Meant to be sourced, not executed.

# run_timestamp
# Prints the UTC run timestamp (YYYYMMDDTHHMMSSZ). Called once per `run`
# so every Capture_Session of that run shares one timestamp directory.
run_timestamp() {
  date -u +%Y%m%dT%H%M%SZ
}

# session_path root ts profile scenario mode
# Pure. Prints root/captures/<ts>/<profile>/<scenario>/<mode>.
session_path() {
  printf '%s/captures/%s/%s/%s/%s\n' "$1" "$2" "$3" "$4" "$5"
}

# session_create path
# Creates the parent chain with mkdir -p, then the last segment with plain
# mkdir. If the last mkdir fails the directory already exists: print
# "session directory already exists: <path>" and exit 1, leaving it untouched.
session_create() {
  local path="$1" parent
  parent="$(dirname "$path")"
  mkdir -p "$parent" || {
    printf '%s\n' "cannot create parent directory: $parent" >&2
    exit 1
  }
  if ! mkdir "$path" 2>/dev/null; then
    printf '%s\n' "session directory already exists: $path" >&2
    exit 1
  fi
}

# Step runner state, set by run_step:
#   SESSION_STEP          name of the step that is running or ran last
#   SESSION_FAILED_STEP   name of the first step that failed ("" when none)
#   SESSION_OUTCOME_HINT  no_prompt or no_hud when a step sets it before failing
SESSION_STEP=""
SESSION_FAILED_STEP=""
SESSION_OUTCOME_HINT=""

# _session_abort_cleanup
# Failure path of run_step (requirement 12.5): finalize a running recorder so
# the manifest still gets its video fields, then run the teardown actions.
# Does nothing in dry-run mode.
_session_abort_cleanup() {
  [ "$CAPTURE_DRY_RUN" = "1" ] && return 0
  if declare -F session_finalize_video >/dev/null 2>&1; then
    session_finalize_video || true
  fi
  # The scoped reset comes before cleanup_all: cleanup_all restores the TCC
  # rows, and a reset after the restore would delete the restored grants (10.7).
  if [ "${S_PAST_RESET:-0}" = "1" ] && [ "$SESSION_STEP" != "reset-after" ] &&
    [ "${S_RESET_AFTER_DONE:-0}" != "1" ] && declare -F step_reset_after >/dev/null 2>&1; then
    log_step reset-after
    S_RESET_AFTER_DONE=1
    step_reset_after >&2 || true
  fi
  if declare -F cleanup_all >/dev/null 2>&1; then
    cleanup_all >&2 || true
  fi
  return 0
}

# run_step name fn args...
# Prints and logs the step line, runs fn in the current shell, and returns its
# status. On failure records failed_step, error (the step's stderr, or a
# generic text) and the outcome in the manifest scratch, then runs
# _session_abort_cleanup. The caller decides whether to continue (--keep-going).
run_step() {
  local name="$1" fn="$2" rc=0 errf="" msg outcome
  shift 2
  SESSION_STEP="$name"
  log_step "$name"
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    "$fn" "$@" || rc=$?
    [ "$rc" -eq 0 ] || SESSION_FAILED_STEP="$name"
    return "$rc"
  fi
  errf="$(mktemp "${TMPDIR:-/tmp}/capture-step.XXXXXX")" || errf=""
  if [ -n "$errf" ]; then
    "$fn" "$@" 2>"$errf" || rc=$?
    [ ! -s "$errf" ] || cat "$errf" >&2
  else
    "$fn" "$@" || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    msg=""
    [ -z "$errf" ] || msg="$(cat "$errf" 2>/dev/null)"
    [ -n "$msg" ] || msg="step $name failed (exit $rc)"
    outcome="${SESSION_OUTCOME_HINT:-error}"
    if [ -z "$SESSION_FAILED_STEP" ]; then
      SESSION_FAILED_STEP="$name"
      manifest_set outcome "$outcome" 2>/dev/null || true
      manifest_set failed_step "$name" 2>/dev/null || true
      manifest_set error "$msg" 2>/dev/null || true
    fi
    [ -z "$errf" ] || rm -f "$errf"
    _session_abort_cleanup
    return "$rc"
  fi
  [ -z "$errf" ] || rm -f "$errf"
  return 0
}
# manifest_artifacts file
# Pure text parse (no osascript): prints the artifact names of a manifest.json
# written by lib/json.js (pretty printed, two-space indent), one per line.
manifest_artifacts() {
  awk '
    function unesc(s,   out, i, c, n) {
      out = ""
      n = length(s)
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\\" && i < n) {
          i++
          c = substr(s, i, 1)
          if (c == "n") c = "\n"; else if (c == "t") c = "\t"
        }
        out = out c
      }
      return out
    }
    /^  "artifacts": \[\]/ { exit }
    /^  "artifacts": \[/ { inarr = 1; next }
    inarr && /^  \]/ { exit }
    inarr {
      line = $0
      sub(/^    "/, "", line)
      sub(/",?$/, "", line)
      print unesc(line)
    }
  ' "$1"
}
# write_summary root ts profile scenario
# Writes <scenario>/summary.md only when both baseline/manifest.json and
# ward/manifest.json exist (11.6, 11.7). Two-column table of relative links,
# one link per manifest artifact. Returns 1 without writing when a mode is missing.
write_summary() {
  local root="$1" ts="$2" profile="$3" scenario="$4" dir tmp b w nb nw i
  dir="$root/captures/$ts/$profile/$scenario"
  if [ ! -f "$dir/baseline/manifest.json" ] || [ ! -f "$dir/ward/manifest.json" ]; then
    printf 'summary.md not written: %s/%s is missing a completed mode\n' "$profile" "$scenario" >&2
    return 1
  fi
  b="$(manifest_artifacts "$dir/baseline/manifest.json")"
  w="$(manifest_artifacts "$dir/ward/manifest.json")"
  tmp="$dir/.summary.md.tmp"
  {
    printf '# %s / %s (%s)\n\n' "$profile" "$scenario" "$ts"
    printf '| Baseline | Ward |\n| --- | --- |\n'
    nb=0; [ -z "$b" ] || nb="$(printf '%s\n' "$b" | wc -l | tr -d ' ')"
    nw=0; [ -z "$w" ] || nw="$(printf '%s\n' "$w" | wc -l | tr -d ' ')"
    i=1
    while [ "$i" -le "$nb" ] || [ "$i" -le "$nw" ]; do
      printf '| '
      _summary_cell baseline "$b" "$i" "$nb"
      printf ' | '
      _summary_cell ward "$w" "$i" "$nw"
      printf ' |\n'
      i=$((i + 1))
    done
  } >"$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$dir/summary.md"
}
# _summary_cell mode names index count: prints "| [name](mode/name)" cell text.
_summary_cell() {
  local mode="$1" names="$2" i="$3" n="$4" name
  if [ "$i" -gt "$n" ]; then
    printf '%s' ''
    return 0
  fi
  name="$(printf '%s\n' "$names" | sed -n "${i}p")"
  printf '[%s](%s/%s)' "$name" "$mode" "$name"
}
