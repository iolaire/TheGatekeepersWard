#!/usr/bin/env bash
# Video recording: start and stop the recorder, check the result.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Backends: "screencapture" (screencapture -v, writes flow.mov) and "ffmpeg"
# (AVFoundation, writes flow.mp4). Every external command goes through ext.
# The recorder PID lives in $CAPTURE_STATE_DIR/recorder.pid and the output
# path in recorder.path beside it, so cleanup from a fresh shell can stop and
# check a recording left by an earlier process.

_VIDEO_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=common.sh
. "$_VIDEO_LIB_DIR/common.sh"

# Seconds the recorder must stay alive after launch (requirement 8.6).
: "${VIDEO_LIVENESS_SECS:=1}"
# Seconds to wait for the recorder to exit after SIGINT (requirements 8.3, 8.8).
: "${VIDEO_FINALIZE_SECS:=10}"

# _video_state_dir: directory that holds recorder.pid.
_video_state_dir() {
  if [ -n "${CAPTURE_STATE_DIR:-}" ]; then
    printf '%s\n' "$CAPTURE_STATE_DIR"
    return 0
  fi
  local root="${CAPTURE_REPO_ROOT:-$(cd "$_VIDEO_LIB_DIR/../../.." && pwd)}"
  printf '%s\n' "$root/captures/.state"
}

# _video_ffmpeg_device display
# Prints the AVFoundation index of "Capture screen <display-1>" (display is
# 1-based, default 1). Returns 1 when the device is not listed.
_video_ffmpeg_device() {
  local display="${1:-1}" n
  case "$display" in '' | *[!0-9]*) return 1 ;; esac
  [ "$display" -ge 1 ] || return 1
  n=$((display - 1))
  ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 |
    awk -v want="Capture screen $n" '
      {
        line = $0
        if (match(line, /\[[0-9]+\] Capture screen [0-9]+$/)) {
          s = substr(line, RSTART, RLENGTH)
          idx = s; sub(/^\[/, "", idx); sub(/\].*$/, "", idx)
          name = s; sub(/^\[[0-9]+\] /, "", name)
          if (name == want) { print idx; found = 1; exit }
        }
      }
      END { exit found ? 0 : 1 }'
}

# video_start dir backend display
# Starts the recorder in the background, records its PID, waits
# VIDEO_LIVENESS_SECS and returns 1 (message on stderr) when the process is
# gone. Prints nothing on success. Backend defaults to screencapture.
video_start() {
  local dir="$1" backend="${2:-screencapture}" display="${3:-}"
  local out state pid_file path_file
  local -a cmd

  case "$backend" in
    screencapture)
      out="$dir/flow.mov"
      cmd=(screencapture -v -x)
      if [ -n "$display" ]; then cmd[${#cmd[@]}]="-D$display"; fi
      cmd[${#cmd[@]}]="$out"
      ;;
    ffmpeg)
      out="$dir/flow.mp4"
      # Dry-run continues without ffmpeg; runner_steps prints the note.
      if [ "$CAPTURE_DRY_RUN" != "1" ] && ! command -v ffmpeg >/dev/null 2>&1; then
        printf 'ffmpeg was not found; install it or use --video-backend screencapture\n' >&2
        return 1
      fi
      local idx
      if [ "$CAPTURE_DRY_RUN" = "1" ]; then
        idx="<screen>"
      else
        idx="$(_video_ffmpeg_device "${display:-1}")" || {
          printf 'video backend failure: ffmpeg found no screen device for display %s\n' "${display:-1}" >&2
          return 1
        }
      fi
      cmd=(ffmpeg -hide_banner -loglevel error -y -f avfoundation -framerate 30 -i "$idx:none" "$out")
      ;;
    *)
      printf 'video backend failure: unknown backend %s\n' "$backend" >&2
      return 1
      ;;
  esac

  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext "${cmd[@]}"
    return 0
  fi

  state="$(_video_state_dir)"
  pid_file="$state/recorder.pid"
  path_file="$state/recorder.path"
  mkdir -p "$state" || {
    printf 'video backend failure: cannot create %s\n' "$state" >&2
    return 1
  }

  # Job control gives the recorder its own process group and keeps SIGINT
  # deliverable: a plain background job in a script has SIGINT ignored.
  local had_m=0 pid
  case "$-" in *m*) had_m=1 ;; esac
  set -m
  ext exec "${cmd[@]}" </dev/null >"$state/recorder.log" 2>&1 &
  pid=$!
  [ "$had_m" = "1" ] || set +m

  printf '%s\n' "$pid" >"$pid_file"
  printf '%s\n' "$out" >"$path_file"
  _VIDEO_FILE="$out"

  sleep "$VIDEO_LIVENESS_SECS"
  if ! kill -0 "$pid" 2>/dev/null; then
    printf 'video backend failure: %s exited within %s s of launch\n' "$backend" "$VIDEO_LIVENESS_SECS" >&2
    rm -f "$pid_file"
    return 1
  fi
  return 0
}

# video_stop [file]
# Sends SIGINT to the PID in recorder.pid, waits up to VIDEO_FINALIZE_SECS for
# exit, then checks that the file exists and is non-empty. On success prints
# "size=<bytes> duration=<seconds>" and returns 0. On failure prints the
# reason on stderr and returns 1 so the caller marks the video failed.
# Returns 0 and prints nothing when no recorder was started.
video_stop() {
  local file="${1:-${_VIDEO_FILE:-}}" state pid_file path_file pid i waited
  state="$(_video_state_dir)"
  pid_file="$state/recorder.pid"
  path_file="$state/recorder.path"

  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    ext kill -INT "<recorder pid>"
    return 0
  fi

  [ -n "$file" ] || { [ -f "$path_file" ] && file="$(cat "$path_file")"; }
  [ -f "$pid_file" ] || return 0
  pid="$(cat "$pid_file" 2>/dev/null)"
  case "$pid" in '' | *[!0-9]*)
    rm -f "$pid_file" "$path_file"
    printf 'video failed: invalid recorder pid\n' >&2
    return 1
    ;;
  esac

  if kill -0 "$pid" 2>/dev/null; then
    ext kill -INT "$pid" 2>/dev/null
    # Poll in 0.2 s steps.
    waited=0
    i=0
    while kill -0 "$pid" 2>/dev/null; do
      if [ "$i" -ge $((VIDEO_FINALIZE_SECS * 5)) ]; then
        waited=1
        break
      fi
      sleep 0.2
      i=$((i + 1))
    done
    if [ "$waited" = "1" ]; then
      rm -f "$pid_file" "$path_file"
      printf 'video failed: recorder did not exit within %s s of SIGINT\n' "$VIDEO_FINALIZE_SECS" >&2
      return 1
    fi
  fi
  rm -f "$pid_file" "$path_file"

  if [ -z "$file" ] || [ ! -s "$file" ]; then
    printf 'video failed: %s is missing or empty\n' "${file:-video file}" >&2
    return 1
  fi
  local size dur
  size="$(wc -c <"$file" | tr -d ' ')"
  dur="$(video_duration "$file")" || dur=0
  printf 'size=%s duration=%s\n' "$size" "$dur"
  return 0
}

# video_duration file
# Prints the duration in seconds (decimal) via AVFoundation. Returns 1 and
# prints nothing when the file cannot be read.
video_duration() {
  local file="$1" out
  [ -n "$file" ] && [ -s "$file" ] || return 1
  out="$(ext osascript -l JavaScript -e '
    function run(argv) {
      ObjC.import("AVFoundation");
      $.NSBundle.bundleWithPath("/System/Library/Frameworks/AVFoundation.framework").load;
      var url = $.NSURL.fileURLWithPath(argv[0]);
      var asset = $.NSClassFromString("AVURLAsset").URLAssetWithURLOptions(url, $());
      // JXA cannot read a CMTime struct directly. Copy it out of the NSValue
      // and decode value (int64, LE) and timescale (int32, LE) from the hex.
      var buf = $.NSMutableData.dataWithLength(24);
      asset.valueForKey("duration").getValue(buf.mutableBytes);
      var hex = ObjC.unwrap(buf.description).split("0x").pop().replace(/[^0-9a-f]/g, "");
      function le(h) { var r = 0, m = 1; for (var i = 0; i < h.length; i += 2) { r += parseInt(h.substr(i, 2), 16) * m; m *= 256; } return r; }
      var value = le(hex.substr(0, 16)), scale = le(hex.substr(16, 8));
      if (!scale) return "0";
      var s = value / scale;
      return (isFinite(s) && s > 0) ? s.toFixed(3) : "0";
    }' "$file" 2>/dev/null)" || return 1
  case "$out" in
    '' | *[!0-9.]*) return 1 ;;
  esac
  printf '%s\n' "$out"
}

# video_playable file
# Exit 0 when video_duration returns a value above 0.
video_playable() {
  local d
  d="$(video_duration "$1")" || return 1
  awk -v d="$d" 'BEGIN { exit (d + 0 > 0) ? 0 : 1 }'
}
