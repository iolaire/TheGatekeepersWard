#!/usr/bin/env bash
# Shared helper: print the file paths a Kiro hook should inspect.
# Usage: source this file, then call `target_files <glob-regex> <fallback-dir>...`.
# Kiro passes hook context as JSON on stdin; we pull any string that looks like
# a path matching the regex. If none is found (or stdin is a TTY) we fall back
# to scanning every matching file under the fallback directories.

target_files() {
  local pattern="$1"; shift
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  local from_stdin=""
  if [ ! -t 0 ] && command -v python3 >/dev/null 2>&1; then
    from_stdin="$(python3 - "$pattern" <<'PY' 2>/dev/null || true
import json, re, sys
pattern = re.compile(sys.argv[1])
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
found = []
def walk(node):
    if isinstance(node, dict):
        for v in node.values(): walk(v)
    elif isinstance(node, list):
        for v in node: walk(v)
    elif isinstance(node, str) and "\n" not in node and pattern.search(node):
        found.append(node)
walk(data)
print("\n".join(dict.fromkeys(found)))
PY
)"
  fi
  if [ -n "$from_stdin" ]; then
    while IFS= read -r f; do
      case "$f" in /*) ;; *) f="$root/$f" ;; esac
      [ -f "$f" ] && echo "$f"
    done <<< "$from_stdin"
    return 0
  fi
  local d
  for d in "$@"; do
    [ -d "$root/$d" ] && find "$root/$d" -type f -name '*.swift' | grep -E "$pattern" || true
  done
}
