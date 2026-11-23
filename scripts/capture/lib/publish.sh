#!/usr/bin/env bash
# Publish step: copy a successful session's files to the assets folder under
# clear names, keep only the newest version, and remove the working folder.
# bash 3.2 compatible. Meant to be sourced, not executed.
#
# Layout: <assets>/<profile>/<mode>_<profile>_<scenario>_<file>, with "-"
# turned into "_" in the profile and scenario, for example
#   docs/demo/assets/deepseek-harness/baseline_deepseek_harness_desktop_prompt.png
# <assets> is $CAPTURE_PUBLISH_DIR, default <repo>/docs/demo/assets.
# Only *.png, *.mov, *.mp4 and manifest.json are published. capture.log and
# tcc-snapshot.json stay in the working folder (local paths, TCC rows).

# publish_dir: root of the published assets.
publish_dir() {
  printf '%s\n' "${CAPTURE_PUBLISH_DIR:-${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}/docs/demo/assets}"
}

# publish_prefix mode profile scenario
# Pure. Prints <mode>_<profile>_<scenario>_ with "-" replaced by "_".
publish_prefix() {
  local p s
  p="$(printf '%s' "$2" | tr '-' '_')"
  s="$(printf '%s' "$3" | tr '-' '_')"
  printf '%s_%s_%s_\n' "$1" "$p" "$s"
}

# publish_wanted file
# Pure. Returns 0 for a file name that is published.
publish_wanted() {
  case "$1" in
    .* | *.tmp | *.tmp.*) return 1 ;;
    *.png | *.mov | *.mp4 | manifest.json) return 0 ;;
  esac
  return 1
}

# publish_session session_dir profile scenario mode
# Replaces the earlier published files of this mode, profile and scenario with
# the session's files and prints "published: <dir>/<prefix>* (<n> files)".
# Returns 1 when the folder cannot be written. Dry-run prints the target only.
publish_session() {
  local dir="$1" profile="$2" scenario="$3" mode="$4" out prefix f name n=0
  out="$(publish_dir)/$profile"
  prefix="$(publish_prefix "$mode" "$profile" "$scenario")"
  if [ "$CAPTURE_DRY_RUN" = "1" ]; then
    printf 'would publish to %s/%s*\n' "$out" "$prefix"
    return 0
  fi
  mkdir -p "$out" 2>/dev/null || { printf 'cannot create %s\n' "$out" >&2; return 1; }
  for f in "$out/$prefix"*; do
    [ -e "$f" ] && rm -f "$f"
  done
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    publish_wanted "$name" || continue
    cp -p "$f" "$out/$prefix$name" || { printf 'cannot copy %s to %s\n' "$f" "$out" >&2; return 1; }
    n=$((n + 1))
  done
  printf 'published: %s/%s* (%s files)\n' "$out" "$prefix" "$n"
}

# publish_summary scenario_dir profile scenario
# Copies <scenario_dir>/summary.md to <assets>/<profile>/<profile>_<scenario>_summary.md
# with each "](baseline/x)" or "](ward/x)" link rewritten to the published name.
publish_summary() {
  local src="$1/summary.md" profile="$2" scenario="$3" out bp wp
  [ -f "$src" ] || return 0
  out="$(publish_dir)/$profile"
  bp="$(publish_prefix baseline "$profile" "$scenario")"
  wp="$(publish_prefix ward "$profile" "$scenario")"
  mkdir -p "$out" || return 1
  # Rewrite links to published names; drop links to files that are not
  # published (capture.log, tcc-snapshot.json) and rows left with no link.
  sed -e "s#](baseline/#](${bp}#g" -e "s#](ward/#](${wp}#g" \
    -e 's#\[capture\.log\]([^)]*)##g' -e 's#\[tcc-snapshot\.json\]([^)]*)##g' "$src" |
    grep -v -E '^\|[[:space:]]*\|[[:space:]]*\|$' >"$out/${bp#baseline_}summary.md"
}

# publish_cleanup session_dir
# Removes a published session's working folder, then each parent left empty,
# up to the run timestamp folder. Refuses any path not under captures/<ts>/.
publish_cleanup() {
  local dir="$1" root
  root="${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}/captures"
  case "$dir" in
    "$root"/?*/?*/?*/?*) ;;
    *) printf 'not removing unexpected path: %s\n' "$dir" >&2; return 1 ;;
  esac
  rm -rf "$dir"
  dir="$(dirname "$dir")"
  while [ "${#dir}" -gt "${#root}" ]; do
    rmdir "$dir" 2>/dev/null || break
    dir="$(dirname "$dir")"
  done
  return 0
}
