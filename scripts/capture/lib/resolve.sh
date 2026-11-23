#!/usr/bin/env bash
# Prompt resolution: button lookup, click, dismissal check.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# ui.applescript contract used here (values always passed as argv):
#   osascript ui.applescript buttons <owner>          one button label per line
#   osascript ui.applescript click   <owner> <label>  click the button with that label
# <owner> is the prompt window owner (CAPTURE_PROMPT_OWNER).

_RESOLVE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
. "$_RESOLVE_LIB_DIR/common.sh"
# shellcheck source=defaults.sh
. "$_RESOLVE_LIB_DIR/defaults.sh"
# shellcheck source=windows.sh
. "$_RESOLVE_LIB_DIR/windows.sh"
# shellcheck source=manifest.sh
. "$_RESOLVE_LIB_DIR/manifest.sh"

: "${CAPTURE_UI_SCRIPT:=$_RESOLVE_LIB_DIR/ui.applescript}"
: "${CAPTURE_DISMISS_TIMEOUT:=5}"

# normalize_label text
# Pure. Prints text lower-cased (ASCII), with curly apostrophes turned into
# straight ones and surrounding whitespace removed.
normalize_label() {
  printf '%s' "$1" \
    | sed -e "s/’/'/g" -e "s/‘/'/g" -e "s/ʼ/'/g" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# pick_button choice < buttons
# Pure. Reads button labels, one per line, from stdin. choice is "allow" or
# "deny". Prints the original text of the first button whose normalized label
# equals a normalized entry of the comma-separated list CAPTURE_ALLOW_LABELS
# (allow) or CAPTURE_DENY_LABELS (deny). Prints nothing and returns 1 when no
# button matches or choice is anything else.
pick_button() {
  local list btn norm entry old_ifs
  case "${1-}" in
    allow) list="$CAPTURE_ALLOW_LABELS" ;;
    deny) list="$CAPTURE_DENY_LABELS" ;;
    *) return 1 ;;
  esac
  list="$(normalize_label "$list")"
  while IFS= read -r btn || [ -n "$btn" ]; do
    [ -n "$btn" ] || continue
    norm="$(normalize_label "$btn")"
    [ -n "$norm" ] || continue
    old_ifs="$IFS"
    IFS=','
    for entry in $list; do
      entry="$(printf '%s' "$entry" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [ -n "$entry" ] && [ "$entry" = "$norm" ]; then
        IFS="$old_ifs"
        printf '%s\n' "$btn"
        return 0
      fi
    done
    IFS="$old_ifs"
  done
  return 1
}

# _resolve_prompt_row: current prompt window row, or nothing.
_resolve_prompt_row() {
  windows_list 2>/dev/null | match_prompt
}

# _resolve_wait_dismissed
# Polls every 500 ms for CAPTURE_DISMISS_TIMEOUT seconds. Returns 0 when no
# prompt window remains.
_resolve_wait_dismissed() {
  local start now
  start="$(_now_ms)"
  while :; do
    if [ -z "$(_resolve_prompt_row)" ]; then
      return 0
    fi
    now="$(_now_ms)"
    if [ $(( now - start )) -ge $(( CAPTURE_DISMISS_TIMEOUT * 1000 )) ]; then
      return 1
    fi
    sleep 0.5
  done
}

# _resolve_not_found choice buttons
# Saves a screenshot of the prompt window, reports the buttons found, records
# the failure in the manifest. Always returns 1.
_resolve_not_found() {
  local choice="$1" buttons="$2" row id shot=""
  row="$(_resolve_prompt_row)"
  id="$(printf '%s' "$row" | awk -F '\t' '{ print $1; exit }')"
  if [ -n "${SESSION_DIR:-}" ] && [ -d "$SESSION_DIR" ]; then
    case "$id" in
      '' | *[!0-9]*) ;;
      *)
        local tmp="$SESSION_DIR/resolve-failure.tmp.png"
        local final="$SESSION_DIR/resolve-failure.png"
        if ext screencapture -x -o "-l$id" "$tmp" && [ -s "$tmp" ] && mv -f "$tmp" "$final"; then
          shot="resolve-failure.png"
          manifest_add_artifact "$shot"
        else
          rm -f "$tmp"
        fi
        ;;
    esac
  fi
  {
    printf 'resolve: no "%s" button found in the prompt window.\n' "$choice"
    if [ -n "$buttons" ]; then
      printf 'resolve: buttons found:\n'
      printf '%s\n' "$buttons" | sed -e "s/^/  - /"
    else
      printf 'resolve: buttons found: (none)\n'
    fi
    if [ -n "$shot" ]; then
      printf 'resolve: screenshot saved to %s\n' "$SESSION_DIR/$shot"
    else
      printf 'resolve: no screenshot saved\n'
    fi
  } >&2
  manifest_set prompt.resolution failed
  manifest_set prompt.buttons_found "$(printf '%s' "$buttons" | tr '\n' ',' | sed -e 's/,$//')"
  return 1
}

# resolve_prompt choice
# choice: allow | deny | none.
#   none:  prints a notice, records "skipped", returns 0, no dismissal check.
#   allow/deny: lists buttons, picks the match, clicks it, then checks for up to
#     CAPTURE_DISMISS_TIMEOUT seconds (500 ms polls) that the prompt is gone.
# Returns 1 when the button is missing (screenshot saved, buttons reported,
# manifest records "failed") or the prompt is still present (manifest records
# "still present"). Returns 2 for an invalid choice before touching anything.
resolve_prompt() {
  local choice="${1-}" buttons label
  case "$choice" in
    none)
      printf 'resolve: --resolve none: leaving the prompt on screen. Resolve it manually.\n'
      manifest_set prompt.resolution skipped
      return 0
      ;;
    allow | deny) ;;
    *)
      printf 'resolve: choice must be allow, deny or none: %s\n' "$choice" >&2
      return 2
      ;;
  esac

  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext osascript "$CAPTURE_UI_SCRIPT" buttons "$CAPTURE_PROMPT_OWNER"
    ext osascript "$CAPTURE_UI_SCRIPT" click "$CAPTURE_PROMPT_OWNER" "<$choice button>"
    return 0
  fi

  buttons="$(osascript "$CAPTURE_UI_SCRIPT" buttons "$CAPTURE_PROMPT_OWNER" 2>/dev/null)"
  label="$(printf '%s\n' "$buttons" | pick_button "$choice")" || label=""
  if [ -z "$label" ]; then
    _resolve_not_found "$choice" "$buttons"
    return 1
  fi

  if ! ext osascript "$CAPTURE_UI_SCRIPT" click "$CAPTURE_PROMPT_OWNER" "$label" >/dev/null; then
    printf 'resolve: clicking "%s" failed\n' "$label" >&2
    _resolve_not_found "$choice" "$buttons"
    return 1
  fi

  if _resolve_wait_dismissed; then
    manifest_set prompt.resolution dismissed
    return 0
  fi
  manifest_set prompt.resolution "still present"
  printf 'resolve: the prompt was not dismissed within %s seconds of clicking "%s".\n' \
    "$CAPTURE_DISMISS_TIMEOUT" "$label" >&2
  return 1
}
