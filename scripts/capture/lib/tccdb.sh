#!/usr/bin/env bash
# TCC_Access_Module: the ONLY file that names a TCC database.
# Opens only the user-level database (or a temp copy for tests, selected through
# CAPTURE_TCC_DB_TEST under the system temporary directory). Never the
# system-level database. Every SQL script goes to sqlite3 on stdin and starts
# with ".bail on". sqlite3 is called from PATH so tests can wrap it.
# bash 3.2 compatible: no associative arrays, no mapfile, no ${var,,}.
# Meant to be sourced, not executed.

_TCCDB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$_TCCDB_DIR/reset.sh"

# tcc_realpath path
# Prints path with symbolic links resolved. The last component need not exist:
# its parent directory is resolved and the name appended. Returns 1 when the
# parent directory cannot be resolved.
tcc_realpath() {
  local p="${1-}" dir base link n=0
  [ -n "$p" ] || return 1
  while [ -L "$p" ] && [ "$n" -lt 40 ]; do
    link="$(readlink "$p")" || return 1
    case "$link" in
      /*) p="$link" ;;
      *) p="$(dirname "$p")/$link" ;;
    esac
    n=$((n + 1))
  done
  [ "$n" -lt 40 ] || return 1
  if [ -d "$p" ]; then
    (cd -P "$p" 2>/dev/null && pwd -P)
    return
  fi
  dir="$(dirname "$p")"
  base="$(basename "$p")"
  local missing=""
  # Walk up to the nearest existing ancestor; the missing tail is appended
  # as-is, and refused when it holds a "." or ".." component.
  while [ ! -d "$dir" ]; do
    case "$base" in "" | . | ..) return 1 ;; esac
    missing="$base${missing:+/$missing}"
    base="$(basename "$dir")"
    local next
    next="$(dirname "$dir")"
    [ "$next" != "$dir" ] || return 1
    dir="$next"
  done
  case "$base" in "" | . | ..) return 1 ;; esac
  dir="$(cd -P "$dir" 2>/dev/null && pwd -P)" || return 1
  [ -z "$missing" ] || base="$base/$missing"
  case "$dir" in
    /) printf '/%s\n' "$base" ;;
    *) printf '%s/%s\n' "$dir" "$base" ;;
  esac
}

# tcc_path_ok candidate home tmpdir test_env
# Pure apart from reading symlinks. Returns 0 when the symlink-resolved
# candidate equals <home>/Library/Application Support/com.apple.TCC/TCC.db, or
# when test_env is non-empty and the resolved candidate lies strictly inside the
# resolved tmpdir. Otherwise prints "refusing database path '<p>'" and returns 1.
tcc_path_ok() {
  local candidate="${1-}" home="${2-}" tmpdir="${3-}" test_env="${4-}"
  local rc rh rt user_db
  rc="$(tcc_realpath "$candidate" 2>/dev/null)" || rc=""
  if [ -n "$rc" ] && [ -n "$home" ]; then
    rh="$(tcc_realpath "$home" 2>/dev/null)" || rh=""
    if [ -n "$rh" ]; then
      user_db="$rh/Library/Application Support/com.apple.TCC/TCC.db"
      # Resolve the user database too, so a symlinked Library still matches.
      user_db="$(tcc_realpath "$user_db" 2>/dev/null)" || user_db="$rh/Library/Application Support/com.apple.TCC/TCC.db"
      if [ "$rc" = "$user_db" ]; then
        return 0
      fi
    fi
  fi
  if [ -n "$rc" ] && [ -n "$test_env" ] && [ -n "$tmpdir" ]; then
    rt="$(tcc_realpath "$tmpdir" 2>/dev/null)" || rt=""
    if [ -n "$rt" ] && [ "$rt" != "/" ]; then
      case "$rc" in
        "$rt"/?*) return 0 ;;
      esac
    fi
  fi
  printf "refusing database path '%s'\n" "$candidate" >&2
  return 1
}

# tcc_db_path
# Prints the database path: $CAPTURE_TCC_DB_TEST when set, else the user
# database. Checks it with tcc_path_ok against $HOME and the system temporary
# directories. Returns 1 on refusal.
tcc_db_path() {
  local candidate t darwin_tmp
  if [ -n "${CAPTURE_TCC_DB_TEST-}" ]; then
    candidate="$CAPTURE_TCC_DB_TEST"
  else
    candidate="${HOME-}/Library/Application Support/com.apple.TCC/TCC.db"
  fi
  darwin_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null)" || darwin_tmp=""
  for t in "$darwin_tmp" /tmp /private/tmp; do
    [ -n "$t" ] || continue
    if tcc_path_ok "$candidate" "${HOME-}" "$t" "${CAPTURE_TCC_DB_TEST-}" 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf "refusing database path '%s'\n" "$candidate" >&2
  return 1
}

# tcc_probe
# Returns 0 when sqlite3 exists and a read-only open of the database can read
# the access table. Writes nothing. Otherwise prints the cause and returns:
#   1  sqlite3 missing, path refused, or the file exists but cannot be opened
#   3  the user database is absent because its parent folder does not exist
#      (this macOS has no per-user TCC database); snapshot and restore are
#      unavailable, so callers point to --no-restore
tcc_probe() {
  local db err
  if ! command -v sqlite3 >/dev/null 2>&1; then
    printf 'sqlite3 not found\n' >&2
    return 1
  fi
  db="$(tcc_db_path)" || return 1
  if [ ! -d "$(dirname "$db")" ]; then
    printf 'no user TCC database on this macOS (%s); snapshot and restore are unavailable, use --no-restore\n' "$db" >&2
    return 3
  fi
  if [ ! -e "$db" ]; then
    printf 'database not found: %s\n' "$db" >&2
    return 1
  fi
  if err="$(sqlite3 -readonly "$db" 'SELECT 1 FROM access LIMIT 1' 2>&1 >/dev/null)"; then
    return 0
  fi
  printf '%s\n' "$err" >&2
  return 1
}

# sql_quote s
# Pure. Prints 'S' with each single quote doubled. Fails for a string with NUL
# (a NUL cannot be held in a bash string, so this checks the byte stream the
# caller passes through a here-string-free printf; callers pass bash strings).
sql_quote() {
  local s="${1-}"
  case "$s" in
    *"'"*) s="$(printf '%s' "$s" | sed "s/'/''/g"; printf x)"; s="${s%x}" ;;
  esac
  printf "'%s'" "$s"
}

# tcc_valid_bundle s
# Pure. Returns 0 for ^[A-Za-z0-9][A-Za-z0-9._-]*$ that is not "All" in any case.
tcc_valid_bundle() {
  local s="${1-}" lower
  [ -n "$s" ] || return 1
  lower="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  [ "$lower" != "all" ] || return 1
  printf '%s' "$s" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$' || return 1
  case "$s" in *"
"*) return 1 ;; esac
  return 0
}

# tcc_valid_service s
# Pure. Returns 0 for ^[A-Za-z][A-Za-z0-9]*$.
tcc_valid_service() {
  local s="${1-}"
  [ -n "$s" ] || return 1
  case "$s" in *"
"*) return 1 ;; esac
  printf '%s' "$s" | LC_ALL=C grep -Eq '^[A-Za-z][A-Za-z0-9]*$'
}

# tcc_db_service name
# Pure. Prints the value stored in access.service: kTCCService<name>, unless
# name already starts with kTCCService. Used only at the SQL boundary.
tcc_db_service() {
  local n="${1-}"
  case "$n" in
    kTCCService*) printf '%s' "$n" ;;
    *) printf 'kTCCService%s' "$n" ;;
  esac
}

# tcc_ident s
# Pure. Prints a column name double-quoted when it matches
# ^[A-Za-z_][A-Za-z0-9_]*$. Otherwise returns 1 and prints nothing.
tcc_ident() {
  local s="${1-}"
  [ -n "$s" ] || return 1
  case "$s" in *"
"*) return 1 ;; esac
  printf '%s' "$s" | LC_ALL=C grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' || return 1
  printf '"%s"' "$s"
}

# cell_literal cell
# Pure. Turns a tagged snapshot cell into a SQL literal made only of digits,
# hex, or NULL: i:<n> -> n, t:<hex> -> CAST(X'hex' AS TEXT), b:<hex> -> X'hex',
# n: -> NULL. Any other cell (including r:) is refused with return 1.
cell_literal() {
  local cell="${1-}" tag body
  case "$cell" in *"
"*) return 1 ;; esac
  tag="${cell%%:*}"
  [ "$tag" != "$cell" ] || return 1
  body="${cell#*:}"
  case "$tag" in
    i)
      printf '%s' "$body" | LC_ALL=C grep -Eq '^-?[0-9]{1,19}$' || return 1
      # Refuse values outside int64: -2^63 .. 2^63-1.
      local digits="${body#-}" limit="9223372036854775807"
      [ "$digits" != "$body" ] && limit="9223372036854775808"
      while [ "${#digits}" -gt 1 ] && [ "${digits#0}" != "$digits" ]; do
        digits="${digits#0}"
      done
      if [ "${#digits}" -eq 19 ] && [[ "$digits" > "$limit" ]]; then
        return 1
      fi
      printf '%s' "$body"
      ;;
    t | b)
      if [ -n "$body" ]; then
        printf '%s' "$body" | LC_ALL=C grep -Eq '^([0-9A-Fa-f]{2})+$' || return 1
      fi
      if [ "$tag" = "t" ]; then
        printf "CAST(X'%s' AS TEXT)" "$body"
      else
        printf "X'%s'" "$body"
      fi
      ;;
    n)
      [ -z "$body" ] || return 1
      printf 'NULL'
      ;;
    *) return 1 ;;
  esac
}

# tcc_guard bundle service... -- known_bundle...
# Refuses (prints the rejected value, returns 1) before any sqlite3 call when
# the bundle is not a known, valid, non-"All" id, or when any service is empty,
# malformed, or (when TCC_DECLARED_SERVICES is set, newline separated) not
# declared by the selected profile.
tcc_guard() {
  local bundle="${1-}" svc
  local -a services=()
  [ "$#" -gt 0 ] && shift
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    services+=("$1")
    shift
  done
  [ "$#" -gt 0 ] && shift
  guard_bundle_id "$bundle" "$@" || return 1
  if ! tcc_valid_bundle "$bundle"; then
    printf "refusing bundle id '%s'\n" "$bundle" >&2
    return 1
  fi
  for svc in ${services[@]+"${services[@]}"}; do
    if [ -z "$svc" ] || ! tcc_valid_service "$svc"; then
      printf "refusing service '%s'\n" "$svc" >&2
      return 1
    fi
    if [ -n "${TCC_DECLARED_SERVICES-}" ] \
      && ! printf '%s\n' "$TCC_DECLARED_SERVICES" | grep -Fxq -- "$svc"; then
      printf "refusing service '%s': not declared by the profile\n" "$svc" >&2
      return 1
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# Snapshot and backup (read-only access to the database, plus a byte copy).
# ---------------------------------------------------------------------------

_TCC_FDA_HINT="grant Full Disk Access to the Capture_Host in System Settings > Privacy & Security > Full Disk Access"

# _tcc_state_dir: runtime state directory (captures/.state).
_tcc_state_dir() {
  printf '%s\n' "${CAPTURE_STATE_DIR:-${CAPTURE_REPO_ROOT:-$(cd "$_TCCDB_DIR/../../.." && pwd)}/captures/.state}"
}

# _tcc_known_bundles: bundle IDs of the loaded profiles, one per line.
# TCC_KNOWN_BUNDLES (newline separated) wins when set; otherwise the profiles
# loaded by reset.sh are used.
_tcc_known_bundles() {
  if [ -n "${TCC_KNOWN_BUNDLES-}" ]; then
    printf '%s\n' "$TCC_KNOWN_BUNDLES"
  elif declare -F _reset_known_ids >/dev/null 2>&1; then
    _reset_known_ids
  fi
}

# _tcc_json_str s
# Prints s as a JSON string. Escapes backslash and double quote only; callers
# pass validated ids, hex cells, and file paths.
_tcc_json_str() {
  local s="${1-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$s"
}

# _tcc_json_list item...
# Prints the items as comma-separated JSON strings.
_tcc_json_list() {
  local item sep=""
  for item in "$@"; do
    printf '%s%s' "$sep" "$(_tcc_json_str "$item")"
    sep=","
  done
}

# _tcc_hex s
# Prints the upper-case hex of the bytes of s (the form SQLite's hex() uses).
_tcc_hex() {
  printf '%s' "${1-}" | od -An -v -tx1 | tr -d ' \n' | tr 'a-f' 'A-F'
}

# _tcc_sql_run flag... -- script
# Runs script (after ".bail on") on sqlite3's stdin against the checked
# database. Prints stdout. On failure prints stderr and returns 1.
_tcc_sql_run() {
  local flags=() db script errf out rc
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    flags+=("$1")
    shift
  done
  [ "$#" -gt 0 ] && shift
  script="${1-}"
  db="$(tcc_db_path)" || return 1
  errf="$(mktemp "${TMPDIR:-/tmp}/tccdb-err.XXXXXX")" || return 1
  out="$(printf '.bail on\n%s\n' "$script" | sqlite3 ${flags[@]+"${flags[@]}"} "$db" 2>"$errf")"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    cat "$errf" >&2
    rm -f "$errf"
    return 1
  fi
  rm -f "$errf"
  [ -z "$out" ] || printf '%s\n' "$out"
  return 0
}

# tcc_columns
# Prints the column names of the access table, one per line, read-only. Each
# name must pass tcc_ident. Fails when `service` or `client` is absent.
tcc_columns() {
  local out name has_service=0 has_client=0 n=0
  out="$(_tcc_sql_run -readonly -- "SELECT name FROM pragma_table_info('access') ORDER BY cid;")" || return 1
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if ! tcc_ident "$name" >/dev/null; then
      printf "refusing column name '%s'\n" "$name" >&2
      return 1
    fi
    [ "$name" = "service" ] && has_service=1
    [ "$name" = "client" ] && has_client=1
    n=$((n + 1))
  done <<EOF
$out
EOF
  if [ "$n" -eq 0 ] || [ "$has_service" -ne 1 ] || [ "$has_client" -ne 1 ]; then
    printf 'access table lacks the service or client column\n' >&2
    return 1
  fi
  printf '%s\n' "$out"
}

# _tcc_scope_where bundle services...
# Prints the WHERE clause of the Snapshot_Scope.
_tcc_scope_where() {
  local bundle="${1-}" svc list="" sep=""
  [ "$#" -gt 0 ] && shift
  for svc in "$@"; do
    list="$list$sep$(sql_quote "$(tcc_db_service "$svc")")"
    sep=", "
  done
  printf 'WHERE client = %s AND service IN (%s)' "$(sql_quote "$bundle")" "$list"
}

# tcc_scope_query bundle services...
# Prints the SQL that selects every column of the Snapshot_Scope rows as one
# line per row of tab-separated tagged cells (i:, t:, b:, n:, r:), ordered by
# service, rowid. The column list comes from TCC_COLUMNS (newline separated)
# when set, else from tcc_columns.
tcc_scope_query() {
  local bundle="${1-}" cols col expr="" sep="" ident
  [ "$#" -gt 0 ] && shift
  cols="${TCC_COLUMNS-}"
  if [ -z "$cols" ]; then
    cols="$(tcc_columns)" || return 1
  fi
  while IFS= read -r col; do
    [ -n "$col" ] || continue
    ident="$(tcc_ident "$col")" || { printf "refusing column name '%s'\n" "$col" >&2; return 1; }
    expr="$expr$sep""CASE typeof($ident) WHEN 'integer' THEN 'i:'||$ident WHEN 'text' THEN 't:'||hex(CAST($ident AS BLOB)) WHEN 'blob' THEN 'b:'||hex($ident) WHEN 'null' THEN 'n:' ELSE 'r:' END"
    sep="||char(9)||"
  done <<EOF
$cols
EOF
  [ -n "$expr" ] || return 1
  printf 'SELECT %s FROM access %s ORDER BY service, rowid;\n' "$expr" "$(_tcc_scope_where "$bundle" "$@")"
}

# _tcc_check_scope bundle services...
# Syntax check only, so a value never reaches sql_quote unvalidated.
_tcc_check_scope() {
  local bundle="${1-}" svc
  [ "$#" -gt 0 ] && shift
  if ! tcc_valid_bundle "$bundle"; then
    printf "refusing bundle id '%s'\n" "$bundle" >&2
    return 1
  fi
  for svc in "$@"; do
    if ! tcc_valid_service "$svc"; then
      printf "refusing service '%s'\n" "$svc" >&2
      return 1
    fi
  done
}

# tcc_rows bundle services...
# Opens the database read-only and prints one line per scope row, cells
# separated by tabs. Fails closed when any cell is a real number (r:).
tcc_rows() {
  local bundle="${1-}" q out tab
  tab="$(printf '\t')"
  _tcc_check_scope "$@" || return 1
  q="$(tcc_scope_query "$@")" || return 1
  out="$(_tcc_sql_run -readonly -- "$q")" || return 1
  if printf '%s\n' "$out" | grep -Eq "(^|$tab)r:"; then
    printf 'refusing to snapshot a real-number cell for %s\n' "$bundle" >&2
    return 1
  fi
  [ -z "$out" ] || printf '%s\n' "$out"
  return 0
}

# _tcc_scope_count bundle services...
# Prints the number of scope rows, counted by a separate read-only query.
_tcc_scope_count() {
  _tcc_sql_run -readonly -- "SELECT count(*) FROM access $(_tcc_scope_where "$@");"
}

# tcc_snapshot bundle services...
# Guards (known bundles from TCC_KNOWN_BUNDLES or the loaded profiles, services
# from TCC_DECLARED_SERVICES when set), then writes
# <state>/tcc-snapshot-<bundle>.json atomically and re-reads it to compare the
# row count with the query's. The run id comes from TCC_RUN_TS (default: now,
# UTC). On any failure removes the temporary file and returns 1.
tcc_snapshot() {
  local bundle="${1-}" state out file tmp cols rows expected got run svc line k
  local known=() svcs=()
  [ "$#" -gt 0 ] && shift
  svcs=("$@")
  while IFS= read -r k; do
    [ -n "$k" ] && known+=("$k")
  done <<EOF
$(_tcc_known_bundles)
EOF
  tcc_guard "$bundle" ${svcs[@]+"${svcs[@]}"} -- ${known[@]+"${known[@]}"} || return 1

  if ! out="$(tcc_probe 2>&1)"; then
    printf 'cannot read the TCC database: %s\n%s\n' "$out" "$_TCC_FDA_HINT" >&2
    return 1
  fi
  state="$(_tcc_state_dir)"
  mkdir -p "$state" || { printf 'cannot create %s\n' "$state" >&2; return 1; }
  file="$state/tcc-snapshot-$bundle.json"
  tmp="$state/.tcc-snapshot-$bundle.json.tmp.$$"
  run="${TCC_RUN_TS:-$(date -u +%Y%m%dT%H%M%SZ)}"

  cols="$(tcc_columns)" || { printf '%s\n' "$_TCC_FDA_HINT" >&2; return 1; }
  rows="$(TCC_COLUMNS="$cols" tcc_rows "$bundle" ${svcs[@]+"${svcs[@]}"})" || return 1
  expected="$(_tcc_scope_count "$bundle" ${svcs[@]+"${svcs[@]}"})" || return 1

  # Services without a row: compare the hex of each declared service with the
  # service cell of every row.
  local sidx=0 i=0 col have="" missing=() first=1
  local -a cells
  while IFS= read -r col; do
    [ "$col" = "service" ] && sidx=$i
    i=$((i + 1))
  done <<EOF
$cols
EOF
  if [ -n "$rows" ]; then
    while IFS= read -r line; do
      IFS=$'\t' read -r -a cells <<EOF
$line
EOF
      have="$have
${cells[$sidx]}"
    done <<EOF
$rows
EOF
  fi
  for svc in ${svcs[@]+"${svcs[@]}"}; do
    printf '%s\n' "$have" | grep -Fxq -- "t:$(_tcc_hex "$(tcc_db_service "$svc")")" || missing+=("$svc")
  done

  {
    printf '{\n  "format": 1,\n'
    printf '  "bundle_id": %s,\n' "$(_tcc_json_str "$bundle")"
    printf '  "taken_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "run": %s,\n' "$(_tcc_json_str "$run")"
    if [ -n "${CAPTURE_TCC_DB_TEST-}" ]; then
      printf '  "database": "test",\n'
    else
      printf '  "database": "user",\n'
    fi
    printf '  "backup": %s,\n' "$(_tcc_json_str "$state/TCC.db.backup-$run")"
    printf '  "services": ['
    _tcc_json_list ${svcs[@]+"${svcs[@]}"}
    printf '],\n  "services_without_row": ['
    _tcc_json_list ${missing[@]+"${missing[@]}"}
    printf '],\n  "columns": ['
    local carr=()
    while IFS= read -r col; do
      carr+=("$col")
    done <<EOF
$cols
EOF
    _tcc_json_list "${carr[@]}"
    printf '],\n'
    if [ -z "$rows" ]; then
      printf '  "rows": []\n'
    else
      printf '  "rows": [\n'
      while IFS= read -r line; do
        [ "$first" -eq 1 ] || printf ',\n'
        first=0
        printf '    ['
        IFS=$'\t' read -r -a cells <<EOF
$line
EOF
        _tcc_json_list "${cells[@]}"
        printf ']'
      done <<EOF
$rows
EOF
      printf '\n  ]\n'
    fi
    printf '}\n'
  } >"$tmp" 2>/dev/null || { rm -f "$tmp"; printf 'cannot write snapshot file %s\n' "$file" >&2; return 1; }

  got="$(grep -c '^    \["' "$tmp" 2>/dev/null)" || got=0
  if [ "$got" != "$expected" ] || ! tail -n 1 "$tmp" | grep -Fxq '}'; then
    rm -f "$tmp"
    printf 'snapshot verification failed: file has %s rows, query returned %s\n' "$got" "$expected" >&2
    return 1
  fi
  if ! mv -f "$tmp" "$file"; then
    rm -f "$tmp"
    printf 'cannot write snapshot file %s\n' "$file" >&2
    return 1
  fi
  return 0
}

# tcc_backup_file_path [run_ts]
# Prints the backup path for a run: <state>/TCC.db.backup-<run_ts>, with a
# placeholder when run_ts is empty.
tcc_backup_file_path() {
  printf '%s/TCC.db.backup-%s\n' "$(_tcc_state_dir)" "${1:-<run timestamp>}"
}

# tcc_newest_backup
# Prints the newest backup file (not -wal or -shm) in the state directory, or
# nothing when there is none.
tcc_newest_backup() {
  ls -t "$(_tcc_state_dir)"/TCC.db.backup-* 2>/dev/null | grep -v -e '-wal$' -e '-shm$' | head -n 1
}

# tcc_backup run_ts
# Byte copy of the database to <state>/TCC.db.backup-<run_ts> (with -wal and
# -shm when present). Returns 0 and does nothing when that file exists. Checks
# that the copy has the source's size and that sqlite3 can read its access
# table; on failure removes the copy and returns 1. Never touches other files.
tcc_backup() {
  local run="${1-}" db state dest ext src ssize dsize
  if [ -z "$run" ] || ! printf '%s' "$run" | LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
    printf "refusing run id '%s'\n" "$run" >&2
    return 1
  fi
  state="$(_tcc_state_dir)"
  dest="$state/TCC.db.backup-$run"
  if [ -e "$dest" ]; then
    return 0
  fi
  db="$(tcc_db_path)" || return 1
  if [ ! -r "$db" ]; then
    printf 'cannot read the TCC database: %s\n%s\n' "$db" "$_TCC_FDA_HINT" >&2
    return 1
  fi
  mkdir -p "$state" || return 1
  if ! cp -p "$db" "$dest" 2>/dev/null; then
    rm -f "$dest"
    printf 'cannot back up the TCC database\n%s\n' "$_TCC_FDA_HINT" >&2
    return 1
  fi
  for ext in -wal -shm; do
    src="$db$ext"
    [ -e "$src" ] || continue
    if ! cp -p "$src" "$dest$ext" 2>/dev/null; then
      rm -f "$dest" "$dest-wal" "$dest-shm"
      printf 'cannot back up %s\n' "$src" >&2
      return 1
    fi
  done
  ssize="$(stat -f %z "$db" 2>/dev/null)" || ssize=""
  dsize="$(stat -f %z "$dest" 2>/dev/null)" || dsize=""
  if [ -z "$ssize" ] || [ "$ssize" != "$dsize" ] \
    || ! sqlite3 -readonly "$dest" 'SELECT count(*) FROM access' >/dev/null 2>&1; then
    rm -f "$dest" "$dest-wal" "$dest-shm"
    printf 'backup verification failed for %s\n' "$dest" >&2
    return 1
  fi
  return 0
}

# tcc_notice bundle [run_ts]
# Prints the notice that the framework reads and may write the user's TCC
# database for the named bundle ID only, and the backup path.
tcc_notice() {
  local bundle="${1-}" run="${2-${TCC_RUN_TS-}}"
  printf "notice: this run reads and may write the TCC database for bundle id '%s' only\n" "$bundle"
  printf 'notice: backup of the whole database: %s/TCC.db.backup-%s\n' "$(_tcc_state_dir)" "${run:-<run timestamp>}"
}

# ---------------------------------------------------------------------------
# Restore, verify, daemon restart, and pending lookup.
# ---------------------------------------------------------------------------

# _tcc_snapshot_file bundle
# Prints the path of the pending snapshot file for bundle.
_tcc_snapshot_file() {
  printf '%s/tcc-snapshot-%s.json\n' "$(_tcc_state_dir)" "${1-}"
}

# _tcc_read_snapshot file
# Parses the snapshot JSON with JXA (any whitespace layout) and prints tagged
# lines: "bundle<TAB>id", "service<TAB>s", "column<TAB>c", "row<TAB>cell...".
# Tab, newline, and carriage return inside a string become \001 so the value
# fails every later grammar check. Prints "error<TAB>reason" and returns 1 when
# the file is not a format-1 snapshot.
_tcc_read_snapshot() {
  local file="${1-}" rc
  if [ ! -f "$file" ]; then
    printf 'error\tsnapshot file not found: %s\n' "$file"
    return 1
  fi
  osascript -l JavaScript -e '
ObjC.import("Foundation");
function clean(s) { return String(s).replace(/[\t\n\r]/g, "\u0001"); }
function run(argv) {
  var err = $();
  var s = $.NSString.stringWithContentsOfFileEncodingError($(argv[0]), $.NSUTF8StringEncoding, err);
  if (s.isNil()) { return "error\tcannot read file"; }
  var d;
  try { d = JSON.parse(ObjC.unwrap(s)); } catch (e) { return "error\tinvalid JSON"; }
  if (d === null || typeof d !== "object" || d.format !== 1 || typeof d.bundle_id !== "string"
      || !Array.isArray(d.services) || !Array.isArray(d.columns) || !Array.isArray(d.rows)) {
    return "error\tnot a format 1 snapshot";
  }
  var out = ["bundle\t" + clean(d.bundle_id)];
  var i, j;
  for (i = 0; i < d.services.length; i++) {
    if (typeof d.services[i] !== "string") { return "error\tbad services"; }
    out.push("service\t" + clean(d.services[i]));
  }
  for (i = 0; i < d.columns.length; i++) {
    if (typeof d.columns[i] !== "string") { return "error\tbad columns"; }
    out.push("column\t" + clean(d.columns[i]));
  }
  for (i = 0; i < d.rows.length; i++) {
    if (!Array.isArray(d.rows[i])) { return "error\tbad row"; }
    var cells = [];
    for (j = 0; j < d.rows[i].length; j++) {
      if (typeof d.rows[i][j] !== "string") { return "error\tbad cell"; }
      cells.push(clean(d.rows[i][j]));
    }
    out.push("row\t" + cells.join("\t"));
  }
  return out.join("\n");
}' "$file" 2>/dev/null
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf 'error\tcannot parse snapshot\n'
    return 1
  fi
}

# _tcc_split line
# Splits line on tabs into the global array _TCC_CELLS (empty fields kept).
_tcc_split() {
  local rest="${1-}"
  _TCC_CELLS=()
  while :; do
    case "$rest" in
      *$'\t'*)
        _TCC_CELLS+=("${rest%%$'\t'*}")
        rest="${rest#*$'\t'}"
        ;;
      *)
        _TCC_CELLS+=("$rest")
        break
        ;;
    esac
  done
}

# _tcc_load_snapshot bundle
# Loads the pending snapshot for bundle into globals: _TS_SERVICES, _TS_COLUMNS
# (arrays) and _TS_ROWS (newline separated rows of tab-separated cells).
# Returns 1 with a message when the file is missing or malformed.
_tcc_load_snapshot() {
  local bundle="${1-}" file parsed line kind val seen_bundle=""
  file="$(_tcc_snapshot_file "$bundle")"
  _TS_SERVICES=()
  _TS_COLUMNS=()
  _TS_ROWS=""
  if [ ! -f "$file" ]; then
    printf 'no pending snapshot for bundle id %s\n' "$bundle" >&2
    return 1
  fi
  if ! parsed="$(_tcc_read_snapshot "$file")"; then
    printf 'cannot read snapshot %s: %s\n' "$file" "${parsed#error$'\t'}" >&2
    return 1
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    kind="${line%%$'\t'*}"
    val="${line#*$'\t'}"
    case "$kind" in
      bundle) seen_bundle="$val" ;;
      service) _TS_SERVICES+=("$val") ;;
      column) _TS_COLUMNS+=("$val") ;;
      row) _TS_ROWS="${_TS_ROWS}${val}"$'\n' ;;
      *) printf 'cannot read snapshot %s\n' "$file" >&2; return 1 ;;
    esac
  done <<EOF
$parsed
EOF
  if [ "$seen_bundle" != "$bundle" ]; then
    printf "snapshot %s belongs to bundle id '%s', not '%s'\n" "$file" "$seen_bundle" "$bundle" >&2
    return 1
  fi
  _TS_ROWS="${_TS_ROWS%$'\n'}"
  return 0
}

# _tcc_known_array
# Fills the global array _TS_KNOWN with the known bundle IDs.
_tcc_known_array() {
  local k
  _TS_KNOWN=()
  while IFS= read -r k; do
    [ -n "$k" ] && _TS_KNOWN+=("$k")
  done <<EOF
$(_tcc_known_bundles)
EOF
  return 0
}

# _tcc_restore_script bundle
# Builds the restore SQL from the loaded snapshot (_TS_* globals) on stdout.
# Every cell goes through cell_literal and every column through tcc_ident
# before anything is printed. Rows outside the snapshot scope are refused.
_tcc_restore_script() {
  local bundle="${1-}" svc col cols="" sep="" in_list="" lit vals line cell ident
  local i=0 bhex shex ok n_cols svc_col=-1 client_col=-1 body="" up
  local -a svc_hex=()
  n_cols="${#_TS_COLUMNS[@]}"
  for col in ${_TS_COLUMNS[@]+"${_TS_COLUMNS[@]}"}; do
    ident="$(tcc_ident "$col")" || { printf "refusing column name '%s'\n" "$col" >&2; return 1; }
    cols="$cols$sep$ident"
    sep=","
    [ "$col" = "service" ] && svc_col=$i
    [ "$col" = "client" ] && client_col=$i
    i=$((i + 1))
  done
  if [ "$svc_col" -lt 0 ] || [ "$client_col" -lt 0 ]; then
    printf 'snapshot lacks the service or client column\n' >&2
    return 1
  fi
  sep=""
  for svc in ${_TS_SERVICES[@]+"${_TS_SERVICES[@]}"}; do
    tcc_valid_service "$svc" || { printf "refusing service '%s'\n" "$svc" >&2; return 1; }
    in_list="$in_list$sep$(sql_quote "$(tcc_db_service "$svc")")"
    sep=", "
    svc_hex+=("t:$(_tcc_hex "$(tcc_db_service "$svc")")")
  done
  bhex="t:$(_tcc_hex "$bundle")"

  if [ -n "$_TS_ROWS" ]; then
    while IFS= read -r line; do
      _tcc_split "$line"
      if [ "${#_TCC_CELLS[@]}" -ne "$n_cols" ]; then
        printf 'refusing snapshot row with %s cells, expected %s\n' "${#_TCC_CELLS[@]}" "$n_cols" >&2
        return 1
      fi
      vals=""
      sep=""
      for cell in "${_TCC_CELLS[@]}"; do
        lit="$(cell_literal "$cell")" || { printf "refusing snapshot cell '%s'\n" "$cell" >&2; return 1; }
        vals="$vals$sep$lit"
        sep=","
      done
      # Scope check: client and service must be the snapshot's own.
      up="$(printf '%s' "${_TCC_CELLS[$client_col]}" | tr 'a-f' 'A-F')"
      if [ "$up" != "$(printf '%s' "$bhex" | tr 'a-f' 'A-F')" ]; then
        printf 'refusing snapshot row outside the scope (client)\n' >&2
        return 1
      fi
      up="$(printf '%s' "${_TCC_CELLS[$svc_col]}" | tr 'a-f' 'A-F')"
      ok=0
      for shex in ${svc_hex[@]+"${svc_hex[@]}"}; do
        [ "$up" = "$(printf '%s' "$shex" | tr 'a-f' 'A-F')" ] && ok=1
      done
      if [ "$ok" -ne 1 ]; then
        printf 'refusing snapshot row outside the scope (service)\n' >&2
        return 1
      fi
      # Plain INSERT: OR REPLACE would turn a NULL in a NOT NULL column into the
      # column default and write a row that differs from the snapshot.
      body="$body"$'\n'"INSERT INTO access ($cols) VALUES ($vals);"
    done <<EOF
$_TS_ROWS
EOF
  fi
  printf 'BEGIN IMMEDIATE;\nDELETE FROM access WHERE client = %s AND service IN (%s);%s\nCOMMIT;\n' \
    "$(sql_quote "$bundle")" "$in_list" "$body"
}

# tcc_restore bundle
# Reads the pending snapshot, guards bundle and services, builds the whole
# script (refusing any cell outside the cell grammar before sqlite3 runs), runs
# it in one transaction, then calls tcc_verify. Does not rename the snapshot or
# restart tccd. Returns 1 on any refusal, write failure, or verify difference.
tcc_restore() {
  local bundle="${1-}" script db
  _tcc_known_array
  tcc_guard "$bundle" -- ${_TS_KNOWN[@]+"${_TS_KNOWN[@]}"} || return 1
  _tcc_load_snapshot "$bundle" || return 1
  tcc_guard "$bundle" ${_TS_SERVICES[@]+"${_TS_SERVICES[@]}"} -- ${_TS_KNOWN[@]+"${_TS_KNOWN[@]}"} || return 1
  script="$(_tcc_restore_script "$bundle")" || return 1
  db="$(tcc_db_path)" || return 1
  if [ ! -f "$db" ]; then
    printf 'database not found: %s\n' "$db" >&2
    return 1
  fi
  _tcc_sql_run -- "$script" >/dev/null || return 1
  tcc_verify "$bundle"
}

# tcc_verify bundle
# Re-reads the scope rows read-only and compares them, sorted, with the
# snapshot rows. Prints the service of each differing or extra row, one per
# line. Returns 0 only when both sides are equal in every column.
tcc_verify() {
  local bundle="${1-}" actual expected diff line cols name shown="" hexs
  local i=0 col sidx=-1
  _tcc_known_array
  tcc_guard "$bundle" -- ${_TS_KNOWN[@]+"${_TS_KNOWN[@]}"} || return 1
  _tcc_load_snapshot "$bundle" || return 1
  for col in ${_TS_COLUMNS[@]+"${_TS_COLUMNS[@]}"}; do
    [ "$col" = "service" ] && sidx=$i
    i=$((i + 1))
  done
  [ "$sidx" -ge 0 ] || { printf 'snapshot lacks the service column\n' >&2; return 1; }
  cols="$(printf '%s\n' ${_TS_COLUMNS[@]+"${_TS_COLUMNS[@]}"})"
  actual="$(TCC_COLUMNS="$cols" tcc_rows "$bundle" ${_TS_SERVICES[@]+"${_TS_SERVICES[@]}"})" || return 1
  expected="$_TS_ROWS"
  actual="$(printf '%s\n' "$actual" | LC_ALL=C sort)"
  expected="$(printf '%s\n' "$expected" | LC_ALL=C sort)"
  [ "$actual" != "$expected" ] || return 0
  diff="$(LC_ALL=C comm -3 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual"))"
  while IFS= read -r line; do
    line="${line#$'\t'}"
    line="${line#$'\t'}"
    [ -n "$line" ] || continue
    _tcc_split "$line"
    hexs="${_TCC_CELLS[$sidx]-}"
    hexs="${hexs#t:}"
    name="$(printf '%s' "$hexs" | xxd -r -p 2>/dev/null)" || name=""
    [ -n "$name" ] || name="$hexs"
    case "
$shown
" in
      *"
$name
"*) ;;
      *) shown="$shown
$name"; printf '%s\n' "$name" ;;
    esac
  done <<EOF
$diff
EOF
  return 1
}

# tcc_restart_daemon
# Restarts the user's tccd so it reloads the database. Prints the result and
# never fails. Skipped when the database path came from CAPTURE_TCC_DB_TEST.
tcc_restart_daemon() {
  if [ -n "${CAPTURE_TCC_DB_TEST-}" ]; then
    printf 'tccd restart: skipped (test database)\n'
    return 0
  fi
  if pkill -x -u "$(id -u)" tccd >/dev/null 2>&1; then
    printf 'tccd restart: done\n'
  else
    printf 'tccd restart: failed\n'
  fi
  return 0
}

# tcc_mark_restored bundle
# Renames the pending snapshot to tcc-snapshot-<bundle>.restored.json.
tcc_mark_restored() {
  local bundle="${1-}" state
  tcc_valid_bundle "$bundle" || { printf "refusing bundle id '%s'\n" "$bundle" >&2; return 1; }
  state="$(_tcc_state_dir)"
  mv -f "$state/tcc-snapshot-$bundle.json" "$state/tcc-snapshot-$bundle.restored.json"
}

# tcc_pending
# Prints the bundle ID of each pending snapshot, one per line. Reads only the
# state directory and never opens the database.
tcc_pending() {
  local state f name
  state="$(_tcc_state_dir)"
  [ -d "$state" ] || return 0
  for f in "$state"/tcc-snapshot-*.json; do
    [ -f "$f" ] || continue
    name="${f##*/}"
    case "$name" in *.restored.json) continue ;; esac
    name="${name#tcc-snapshot-}"
    printf '%s\n' "${name%.json}"
  done
  return 0
}
