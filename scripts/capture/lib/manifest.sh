#!/usr/bin/env bash
# Manifest accumulation, writing and validation for the capture framework.
# bash 3.2 compatible. Meant to be sourced, not executed.
# JSON is built and parsed by osascript -l JavaScript (lib/json.js); no jq, no Python.
#
# Fields are stored one per file in a scratch directory (f.<key>, raw value) plus
# an "artifacts" file (one name per line), so values may hold any text.
# Dotted keys nest: prompt.bounds.x, hud.detected_at, video.bytes, ...

: "${CAPTURE_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MANIFEST_JSON_JS="$CAPTURE_DIR/lib/json.js"
MANIFEST_MAX_ARTIFACTS=50

# manifest_scratch: prints the scratch directory path (stable per shell PID).
manifest_scratch() {
  if [ -n "${CAPTURE_MANIFEST_TMP:-}" ]; then
    printf '%s\n' "$CAPTURE_MANIFEST_TMP"
    return 0
  fi
  local root="${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$CAPTURE_DIR/../.." && pwd)}/captures/.state}"
  printf '%s\n' "$root/tmp.$$"
}

# manifest_reset: deletes the scratch directory.
manifest_reset() {
  local d
  d="$(manifest_scratch)"
  case "$d" in
    */tmp.*|"${CAPTURE_MANIFEST_TMP:-/nonexistent-unset}") rm -rf "$d" ;;
  esac
}

# manifest_set key value
# Adds or replaces a scalar field. Keys are lower case words joined by dots.
manifest_set() {
  local key="${1:-}" value="${2-}" d
  case "$key" in
    ''|*[!a-z0-9_.]*|.*|*.|*..*)
      printf 'manifest_set: invalid key: %s\n' "$key" >&2
      return 2 ;;
  esac
  if [ "$key" = "outcome" ]; then
    case "$value" in
      ok|no_prompt|no_hud|error) ;;
      *) printf 'manifest_set: outcome must be ok, no_prompt, no_hud or error: %s\n' "$value" >&2
         return 2 ;;
    esac
  fi
  d="$(manifest_scratch)"
  mkdir -p "$d" || return 1
  printf '%s' "$value" >"$d/f.$key"
}

# manifest_add_artifact name
# Appends a plain relative file name. At most 50 entries; no path separators.
manifest_add_artifact() {
  local name="${1-}" d count
  case "$name" in
    ''|.|..|*/*|*\\*)
      printf 'manifest_add_artifact: not a plain relative file name: %s\n' "$name" >&2
      return 2 ;;
  esac
  case "$name" in
    *[[:cntrl:]]*)
      printf 'manifest_add_artifact: control character in name\n' >&2
      return 2 ;;
  esac
  d="$(manifest_scratch)"
  mkdir -p "$d" || return 1
  count=0
  if [ -f "$d/artifacts" ]; then
    if grep -qxF -- "$name" "$d/artifacts"; then return 0; fi
    count="$(wc -l <"$d/artifacts" | tr -d ' ')"
  fi
  if [ "$count" -ge "$MANIFEST_MAX_ARTIFACTS" ]; then
    printf 'manifest_add_artifact: more than %s artifacts\n' "$MANIFEST_MAX_ARTIFACTS" >&2
    return 1
  fi
  printf '%s\n' "$name" >>"$d/artifacts"
}

# manifest_check file
# Prints nothing and returns 0 when valid; otherwise prints the reason to stderr, returns 1.
manifest_check() {
  local file="${1:-}" out
  if [ ! -f "$file" ]; then
    printf 'manifest_check: no such file: %s\n' "$file" >&2
    return 1
  fi
  out="$(osascript -l JavaScript "$MANIFEST_JSON_JS" check "$file" 2>&1)" || {
    printf 'manifest_check: %s\n' "$out" >&2
    return 1
  }
  if [ "$out" = "ok" ]; then return 0; fi
  printf 'manifest_check: %s\n' "$out" >&2
  return 1
}

# manifest_write dir
# Builds dir/manifest.json from the scratch fields, validates it, removes the scratch directory.
# On validation failure the file is removed so the directory never holds an invalid manifest.
manifest_write() {
  local dir="${1:-}" d tmp
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    printf 'manifest_write: not a directory: %s\n' "$dir" >&2
    return 1
  fi
  d="$(manifest_scratch)"
  mkdir -p "$d" || return 1
  tmp="$d/manifest.out"
  if ! osascript -l JavaScript "$MANIFEST_JSON_JS" build "$d" >"$tmp"; then
    printf 'manifest_write: build failed\n' >&2
    return 1
  fi
  if ! manifest_check "$tmp"; then
    return 1
  fi
  mv "$tmp" "$dir/manifest.json" || return 1
  manifest_reset
}

# manifest_roundtrip file
# Re-serializes the file with json.js and compares parsed values. Returns 0 when equal.
manifest_roundtrip() {
  local file="${1:-}" tmp out
  tmp="$(mktemp "${TMPDIR:-/tmp}/manifest-rt.XXXXXX")" || return 1
  if ! osascript -l JavaScript "$MANIFEST_JSON_JS" reserialize "$file" >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  out="$(osascript -l JavaScript "$MANIFEST_JSON_JS" equal "$file" "$tmp")"
  rm -f "$tmp"
  [ "$out" = "equal" ]
}
