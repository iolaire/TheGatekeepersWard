#!/usr/bin/env bash
# App_Profile loading, parsing and validation.
# Profiles are PARSED, never sourced: content is only ever read as data.
# bash 3.2 compatible: no associative arrays, no mapfile, no ${var,,}.
# Meant to be sourced, not executed.
#
# File format: blank lines, "# comment" lines, and "key = value" lines.
#   profile_id = zcode
#   scenario.<name>.prompt|service|prompt_timeout|dwell = ...
# A trailing " # comment" is removed only for the numeric and enum fields
# (launch_timeout, send_method, ax_manual_accessibility, prompt_timeout, dwell). Every other value is
# kept verbatim, so a prompt may contain " #".

CAPTURE_PROFILE_REQUIRED="profile_id display_name bundle_id launch input_locator send_action"
CAPTURE_MAX_SCENARIOS=20
CAPTURE_PROMPT_MAX_CHARS=2000

# Filled by profile_load_all.
CAPTURE_PROFILE_IDS=()
CAPTURE_PROFILE_FILES=()

# profile_dir: directory holding *.profile files.
profile_dir() {
  printf '%s\n' "${CAPTURE_PROFILES_DIR:-${CAPTURE_DIR:-.}/profiles}"
}

# _profile_trim text: strip leading and trailing whitespace.
_profile_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# _profile_strip_comment key value: print value, minus a trailing " # ..." for
# keys that never hold free text.
_profile_strip_comment() {
  local key="$1" v="$2"
  case "$key" in
    launch_timeout|approve_timeout|send_method|ax_manual_accessibility|scenario.*.prompt_timeout|scenario.*.dwell)
      case "$v" in
        '#'*) v="" ;;
        *[[:space:]]'#'*) v="${v%%[[:space:]]#*}" ;;
      esac
      ;;
  esac
  _profile_trim "$v"
}

# profile_parse path
# Prints "key<TAB>value" per assignment. Returns 1 and prints
# "path:LINE: <reason>" on a line that is not blank, a comment, or key = value,
# and on a duplicate key. Returns 1 when the file cannot be read.
profile_parse() {
  local path="$1" line key val n=0 rc=0 seen=$'\n'
  [ -f "$path" ] && [ -r "$path" ] || { echo "$path: cannot read profile" >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%$'\r'}"
    line="$(_profile_trim "$line")"
    case "$line" in
      ''|'#'*) continue ;;
      *=*) ;;
      *) echo "$path:$n: not a 'key = value' line" >&2; rc=1; continue ;;
    esac
    key="$(_profile_trim "${line%%=*}")"
    val="$(_profile_trim "${line#*=}")"
    case "$key" in
      ''|*[!A-Za-z0-9_.-]*) echo "$path:$n: invalid key" >&2; rc=1; continue ;;
    esac
    case "$seen" in
      *$'\n'"$key"$'\n'*) echo "$path:$n: duplicate key '$key'" >&2; rc=1; continue ;;
    esac
    seen="$seen$key"$'\n'
    val="$(_profile_strip_comment "$key" "$val")"
    case "$val" in
      *$'\t'*) val="$(printf '%s' "$val" | tr '\t' ' ')" ;;
    esac
    printf '%s\t%s\n' "$key" "$val"
  done <"$path"
  return "$rc"
}

# _profile_get parsed key: print the value of key from parsed text (empty if absent).
_profile_get() {
  local k v
  while IFS=$'\t' read -r k v; do
    if [ "$k" = "$2" ]; then
      printf '%s' "$v"
      return 0
    fi
  done <<EOF
$1
EOF
  return 1
}

# _profile_scenario_names parsed: scenario names in declaration order, one per line.
_profile_scenario_names() {
  local k v rest name seen=$'\n'
  while IFS=$'\t' read -r k v; do
    case "$k" in
      scenario.*.*)
        rest="${k#scenario.}"
        name="${rest%.*}"
        case "$seen" in
          *$'\n'"$name"$'\n'*) ;;
          *) seen="$seen$name"$'\n'; printf '%s\n' "$name" ;;
        esac
        ;;
    esac
  done <<EOF
$1
EOF
}

# _profile_chars text: character count (locale-aware where a UTF-8 locale exists).
_profile_chars() {
  printf '%s' "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '
}

# profile_validate path
# Returns 0 for a valid profile. Otherwise prints one line per problem to
# stderr, each starting with the path, and returns 1.
profile_validate() {
  local path="$1" parsed rc=0 f v stem ids n name p svc t
  parsed="$(profile_parse "$path")" || return 1

  for f in $CAPTURE_PROFILE_REQUIRED; do
    v="$(_profile_get "$parsed" "$f")"
    if [ -z "$v" ]; then
      echo "$path: missing field $f" >&2
      rc=1
    fi
  done

  v="$(_profile_get "$parsed" profile_id)"
  stem="$(basename "$path")"
  stem="${stem%.profile}"
  if [ -n "$v" ] && [ "$v" != "$stem" ]; then
    echo "$path: profile_id '$v' does not match file name '$stem'" >&2
    rc=1
  fi

  v="$(_profile_get "$parsed" launch_timeout)"
  if [ -n "$v" ] && ! valid_range "$v" "$CAPTURE_TIMEOUT_MIN" "$CAPTURE_TIMEOUT_MAX"; then
    echo "$path: launch_timeout '$v' out of range $CAPTURE_TIMEOUT_MIN..$CAPTURE_TIMEOUT_MAX" >&2
    rc=1
  fi
  for f in prepare_action approve_tool_call; do
    v="$(_profile_get "$parsed" "$f")"
    case "$v" in
      '' | ax:?* | find:?*) ;;
      *) echo "$path: $f '$v' must start with ax: or find:" >&2; rc=1 ;;
    esac
  done
  v="$(_profile_get "$parsed" approve_timeout)"
  if [ -n "$v" ] && ! valid_range "$v" "$CAPTURE_TIMEOUT_MIN" "$CAPTURE_TIMEOUT_MAX"; then
    echo "$path: approve_timeout '$v' out of range $CAPTURE_TIMEOUT_MIN..$CAPTURE_TIMEOUT_MAX" >&2
    rc=1
  fi
  v="$(_profile_get "$parsed" send_method)"
  case "$v" in
    ''|clipboard|keystroke) ;;
    *) echo "$path: send_method '$v' must be clipboard or keystroke" >&2; rc=1 ;;
  esac
  v="$(_profile_get "$parsed" ax_manual_accessibility)"
  case "$v" in
    ''|true|false) ;;
    *) echo "$path: ax_manual_accessibility '$v' must be true or false" >&2; rc=1 ;;
  esac

  ids="$(_profile_scenario_names "$parsed")"
  n=0
  if [ -n "$ids" ]; then n="$(printf '%s\n' "$ids" | wc -l | tr -d ' ')"; fi
  if [ "$n" -eq 0 ]; then
    echo "$path: missing field scenario" >&2
    rc=1
  elif [ "$n" -gt "$CAPTURE_MAX_SCENARIOS" ]; then
    echo "$path: too many scenarios ($n, maximum $CAPTURE_MAX_SCENARIOS)" >&2
    rc=1
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$name" in
      *[!A-Za-z0-9_-]*) echo "$path: invalid scenario name '$name'" >&2; rc=1; continue ;;
    esac
    p="$(_profile_get "$parsed" "scenario.$name.prompt")"
    if [ -z "$p" ]; then
      echo "$path: missing field scenario.$name.prompt" >&2
      rc=1
    else
      t="$(_profile_chars "$p")"
      if [ "$t" -lt 1 ] || [ "$t" -gt "$CAPTURE_PROMPT_MAX_CHARS" ]; then
        echo "$path: scenario.$name.prompt length $t outside 1..$CAPTURE_PROMPT_MAX_CHARS" >&2
        rc=1
      fi
    fi
    svc="$(_profile_get "$parsed" "scenario.$name.service")"
    if [ -z "$svc" ]; then
      echo "$path: missing field scenario.$name.service" >&2
      rc=1
    fi
    v="$(_profile_get "$parsed" "scenario.$name.prompt_timeout")"
    if [ -n "$v" ] && ! valid_range "$v" "$CAPTURE_TIMEOUT_MIN" "$CAPTURE_TIMEOUT_MAX"; then
      echo "$path: scenario.$name.prompt_timeout '$v' out of range $CAPTURE_TIMEOUT_MIN..$CAPTURE_TIMEOUT_MAX" >&2
      rc=1
    fi
    v="$(_profile_get "$parsed" "scenario.$name.dwell")"
    if [ -n "$v" ] && ! valid_range "$v" "$CAPTURE_DWELL_MIN" "$CAPTURE_DWELL_MAX"; then
      echo "$path: scenario.$name.dwell '$v' out of range $CAPTURE_DWELL_MIN..$CAPTURE_DWELL_MAX" >&2
      rc=1
    fi
  done <<EOF
$ids
EOF
  return "$rc"
}

# profile_load_all dir
# Validates every *.profile in dir (other files are skipped) and fills
# CAPTURE_PROFILE_IDS / CAPTURE_PROFILE_FILES in name order. Returns 2 after
# printing every error when any profile is invalid; then the arrays are empty.
profile_load_all() {
  local dir="$1" f stem rc=0
  CAPTURE_PROFILE_IDS=()
  CAPTURE_PROFILE_FILES=()
  CAPTURE_PROFILE_PARSED=()
  [ -d "$dir" ] || return 0
  for f in "$dir"/*.profile; do
    [ -f "$f" ] || continue
    if profile_validate "$f"; then
      stem="$(basename "$f")"
      CAPTURE_PROFILE_IDS+=("${stem%.profile}")
      CAPTURE_PROFILE_FILES+=("$f")
      # Parsed once here; profile_field and friends read this copy, also from
      # the $(...) subshells they usually run in. Profiles do not change mid-run.
      CAPTURE_PROFILE_PARSED+=("$(profile_parse "$f")")
    else
      rc=2
    fi
  done
  if [ "$rc" -ne 0 ]; then
    CAPTURE_PROFILE_IDS=()
    CAPTURE_PROFILE_FILES=()
    CAPTURE_PROFILE_PARSED=()
  fi
  return "$rc"
}

# profile_file id: path of the profile. An argument containing "/" is used as a path.
profile_file() {
  case "$1" in
    */*) printf '%s\n' "$1" ;;
    *) printf '%s/%s.profile\n' "$(profile_dir)" "$1" ;;
  esac
}

# _profile_text id: parsed "key<TAB>value" text of a profile. Uses the copy
# profile_load_all stored for that file, else parses the file.
_profile_text() {
  local path i
  path="$(profile_file "$1")"
  for i in "${!CAPTURE_PROFILE_FILES[@]}"; do
    if [ "${CAPTURE_PROFILE_FILES[$i]}" = "$path" ] && [ -n "${CAPTURE_PROFILE_PARSED[$i]+x}" ]; then
      printf '%s\n' "${CAPTURE_PROFILE_PARSED[$i]}"
      return 0
    fi
  done
  profile_parse "$path"
}

# profile_field id key: value of a top-level field.
profile_field() {
  local parsed
  parsed="$(_profile_text "$1")" || return 1
  _profile_get "$parsed" "$2"
}

# profile_scenarios id: scenario names in declaration order, one per line.
profile_scenarios() {
  local parsed
  parsed="$(_profile_text "$1")" || return 1
  _profile_scenario_names "$parsed"
}

# profile_services id: distinct scenario service keys in declaration order.
profile_services() {
  local parsed k v seen=$'\n'
  parsed="$(_profile_text "$1")" || return 1
  while IFS=$'\t' read -r k v; do
    case "$k" in
      scenario.*.service)
        [ -n "$v" ] || continue
        case "$seen" in
          *$'\n'"$v"$'\n'*) ;;
          *) seen="$seen$v"$'\n'; printf '%s\n' "$v" ;;
        esac
        ;;
    esac
  done <<EOF
$parsed
EOF
}

# cmd_list: one line per profile: profile_id<TAB>bundle_id<TAB>scenario,scenario,...
# Exit 2 on an invalid profile, 1 when none is loadable.
cmd_list() {
  local i id bundle names
  profile_load_all "$(profile_dir)" || exit "$EXIT_USAGE"
  if [ "${#CAPTURE_PROFILE_IDS[@]}" -eq 0 ]; then
    echo "no profiles found in $(profile_dir)"
    exit "$EXIT_FAIL"
  fi
  for i in "${!CAPTURE_PROFILE_IDS[@]}"; do
    id="${CAPTURE_PROFILE_IDS[$i]}"
    bundle="$(profile_field "${CAPTURE_PROFILE_FILES[$i]}" bundle_id)"
    names="$(profile_scenarios "${CAPTURE_PROFILE_FILES[$i]}" | tr '\n' ',')"
    printf '%s\t%s\t%s\n' "$id" "$bundle" "${names%,}"
  done
}
