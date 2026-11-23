#!/usr/bin/env bash
# Screenshots and the pair crop rectangle.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# File names are literals: screen.png, prompt.png, hud.png, pair.png.
# They never come from the manifest or any option (requirement 7.9).
# Each capture writes <name>.tmp.png first and renames it only when
# screencapture exits 0 and the file is non-empty. Otherwise the temp file is
# removed, "skipped <name>" goes to stderr, and the function returns 1 so the
# caller can continue with the remaining images (requirement 7.8).

_SHOTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
. "$_SHOTS_LIB_DIR/common.sh"

# crop_rect prompt hud margin display
# Pure. prompt, hud and display are each one argument "x y w h" in points.
# Prints "x y w h": the smallest rectangle containing both windows, grown by
# margin on every side, then intersected with display. Prints nothing and
# returns 1 when the result is empty or an input is malformed.
crop_rect() {
  [ "$#" -eq 4 ] || return 1
  printf '%s\n%s\n%s\n%s\n' "$1" "$2" "$3" "$4" | awk '
    function isnum(s) { return s ~ /^-?[0-9]+(\.[0-9]+)?$/ }
    function fields(line, arr,    n, p) {
      n = split(line, p, /[ ,\t]+/)
      if (n != 4) return 0
      for (i = 1; i <= 4; i++) { if (!isnum(p[i])) return 0; arr[i] = p[i] + 0 }
      return 1
    }
    NR == 1 { ok = fields($0, P) }
    NR == 2 { ok = ok && fields($0, H) }
    NR == 3 { ok = ok && isnum($0); M = $0 + 0 }
    NR == 4 { ok = ok && fields($0, D) }
    END {
      if (!ok) exit 1
      l = (P[1] < H[1]) ? P[1] : H[1]
      t = (P[2] < H[2]) ? P[2] : H[2]
      pr = P[1] + P[3]; hr = H[1] + H[3]
      pb = P[2] + P[4]; hb = H[2] + H[4]
      r = (pr > hr) ? pr : hr
      b = (pb > hb) ? pb : hb
      l -= M; t -= M; r += M; b += M
      if (l < D[1]) l = D[1]
      if (t < D[2]) t = D[2]
      if (r > D[1] + D[3]) r = D[1] + D[3]
      if (b > D[2] + D[4]) b = D[2] + D[4]
      if (r <= l || b <= t) exit 1
      printf "%g %g %g %g\n", l, t, r - l, b - t
    }
  '
}

# _shot_capture dir name cmd args...
# Runs "cmd args... dir/<name>.tmp.png" through ext and publishes it as
# dir/<name> on success.
_shot_capture() {
  local dir="$1" name="$2"
  shift 2
  local base="${name%.png}"
  local tmp="$dir/$base.tmp.png" final="$dir/$name"
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext "$@" "$tmp"
    return 0
  fi
  rm -f "$tmp"
  if ext "$@" "$tmp" && [ -s "$tmp" ]; then
    if mv -f "$tmp" "$final"; then
      return 0
    fi
  fi
  rm -f "$tmp"
  printf 'skipped %s\n' "$name" >&2
  return 1
}

# shot_screen dir [display]
# Full-display capture to dir/screen.png. Main display when display is empty.
shot_screen() {
  local dir="$1" display="${2:-}"
  if [ -n "$display" ]; then
    _shot_capture "$dir" screen.png screencapture -x "-D$display"
  else
    _shot_capture "$dir" screen.png screencapture -x
  fi
}

# shot_window dir id file
# Captures one window by number. file must be prompt.png or hud.png.
shot_window() {
  local dir="$1" id="$2" file="$3"
  case "$file" in
    prompt.png | hud.png) ;;
    *)
      printf 'skipped %s\n' "$file" >&2
      return 1
      ;;
  esac
  case "$id" in
    '' | *[!0-9]*)
      printf 'skipped %s\n' "$file" >&2
      return 1
      ;;
  esac
  _shot_capture "$dir" "$file" screencapture -x -o "-l$id"
}

# shot_pair dir rect
# Captures the rectangle "x y w h" (spaces or commas) to dir/pair.png.
shot_pair() {
  local dir="$1" rect="$2" r
  r="$(printf '%s\n' "$rect" | awk '
    {
      n = split($0, p, /[ ,\t]+/)
      if (n != 4) exit 1
      for (i = 1; i <= 4; i++) if (p[i] !~ /^-?[0-9]+(\.[0-9]+)?$/) exit 1
      x = int(p[1]); if (x > p[1]) x--
      y = int(p[2]); if (y > p[2]) y--
      w = int(p[3]); if (w < p[3]) w++
      h = int(p[4]); if (h < p[4]) h++
      if (w <= 0 || h <= 0) exit 1
      printf "%d,%d,%d,%d\n", x, y, w, h
    }')" || {
    printf 'skipped pair.png\n' >&2
    return 1
  }
  _shot_capture "$dir" pair.png screencapture -x "-R$r"
}
