#!/usr/bin/env bash
# Target app driver: launch, focus the input, check volume paths, send the
# Prompt_Message, run the optional approve_tool_call step.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Every value reaches osascript as a separate argv element. ui.applescript and
# clipboard.js are fixed files; no value is spliced into script source
# (requirement 13.10). Mutating commands go through ext so --dry-run prints them.
# Read-only queries (running, frontmost, disk-exists) run directly.
#
# Inputs from the caller:
#   SESSION_DIR           where the locator-failure screenshot goes
#   CAPTURE_STATE_DIR     state directory (default <repo>/captures/.state)
#   CAPTURE_DRY_RUN       "1" prints commands only

_APP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${CAPTURE_DIR:=$(cd "$_APP_LIB_DIR/.." && pwd)}"

# shellcheck source=common.sh
. "$_APP_LIB_DIR/common.sh"
# shellcheck source=validate.sh
. "$_APP_LIB_DIR/validate.sh"
# shellcheck source=profile.sh
. "$_APP_LIB_DIR/profile.sh"

APP_UI_SCRIPT="$_APP_LIB_DIR/ui.applescript"
APP_CLIPBOARD_JS="$_APP_LIB_DIR/clipboard.js"
APP_AXMANUAL_SWIFT="$_APP_LIB_DIR/axmanual.swift"
APP_LOCATOR_TIMEOUT=5
APP_APPROVE_TIMEOUT=30

# _app_state_dir: directory for launched.txt and clipboard.snap.
_app_state_dir() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$_APP_LIB_DIR/../../.." && pwd)}/captures/.state}"
}

# _app_ui verb args...: run a ui.applescript verb, values in argv.
_app_ui() {
  osascript "$APP_UI_SCRIPT" "$@"
}

# app_extract_volume_paths text
# Pure. Prints each removable-volume root named in text, one per line, in order
# of appearance, as /Volumes/<name>. Interface:
#   input   one argument, the Prompt_Message
#   output  zero or more lines "/Volumes/<name>"; exit status always 0
# Rules:
#   - "/Volumes/" must start the text or follow a character that is not part of
#     a path (not a letter, digit, "_", ".", "~", "-" or "/"). So
#     "/Users/a/Volumes/b" is not a match.
#   - <name> runs up to the first whitespace, "/", quote, backtick, or one of
#     , ; : ( ) [ ] { } < > |  A backslash-space pair stays inside the name and
#     is printed as a plain space.
#   - Trailing "." characters are removed (sentence punctuation).
#   - An empty <name> yields nothing.
app_extract_volume_paths() {
  local rest="$1" prev="" prefix name c next i len
  while :; do
    case "$rest" in
      *"/Volumes/"*) ;;
      *) break ;;
    esac
    prefix="${rest%%/Volumes/*}"
    rest="${rest#*/Volumes/}"
    if [ -n "$prefix" ]; then
      prev="${prefix: -1}"
    fi
    case "$prev" in
      [A-Za-z0-9_.~/-]) _app_vol_skip=1 ;;
      *) _app_vol_skip=0 ;;
    esac
    name=""
    i=0
    len="${#rest}"
    while [ "$i" -lt "$len" ]; do
      c="${rest:$i:1}"
      if [ "$c" = "\\" ]; then
        next="${rest:$((i + 1)):1}"
        if [ "$next" = " " ]; then
          name="$name "
          i=$((i + 2))
          continue
        fi
      fi
      case "$c" in
        ' ' | $'\t' | $'\n' | $'\r' | '/' | '"' | "'" | '`' | ',' | ';' | ':' | '(' | ')' | '[' | ']' | '{' | '}' | '<' | '>' | '|' | '\') break ;;
      esac
      name="$name$c"
      i=$((i + 1))
    done
    rest="${rest:$i}"
    prev="${name: -1}"
    [ -n "$prev" ] || prev="/"
    while :; do
      case "$name" in
        *.) name="${name%.}" ;;
        *) break ;;
      esac
    done
    if [ "$_app_vol_skip" = "0" ] && [ -n "$name" ]; then
      printf '/Volumes/%s\n' "$name"
    fi
  done
  unset _app_vol_skip
  return 0
}

# app_check_paths prompt
# Requirements 5.5, 5.6. For every /Volumes/<name> in prompt, requires that the
# directory exists and that Finder lists a disk of that name. Prints
# "removable volume path not found: <path>" to stderr and returns 1 on the
# first miss. Sends no text.
app_check_paths() {
  local prompt="$1" path name
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    name="${path#/Volumes/}"
    if [ ! -d "$path" ]; then
      printf 'removable volume path not found: %s\n' "$path" >&2
      return 1
    fi
    if [ "$(_app_ui disk-exists "$name" 2>/dev/null)" != "true" ]; then
      printf 'removable volume path not found: %s (Finder lists no disk named %s)\n' "$path" "$name" >&2
      return 1
    fi
  done <<EOF
$(app_extract_volume_paths "$prompt")
EOF
  return 0
}

# _app_launch_cmd_ok first_word: the launch command must start with open,
# osascript, or an absolute path under /Applications.
_app_launch_cmd_ok() {
  case "$1" in
    open | osascript | /Applications/*) return 0 ;;
  esac
  return 1
}

# _app_axmanual bundle: set AXManualAccessibility on the running app.
# Test hook: CAPTURE_AXMANUAL names an executable taking the same argument.
_app_axmanual() {
  if [ -n "${CAPTURE_AXMANUAL:-}" ]; then
    ext "$CAPTURE_AXMANUAL" "$1"
  else
    ext swift "$APP_AXMANUAL_SWIFT" "$1"
  fi
}

# app_expose_ax profile_id
# For Electron apps (profile ax_manual_accessibility = true): sets
# AXManualAccessibility so the web content, and with it the input_locator, is
# visible to System Events. Does nothing for other profiles. The attribute lasts
# until the app quits, so this runs after every launch. On failure prints
# "could not expose <bundle> to Accessibility" and returns 1.
app_expose_ax() {
  local id="$1" bundle flag
  flag="$(profile_field "$id" ax_manual_accessibility)" || flag=""
  [ "$flag" = "true" ] || return 0
  bundle="$(profile_field "$id" bundle_id)" || return 1
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    _app_axmanual "$bundle"
    return 0
  fi
  if ! _app_axmanual "$bundle" >/dev/null; then
    printf 'could not expose %s to Accessibility (AXManualAccessibility)\n' "$bundle" >&2
    return 1
  fi
  # Electron builds the tree asynchronously after the attribute is set.
  sleep 1
  return 0
}

# app_launch profile_id
# Requirements 5.1, 5.3, 2.6. Runs the profile launch command (also when the
# app runs, to activate it) and records the bundle ID in launched.txt only
# when the app was not running. Waits up to
# launch_timeout for a frontmost window. On timeout prints
# "app window did not appear within <N>s: <bundle>" to stderr, returns 1 and
# leaves the app running. Then runs app_expose_ax (Electron profiles only).
app_launch() {
  local id="$1" bundle launch timeout words state running="" deadline
  bundle="$(profile_field "$id" bundle_id)" || return 1
  launch="$(profile_field "$id" launch)" || return 1
  timeout="$(with_default "$(profile_field "$id" launch_timeout)" 20)"
  if ! valid_range "$timeout" 1 300; then
    printf 'invalid launch_timeout: %s\n' "$timeout" >&2
    return 1
  fi
  if [ "$CAPTURE_DRY_RUN" != "1" ]; then
    running="$(_app_ui running "$bundle" 2>/dev/null)"
  fi
  # Split once on whitespace; no eval, no globbing.
  set -f
  # shellcheck disable=SC2206
  words=($launch)
  set +f
  if [ "${#words[@]}" -eq 0 ] || ! _app_launch_cmd_ok "${words[0]}"; then
    printf 'launch command not allowed: %s\n' "$launch" >&2
    return 1
  fi
  # Sent even when the app runs: open activates it and brings back a closed or
  # hidden window, and a copy that is quitting is relaunched. Only a launch from
  # a stopped state is recorded for teardown to quit.
  ext "${words[@]}" || return 1
  if [ "$running" != "true" ] && [ "$CAPTURE_DRY_RUN" != "1" ]; then
    state="$(_app_state_dir)"
    mkdir -p "$state" && printf '%s\n' "$bundle" >>"$state/launched.txt"
  fi
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "$APP_UI_SCRIPT" frontmost "$bundle"
    app_expose_ax "$id"
    return
  fi
  deadline=$((SECONDS + timeout))
  while :; do
    if [ "$(_app_ui frontmost "$bundle" 2>/dev/null)" = "true" ]; then
      app_expose_ax "$id"
      return
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      printf 'app window did not appear within %ss: %s\n' "$timeout" "$bundle" >&2
      return 1
    fi
    sleep 0.5
  done
}

# app_prepare profile_id
# Clicks the profile's optional prepare_action (for example
# find:button "New Session") so each session starts from a clean view. Does
# nothing when the profile has none. Waits up to 10 s for the element, then
# 1.5 s for the view to settle. On failure prints
# "prepare_action step failed: <spec>" and returns 1.
APP_PREPARE_TIMEOUT=10
app_prepare() {
  local id="$1" bundle spec
  spec="$(profile_field "$id" prepare_action)" || spec=""
  [ -n "$spec" ] || return 0
  bundle="$(profile_field "$id" bundle_id)" || return 1
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "$APP_UI_SCRIPT" send "$bundle" "$spec" "$APP_PREPARE_TIMEOUT"
    return 0
  fi
  if ! ext osascript "$APP_UI_SCRIPT" send "$bundle" "$spec" "$APP_PREPARE_TIMEOUT" >/dev/null; then
    printf 'prepare_action step failed: %s\n' "$spec" >&2
    return 1
  fi
  sleep 1.5
  return 0
}

# app_focus_input profile_id
# Requirement 5.2, 5.4. Focuses the input field named by input_locator, waiting
# up to 5 s. On failure saves a screenshot to $SESSION_DIR, sends no text,
# prints the failed locator and the screenshot path to stderr, returns 1.
app_focus_input() {
  local id="$1" bundle locator shot
  bundle="$(profile_field "$id" bundle_id)" || return 1
  locator="$(profile_field "$id" input_locator)" || return 1
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "$APP_UI_SCRIPT" focus "$bundle" "$locator" "$APP_LOCATOR_TIMEOUT"
    return 0
  fi
  if _app_ui focus "$bundle" "$locator" "$APP_LOCATOR_TIMEOUT" >/dev/null 2>&1; then
    return 0
  fi
  shot="${SESSION_DIR:-.}/input-locator-failed.png"
  if ! screencapture -x "$shot" 2>/dev/null; then
    shot="(screenshot failed)"
  fi
  printf 'input locator matched no element within %ss: %s (screenshot: %s)\n' \
    "$APP_LOCATOR_TIMEOUT" "$locator" "$shot" >&2
  return 1
}

# _app_clipboard_restore snap: restores and deletes the snapshot.
_app_clipboard_restore() {
  local snap="$1"
  [ -f "$snap" ] || return 0
  if osascript -l JavaScript "$APP_CLIPBOARD_JS" restore "$snap" >/dev/null 2>&1; then
    rm -f "$snap"
    return 0
  fi
  printf 'warning: could not restore clipboard from %s\n' "$snap" >&2
  return 1
}

# app_send profile_id prompt [method]
# Requirements 5.2, 5.9, 5.10. method is clipboard or keystroke; default is the
# profile's send_method, then clipboard.
#   clipboard: snapshot the pasteboard, set it to prompt, cmd+v, restore the
#              pasteboard (success or failure), then perform send_action.
#   keystroke: type prompt through System Events, then perform send_action.
# Returns 1 on any failure. Clipboard contents are restored before returning.
app_send() {
  local id="$1" prompt="$2" method="${3:-}" bundle send_action state snap rc=0
  bundle="$(profile_field "$id" bundle_id)" || return 1
  send_action="$(profile_field "$id" send_action)" || return 1
  [ -n "$method" ] || method="$(profile_field "$id" send_method)"
  [ -n "$method" ] || method=clipboard
  case "$method" in
    clipboard | keystroke) ;;
    *)
      printf 'invalid send method: %s (use clipboard or keystroke)\n' "$method" >&2
      return 1
      ;;
  esac
  state="$(_app_state_dir)"
  snap="$state/clipboard.snap"

  if [ "$method" = "keystroke" ]; then
    ext osascript "$APP_UI_SCRIPT" type "$bundle" "$prompt" || return 1
  elif [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript -l JavaScript "$APP_CLIPBOARD_JS" snapshot "$snap"
    ext osascript -l JavaScript "$APP_CLIPBOARD_JS" set "$prompt"
    ext osascript "$APP_UI_SCRIPT" paste "$bundle"
    ext osascript -l JavaScript "$APP_CLIPBOARD_JS" restore "$snap"
  else
    mkdir -p "$state" || return 1
    if ! osascript -l JavaScript "$APP_CLIPBOARD_JS" snapshot "$snap" >/dev/null 2>&1; then
      printf 'cannot snapshot the clipboard; sending nothing\n' >&2
      rm -f "$snap"
      return 1
    fi
    if osascript -l JavaScript "$APP_CLIPBOARD_JS" set "$prompt" >/dev/null 2>&1 &&
      _app_ui paste "$bundle" >/dev/null 2>&1; then
      rc=0
    else
      printf 'clipboard paste failed\n' >&2
      rc=1
    fi
    _app_clipboard_restore "$snap" || rc=1
    [ "$rc" -eq 0 ] || return 1
  fi

  ext osascript "$APP_UI_SCRIPT" send "$bundle" "$send_action" "$APP_LOCATOR_TIMEOUT" || {
    printf 'send action failed: %s\n' "$send_action" >&2
    return 1
  }
  return 0
}

# app_approve profile_id
# Requirements 5.7, 5.8. Does nothing when the profile has no approve_tool_call.
# Otherwise waits up to approve_timeout seconds (default 30) for whichever comes
# first: the approval element, which it clicks, or the TCC prompt window, which
# means the agent did not ask this time (agents such as DeepSeek Harness only
# ask in some sessions). Each pass searches for the element for 2 s. On timeout
# prints "approve_tool_call step failed: <step>" to stderr and returns 1.
APP_APPROVE_PASS=2
app_approve() {
  local id="$1" bundle spec secs deadline
  spec="$(profile_field "$id" approve_tool_call)" || spec=""
  [ -n "$spec" ] || return 0
  bundle="$(profile_field "$id" bundle_id)" || return 1
  secs="$(with_default "$(profile_field "$id" approve_timeout)" "$APP_APPROVE_TIMEOUT")"
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "$APP_UI_SCRIPT" approve "$bundle" "$spec" "$secs"
    return 0
  fi
  deadline=$((SECONDS + secs))
  while :; do
    if osascript "$APP_UI_SCRIPT" approve "$bundle" "$spec" "$APP_APPROVE_PASS" >/dev/null 2>&1; then
      printf 'approved: %s\n' "$spec"
      return 0
    fi
    if declare -F match_prompt >/dev/null 2>&1 &&
      [ -n "$(windows_list 2>/dev/null | match_prompt)" ]; then
      printf '%s\n' "no tool approval needed: the TCC prompt is already on screen"
      return 0
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
      printf 'approve_tool_call step failed: %s\n' "$spec" >&2
      return 1
    fi
    sleep 0.5
  done
}
