#!/usr/bin/env bash
# export subcommand: copy screenshots and videos out of captures/.
# bash 3.2 compatible. Meant to be sourced, not executed.

# export_dest_name captures_root file
# Pure. Maps captures/<ts>/<profile>/<scenario>/<mode>/<file> to
# <ts>__<profile>__<scenario>__<mode>__<file>. Prints nothing and returns 1
# when the path does not have that shape.
export_dest_name() {
  local rel="${2#"$1"/}" ts rest profile scenario mode file
  case "$rel" in
    */*/*/*/*) ;;
    *) return 1 ;;
  esac
  ts="${rel%%/*}"; rest="${rel#*/}"
  profile="${rest%%/*}"; rest="${rest#*/}"
  scenario="${rest%%/*}"; rest="${rest#*/}"
  mode="${rest%%/*}"; file="${rest#*/}"
  case "$file" in */*) return 1 ;; esac
  printf '%s__%s__%s__%s__%s\n' "$ts" "$profile" "$scenario" "$mode" "$file"
}

# export_list captures_root
# Prints NUL-free, newline-separated paths of *.png and flow.* files that sit
# at <ts>/<profile>/<scenario>/<mode>/<file>, in sorted order.
export_list() {
  [ -d "$1" ] || return 0
  find "$1" -mindepth 5 -maxdepth 5 -type f \( -name '*.png' -o -name 'flow.*' \) 2>/dev/null | LC_ALL=C sort
}

# cmd_export dir
# Copies each selected file with cp -p. Exit 1 with "nothing to export" when no
# file matches (creates nothing), or "destination not writable" when dir
# cannot be created or written.
cmd_export() {
  local dest="${1:-}" root files f name n=0
  [ -n "$dest" ] || die "$EXIT_USAGE" "usage: capture.sh export <dir>"
  root="${CAPTURE_ROOT:-$CAPTURE_REPO_ROOT}/captures"
  files="$(export_list "$root")"
  if [ -z "$files" ]; then
    die "$EXIT_FAIL" "nothing to export: no *.png or flow.* files under $root"
  fi
  if ! mkdir -p "$dest" 2>/dev/null || [ ! -d "$dest" ] || [ ! -w "$dest" ]; then
    die "$EXIT_FAIL" "destination not writable: $dest"
  fi
  while IFS= read -r f; do
    name="$(export_dest_name "$root" "$f")" || continue
    cp -p "$f" "$dest/$name" 2>/dev/null || die "$EXIT_FAIL" "destination not writable: $dest"
    n=$((n + 1))
  done <<EOF2
$files
EOF2
  printf 'exported %s file(s) to %s\n' "$n" "$dest"
}
