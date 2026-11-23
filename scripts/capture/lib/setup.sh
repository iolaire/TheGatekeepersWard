#!/usr/bin/env bash
# setup and doctor subcommands, permission checks, Setup_State_File merge.
# bash 3.2 compatible. Meant to be sourced.
#
# Test hook: set CAPTURE_PERMCHECK to an executable that takes the same
# arguments as permcheck.swift ("status <name>" / "request <name>").

PERM_NAMES="accessibility screen-recording automation-system-events automation-finder full-disk-access"

# Full Disk Access is probed through tcc_probe in tccdb.sh.
if ! command -v tcc_probe >/dev/null 2>&1 && [ -f "${CAPTURE_DIR:-.}/lib/tccdb.sh" ]; then
  # shellcheck source=lib/tccdb.sh
  . "$CAPTURE_DIR/lib/tccdb.sh"
fi

# perm_run args...: run the permcheck helper.
perm_run() {
  if [ -n "${CAPTURE_PERMCHECK:-}" ]; then
    "$CAPTURE_PERMCHECK" "$@"
  else
    swift "$CAPTURE_DIR/lib/permcheck.swift" "$@"
  fi
}

# perm_pane name: print the System Settings pane key for a permission.
perm_pane() {
  case "$1" in
    accessibility) printf '%s\n' "Privacy_Accessibility" ;;
    screen-recording) printf '%s\n' "Privacy_ScreenCapture" ;;
    automation-system-events|automation-finder) printf '%s\n' "Privacy_Automation" ;;
    full-disk-access) printf '%s\n' "Privacy_AllFiles" ;;
    *) return 1 ;;
  esac
}

# perm_pane_url name: print the x-apple.systempreferences: URL for a permission.
perm_pane_url() {
  local pane
  pane="$(perm_pane "$1")" || return 1
  printf 'x-apple.systempreferences:com.apple.preference.security?%s\n' "$pane"
}

# perm_status name: print "granted" or "missing". Never prompts.
perm_status() {
  local out
  if [ "$1" = full-disk-access ]; then
    local rc=0
    tcc_probe >/dev/null 2>&1 || rc=$?
    case "$rc" in
      0) printf '%s\n' granted ;;
      3) printf '%s\n' unavailable ;;
      *) printf '%s\n' missing ;;
    esac
    return 0
  fi
  out="$(perm_run status "$1" 2>/dev/null)" || out=""
  case "$out" in
    granted) printf '%s\n' granted ;;
    *) printf '%s\n' missing ;;
  esac
}

# perm_line name status: print the status line for setup and doctor.
perm_line() {
  if [ "$1" = full-disk-access ] && [ "$2" = unavailable ]; then
    printf '%s\n' "full-disk-access: unavailable (no user TCC database on this macOS; use --no-restore)"
  else
    printf '%s: %s\n' "$1" "$2"
  fi
}

# perm_request name: open the matching Settings pane, then trigger the system
# request. The pane is opened first so it appears within 5 s even when the
# request call blocks on a dialog. Prints the resulting status.
perm_request() {
  local url out
  url="$(perm_pane_url "$1")" || return 2
  ext open "$url" >/dev/null 2>&1 || true
  # No request API exists for Full Disk Access: opening the pane is all we do.
  if [ "$1" = full-disk-access ]; then
    perm_status "$1"
    return 0
  fi
  out="$(perm_run request "$1" 2>/dev/null)" || out=""
  case "$out" in
    granted) printf '%s\n' granted ;;
    *) printf '%s\n' missing ;;
  esac
}

# state_dir: runtime state directory.
setup_state_dir() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$CAPTURE_DIR/../.." && pwd)}/captures/.state}"
}

# setup_state_file: path of the Setup_State_File.
setup_state_file() {
  printf '%s/setup.json\n' "$(setup_state_dir)"
}

# setup_state_get text name: print "true" or "false" when text records the
# permission, else nothing. text is flat JSON with one "name": bool per line.
setup_state_get() {
  printf '%s\n' "$1" | sed -n -E "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*(true|false).*/\\1/p" | head -n 1
}

# setup_state_merge old new [skip]
# Pure. old and new are Setup_State_File texts (old may be empty). For each of
# the five permissions keeps old's already_granted value when old records it,
# otherwise takes new's (default false). A permission named in skip (a
# space-separated list) is left out unless old records it. Prints the merged
# file text.
setup_state_merge() {
  local old="$1" new="$2" skip="${3:-}" name val lines="" n=0 total=0 s skipped
  for name in $PERM_NAMES; do
    val="$(setup_state_get "$old" "$name")"
    skipped=0
    for s in $skip; do [ "$s" = "$name" ] && skipped=1; done
    if [ "$skipped" = 1 ] && [ -z "$val" ]; then
      continue
    fi
    [ -n "$val" ] || val="$(setup_state_get "$new" "$name")"
    [ -n "$val" ] || val=false
    lines="$lines$name $val
"
    total=$((total + 1))
  done
  printf '{\n'
  while read -r name val; do
    [ -n "$name" ] || continue
    n=$((n + 1))
    if [ "$n" -lt "$total" ]; then
      printf '  "%s": %s,\n' "$name" "$val"
    else
      printf '  "%s": %s\n' "$name" "$val"
    fi
  done <<EOF2
$lines
EOF2
  printf '}\n'
}

# setup_state_write new_text: merge into the Setup_State_File and write it.
setup_state_write() {
  local file old="" merged
  file="$(setup_state_file)"
  [ -f "$file" ] && old="$(cat "$file")"
  local skip=""
  [ "${OPT_NO_RESTORE:-0}" = 1 ] && skip="full-disk-access"
  merged="$(setup_state_merge "$old" "$1" "$skip")"
  mkdir -p "$(dirname "$file")" || return 1
  printf '%s\n' "$merged" >"$file.tmp" && mv "$file.tmp" "$file"
}

# cmd_setup: print five status lines (four with --no-restore, plus a skipped line), request what is missing, re-check after
# the user confirms, write the state file. Exit 0 only when all are granted.
cmd_setup() {
  local name st new_state="" missing="" first_status="" still=""
  for name in $PERM_NAMES; do
    if [ "$name" = full-disk-access ] && [ "${OPT_NO_RESTORE:-0}" = 1 ]; then
      printf '%s\n' "full-disk-access: skipped (--no-restore)"
      continue
    fi
    st="$(perm_status "$name")"
    perm_line "$name" "$st"
    if [ "$st" = unavailable ]; then
      # Nothing to grant: not a missing permission, no pane opened.
      new_state="$new_state\"$name\": false
"
    elif [ "$st" = granted ]; then
      new_state="$new_state\"$name\": true
"
    else
      new_state="$new_state\"$name\": false
"
      missing="$missing $name"
    fi
  done

  if [ -n "$missing" ]; then
    for name in $missing; do
      perm_request "$name" >/dev/null
    done
    case " $missing " in
      *" full-disk-access "*)
        printf 'full-disk-access is missing: grant it in System Settings (%s), then restart the Capture_Host if needed\n' \
          "$(perm_pane full-disk-access)" >&2 ;;
    esac
    printf '%s\n' "Grant the missing permissions in System Settings, then press Return." >&2
    # EOF (no terminal) falls through to the re-check.
    read -r _ || true
    for name in $missing; do
      st="$(perm_status "$name")"
      [ "$st" = granted ] || still="$still $name"
    done
  fi

  setup_state_write "$new_state" || die "$EXIT_FAIL" "cannot write $(setup_state_file)"

  if [ -n "$still" ]; then
    for name in $still; do
      printf 'still missing: %s (grant it in System Settings: %s)\n' \
        "$name" "$(perm_pane "$name")" >&2
    done
    return "$EXIT_FAIL"
  fi
  return "$EXIT_OK"
}

# cmd_doctor: read-only report. Calls only perm_status and command -v.
cmd_doctor() {
  local name st tool rc=0 backend pending
  backend="${OPT_VIDEO_BACKEND:-${CAPTURE_VIDEO_BACKEND:-screencapture}}"
  for name in $PERM_NAMES; do
    if [ "$name" = full-disk-access ] && [ "${OPT_NO_RESTORE:-0}" = 1 ]; then
      printf '%s\n' "full-disk-access: skipped (--no-restore)"
      continue
    fi
    perm_line "$name" "$(perm_status "$name")"
  done
  for tool in osascript screencapture tccutil; do
    if command -v "$tool" >/dev/null 2>&1; then
      printf '%s: found\n' "$tool"
    else
      printf '%s: not found\n' "$tool"
      rc="$EXIT_FAIL"
    fi
  done
  if [ "$backend" = ffmpeg ]; then
    if command -v ffmpeg >/dev/null 2>&1; then
      printf 'ffmpeg: found\n'
    else
      printf 'ffmpeg: not found\n'
      rc="$EXIT_FAIL"
    fi
  fi
  pending="$(tcc_pending 2>/dev/null | paste -sd, -)"
  printf 'pending tcc snapshot: %s\n' "${pending:-none}"
  printf 'macos: %s (prompt owner %s, layer %s)\n' \
    "$(sw_vers -productVersion 2>/dev/null || printf unknown)" \
    "${CAPTURE_PROMPT_OWNER:-unknown}" "${CAPTURE_PROMPT_LAYER:-unknown}"
  return "$rc"
}
