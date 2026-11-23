#!/usr/bin/env bash
# Session planning and failure policy for the capture framework.
# Pure: no file access, no external commands except sort/tr, no side effects
# beyond writing to stdout/stderr. bash 3.2 compatible. Meant to be sourced.
#
# Row format (used by all three functions), tab separated:
#   pair<TAB>profile<TAB>scenario<TAB>mode
# where pair is "<profile>:<scenario>" and mode is baseline or ward.
# A baseline row and the ward row that follows it share one pair id.
# An executed row, as passed to plan_continue, has a fifth field:
#   pair<TAB>profile<TAB>scenario<TAB>mode<TAB>outcome     (outcome: ok|error)

# plan_sessions mode all_scenarios scenario < catalog
#
# Arguments:
#   mode           "" (both modes, baseline then ward), "baseline", or "ward".
#   all_scenarios  "1" to plan every scenario of each profile in declared
#                  order; anything else plans only the one named scenario.
#   scenario       Scenario name. Ignored when all_scenarios is "1".
# Stdin (the catalog): one line per loaded profile,
#   profile_id<TAB>scenario,scenario,...
# scenarios comma separated in declared order. Input line order does not
# matter; profiles are emitted in byte order of profile_id (LC_ALL=C).
# Pass one catalog line for a single profile, all lines for --all-profiles.
#
# Stdout: rows (see header), profiles in name order, scenarios in declared
# order, and within a pair baseline before ward (or just the given mode).
# Stderr: when all_scenarios is not "1", each profile lacking the scenario
# produces "skipping <id>: no scenario <name>" and no rows.
# Returns 0.
plan_sessions() {
  local mode="$1" all="$2" want="$3"
  local id scen rest s found modes m list
  case "$mode" in
    '') modes="baseline ward" ;;
    *) modes="$mode" ;;
  esac
  LC_ALL=C sort -t "$(printf '\t')" -k1,1 | while IFS="$(printf '\t')" read -r id scen rest; do
    [ -n "$id" ] || continue
    found=0
    list="$(printf '%s' "$scen" | tr ',' '\n')"
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      if [ "$all" != "1" ] && [ "$s" != "$want" ]; then
        continue
      fi
      found=1
      for m in $modes; do
        printf '%s:%s\t%s\t%s\t%s\n' "$id" "$s" "$id" "$s" "$m"
      done
    done <<EOF
$list
EOF
    if [ "$found" -eq 0 ] && [ "$all" != "1" ]; then
      printf 'skipping %s: no scenario %s\n' "$id" "$want" >&2
    fi
  done
}

# plan_continue rows_so_far next_row keep_going
#
# Arguments:
#   rows_so_far  Executed rows so far, one per line, each with the fifth
#                outcome field (ok or error). May be empty. Rows that were
#                skipped are not listed.
#   next_row     The row about to start (four fields, or five; the fifth is
#                ignored).
#   keep_going   "1" for --keep-going, anything else for stop-on-failure.
# Returns 0 when next_row may start, 1 when it must be skipped.
# Policy: without keep_going, start only if no earlier outcome is not ok.
# With keep_going, start unless next_row is a ward row and the baseline row
# of the same pair (same first field) ended with an outcome other than ok.
plan_continue() {
  local rows="$1" next="$2" keep="$3"
  local tab pair mode p _a _b m o
  tab="$(printf '\t')"
  pair="${next%%"$tab"*}"
  mode="$(printf '%s\n' "$next" | cut -f4)"
  while IFS="$tab" read -r p _a _b m o; do
    [ -n "$p" ] || continue
    if [ "$keep" != "1" ]; then
      [ "$o" = "ok" ] || return 1
    elif [ "$mode" = "ward" ] && [ "$p" = "$pair" ] && [ "$m" = "baseline" ] && [ "$o" != "ok" ]; then
      return 1
    fi
  done <<EOF
$rows
EOF
  return 0
}

# plan_exit_code outcome...
#
# Arguments: the outcomes of every executed row, as separate arguments or as
# one whitespace-separated string (each word is one outcome). Skipped rows
# are not passed.
# An optional last argument is the run's restore status: verified, none or
# skipped keep the result; failed makes it 1.
# Prints nothing. Returns 0 when every outcome is "ok" (including when there
# are none) and the restore did not fail, otherwise 1.
plan_exit_code() {
  local arg o last=""
  for last in "$@"; do :; done
  case "$last" in
    verified | none | skipped) set -- "${@:1:$(($# - 1))}" ;;
    failed) return 1 ;;
  esac
  for arg in "$@"; do
    for o in $arg; do
      [ "$o" = "ok" ] || return 1
    done
  done
  return 0
}
