#!/usr/bin/env bash
# Permission Capture Framework entry point.
# Usage: capture.sh <subcommand> [options] [args]
# bash 3.2 compatible.

CAPTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_REPO_ROOT="$(cd "$CAPTURE_DIR/../.." && pwd)"
export CAPTURE_DIR CAPTURE_REPO_ROOT

# shellcheck source=lib/common.sh
. "$CAPTURE_DIR/lib/common.sh"
# shellcheck source=lib/defaults.sh
. "$CAPTURE_DIR/lib/defaults.sh"

# Source every library that exists. Libraries arrive in later tasks.
for _lib in validate profile tccdb restore reset plan session manifest windows shots video \
  ward app resolve cleanup setup focus export publish runner_steps runner; do
  # shellcheck disable=SC1090
  [ -f "$CAPTURE_DIR/lib/$_lib.sh" ] && . "$CAPTURE_DIR/lib/$_lib.sh"
done
unset _lib

usage() {
  cat <<'EOF'
Usage: capture.sh <subcommand> [options]

Subcommands:
  setup                         Check and request permissions
  doctor                        Read-only check of permissions and tools
  teardown                      Undo everything the framework started
  reset <profile>               Scoped tccutil reset  [--service <svc>] [--dry-run]
  restore [<profile>]           Restore a pending TCC snapshot  [--dry-run]
  prompt <profile> <scenario>   Run one Capture_Session
  run <profile> <scenario>      Run baseline then ward
  list                          List profiles and scenarios
  export <dir>                  Copy screenshots and videos to <dir>

Options for prompt and run:
  --mode baseline|ward   --resolve allow|deny|none   --no-reset   --no-video
  --no-images   --video-backend screencapture|ffmpeg   --display <n>
  --dry-run   --redact-notifications   --no-restore
Options for setup, doctor and reset: --no-restore
Options for run only:
  --all-scenarios   --all-profiles   --keep-going
EOF
}

# Personal-data notice, printed before any Scenario runs (13.6).
print_notice() {
  cat >&2 <<'EOF'
NOTICE: screenshots and video captured by this tool may include personal data
visible on screen. The captures/ directory is excluded from version control.
EOF
}

# Parsed option state (globals; consumed by later libraries).
OPT_MODE=""
OPT_RESOLVE=""
OPT_SERVICE=""
OPT_DISPLAY=""
OPT_VIDEO_BACKEND=""
OPT_NO_RESET=0
OPT_NO_VIDEO=0
OPT_NO_IMAGES=0
OPT_ALL_SCENARIOS=0
OPT_ALL_PROFILES=0
OPT_KEEP_GOING=0
OPT_REDACT=0
OPT_NO_RESTORE=0
POSITIONAL=()

# parse_options subcommand args...
# Fills OPT_* and POSITIONAL. Exits 2 on an unknown option or a missing value.
parse_options() {
  local sub="$1"
  shift
  POSITIONAL=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) CAPTURE_DRY_RUN=1 ;;
      --service|--mode|--resolve|--display|--video-backend)
        case "$sub" in
          reset) [ "$1" = "--service" ] || die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
          prompt|run) [ "$1" != "--service" ] || die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
          doctor) [ "$1" = "--video-backend" ] || die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
          *) die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
        esac
        [ $# -ge 2 ] || die "$EXIT_USAGE" "option $1 needs a value"
        case "$1" in
          --service) OPT_SERVICE="$2" ;;
          --mode) OPT_MODE="$2" ;;
          --resolve) OPT_RESOLVE="$2" ;;
          --display) OPT_DISPLAY="$2" ;;
          --video-backend) OPT_VIDEO_BACKEND="$2" ;;
        esac
        shift
        ;;
      --no-reset|--no-video|--no-images|--redact-notifications)
        case "$sub" in
          prompt|run) ;;
          *) die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
        esac
        case "$1" in
          --no-reset) OPT_NO_RESET=1 ;;
          --no-video) OPT_NO_VIDEO=1 ;;
          --no-images) OPT_NO_IMAGES=1 ;;
          --redact-notifications) OPT_REDACT=1 ;;
        esac
        ;;
      --no-restore)
        case "$sub" in
          setup|doctor|reset|prompt|run) OPT_NO_RESTORE=1 ;;
          *) die "$EXIT_USAGE" "option $1 is not valid for '$sub'" ;;
        esac
        ;;
      --all-scenarios|--all-profiles|--keep-going)
        [ "$sub" = "run" ] || die "$EXIT_USAGE" "option $1 is only valid for 'run'"
        case "$1" in
          --all-scenarios) OPT_ALL_SCENARIOS=1 ;;
          --all-profiles) OPT_ALL_PROFILES=1 ;;
          --keep-going) OPT_KEEP_GOING=1 ;;
        esac
        ;;
      --) shift; while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done; break ;;
      -*) die "$EXIT_USAGE" "unknown option: $1" ;;
      *) POSITIONAL+=("$1") ;;
    esac
    shift
  done
  export CAPTURE_DRY_RUN OPT_NO_RESTORE
}

# not_implemented name: placeholder until the owning library is sourced.
not_implemented() {
  die "$EXIT_FAIL" "subcommand '$1' is not implemented yet"
}

# dispatch_fn subcommand function: call the library function if defined.
dispatch_fn() {
  local sub="$1" fn="$2"
  shift 2
  if command -v "$fn" >/dev/null 2>&1; then
    "$fn" "$@"
  else
    not_implemented "$sub"
  fi
}

main() {
  if [ $# -eq 0 ]; then
    usage >&2
    exit "$EXIT_USAGE"
  fi
  local sub="$1"
  shift
  case "$sub" in
    -h|--help|help) usage; exit "$EXIT_OK" ;;
    setup|doctor|teardown|reset|restore|prompt|run|list|export) ;;
    *) usage >&2; die "$EXIT_USAGE" "unknown subcommand: $sub" ;;
  esac

  parse_options "$sub" "$@"

  case "$sub" in
    prompt|run)
      # Notice precedes any Scenario, including dry-run output.
      print_notice
      if command -v install_cleanup_traps >/dev/null 2>&1; then install_cleanup_traps; fi
      dispatch_fn "$sub" "cmd_$sub" "${POSITIONAL[@]}"
      ;;
    *)
      dispatch_fn "$sub" "cmd_$sub" "${POSITIONAL[@]}"
      ;;
  esac
}

main "$@"
