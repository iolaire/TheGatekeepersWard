#!/usr/bin/env bash
# Window matching (pure) and window list polling.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Window list rows (stdin of the match_* functions), tab-separated:
#   <windowNumber> <owner> <layer> <alpha> <x> <y> <w> <h>

_WINDOWS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=defaults.sh
. "$_WINDOWS_LIB_DIR/defaults.sh"

# Window owner name of the Ward: its CFBundleName, not the executable name.
_WARD_DEFAULT_OWNER="Gatekeeper's Ward"
: "${CAPTURE_WARD_OWNER:=$_WARD_DEFAULT_OWNER}"
WARD_OWNER="$CAPTURE_WARD_OWNER"
WARD_HUD_LAYER=3
WARD_HUD_WIDTH=400
WARD_HUD_WIDTH_TOLERANCE=2
WARD_HUD_MIN_ALPHA=0.9

# windows_list: current on-screen windows, front to back.
windows_list() {
  osascript -l JavaScript "$_WINDOWS_LIB_DIR/windows.js" list
}

# windows_list_all: every window, including off-screen ones (same columns).
windows_list_all() {
  osascript -l JavaScript "$_WINDOWS_LIB_DIR/windows.js" all
}

# windows_displays: "<index> <x> <y> <w> <h>" per active display, main first.
windows_displays() {
  osascript -l JavaScript "$_WINDOWS_LIB_DIR/windows.js" displays
}

# match_prompt [owner [layer]] < list
# Pure. First row whose owner and layer equal the arguments (defaults:
# CAPTURE_PROMPT_OWNER, CAPTURE_PROMPT_LAYER) and whose w and h are positive.
match_prompt() {
  local owner="${1:-$CAPTURE_PROMPT_OWNER}" layer="${2:-$CAPTURE_PROMPT_LAYER}"
  awk -F '\t' -v owner="$owner" -v layer="$layer" '
    $2 == owner && ($3 + 0) == (layer + 0) && ($7 + 0) > 0 && ($8 + 0) > 0 { print; exit }
  '
}

# match_hud < list
# Pure. First Ward window at layer 3 with alpha above 0.9 and width within 2
# of 400. Excludes the menu bar status item.
match_hud() {
  awk -F '\t' \
    -v owner="$WARD_OWNER" -v layer="$WARD_HUD_LAYER" -v alpha="$WARD_HUD_MIN_ALPHA" \
    -v width="$WARD_HUD_WIDTH" -v tol="$WARD_HUD_WIDTH_TOLERANCE" '
    function abs(v) { return v < 0 ? -v : v }
    $2 == owner && ($3 + 0) == (layer + 0) && ($4 + 0) > (alpha + 0) \
      && abs(($7 + 0) - width) <= tol { print; exit }
  '
}

# match_ward_item < list
# Pure. First on-screen Ward window at or above CAPTURE_WARD_MENUBAR_MIN_LAYER.
match_ward_item() {
  awk -F '\t' -v owner="$WARD_OWNER" -v min="$CAPTURE_WARD_MENUBAR_MIN_LAYER" '
    $2 == owner && ($3 + 0) >= (min + 0) { print; exit }
  '
}

# match_ward_registered < list
# Pure. First window of any layer owned by the Ward. On macOS 26 and later the
# menu bar status item is drawn by the system and is not in the window list, so
# a registered Ward window (its hidden HUD panel) shows the app finished launching.
match_ward_registered() {
  awk -F '\t' -v owner="$WARD_OWNER" '$2 == owner { print; exit }'
}

# _now_ms: epoch milliseconds (perl ships with macOS; falls back to seconds).
_now_ms() {
  perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000' 2>/dev/null \
    || echo $(( $(date +%s) * 1000 ))
}

# poll_window timeout_seconds matcher [matcher args...]
# Runs windows_list every 250 ms (sleep shortened by the list call duration)
# and prints the first row the matcher accepts. Returns 1 at the timeout.
# The matcher is a function name such as match_prompt, match_hud, match_ward_item.
poll_window() {
  local timeout="$1" matcher="$2" row start now next elapsed_ms
  shift 2
  local period_ms=250
  start="$(_now_ms)"
  next="$start"
  while :; do
    row="$(windows_list 2>/dev/null | "$matcher" "$@")"
    if [ -n "$row" ]; then
      printf '%s\n' "$row"
      return 0
    fi
    now="$(_now_ms)"
    elapsed_ms=$(( now - start ))
    if [ "$elapsed_ms" -ge $(( timeout * 1000 )) ]; then
      return 1
    fi
    next=$(( next + period_ms ))
    if [ "$next" -gt "$now" ]; then
      sleep "$(awk -v ms=$(( next - now )) 'BEGIN { printf "%.3f", ms / 1000 }')"
    else
      next="$now"
    fi
  done
}

# classify_prompt text service
# Pure. Looks service up in services.tbl. Prints "unknown" when text is empty or
# the service is missing, "true" when the lowercased text contains any keyword,
# otherwise "false".
classify_prompt() {
  local text="$1" service="$2" tbl keywords kw lower
  tbl="${CAPTURE_SERVICES_TBL:-$_WINDOWS_LIB_DIR/services.tbl}"
  if [ -z "$text" ] || [ -z "$service" ] || [ ! -f "$tbl" ]; then
    echo unknown
    return 0
  fi
  keywords="$(awk -F '\t' -v s="$service" '$1 == s { print $2; exit }' "$tbl")"
  if [ -z "$keywords" ]; then
    echo unknown
    return 0
  fi
  lower="$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]')"
  local old_ifs="$IFS"
  IFS=','
  for kw in $keywords; do
    IFS="$old_ifs"
    kw="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
    if [ -n "$kw" ]; then
      case "$lower" in
        *"$kw"*) echo true; return 0 ;;
      esac
    fi
    IFS=','
  done
  IFS="$old_ifs"
  echo false
}
