"""Property 20: Failure policy.

For any sequence of session outcomes and any --keep-going setting: without
--keep-going no row starts after a failed outcome. With --keep-going rows keep
starting, except the ward row of a pair whose baseline row failed. The exit
code is 0 iff every executed row ended ok, and every planned row not skipped by
these rules is executed.

**Validates: Requirements 9.8, 12.6**
"""
from __future__ import annotations

from hypothesis import given, strategies as st

from conftest import profile_ids, run_bash, scenario_names

TAB = "\t"

# A driver that mimics capture.sh: walk the planned rows, ask plan_continue
# before each, "execute" the row with its pre-drawn outcome, then ask
# plan_exit_code. Output: one "E<TAB>pair<TAB>mode<TAB>outcome" line per
# executed row, one "S<TAB>pair<TAB>mode" per skipped row, then "X<TAB>code".
DRIVER = r"""
keep="$1"
. "$CAPTURE_DIR/lib/plan.sh"
tab="$(printf '\t')"
executed=""
outcomes=""
while IFS= read -r row; do
  [ -n "$row" ] || continue
  pair="${row%%"$tab"*}"
  mode="$(printf '%s\n' "$row" | cut -f4)"
  want="$(printf '%s\n' "$row" | cut -f5)"
  four="$(printf '%s\n' "$row" | cut -f1-4)"
  if plan_continue "$executed" "$four" "$keep"; then
    printf 'E\t%s\t%s\t%s\n' "$pair" "$mode" "$want"
    if [ -n "$executed" ]; then executed="$executed
$four$tab$want"; else executed="$four$tab$want"; fi
    outcomes="$outcomes $want"
  else
    printf 'S\t%s\t%s\n' "$pair" "$mode"
  fi
done
plan_exit_code $outcomes
printf 'X\t%s\n' "$?"
"""

outcome_values = st.sampled_from(["ok", "ok", "ok", "error", "no_prompt", "no_hud"])


@st.composite
def plans(draw):
    """Planned rows (pair, profile, scenario, mode, outcome-if-run)."""
    pairs = draw(
        st.lists(st.tuples(profile_ids, scenario_names), min_size=0, max_size=6, unique=True)
    )
    modes = draw(st.sampled_from([("baseline", "ward"), ("baseline",), ("ward",)]))
    rows = []
    for prof, scen in pairs:
        for mode in modes:
            rows.append((f"{prof}:{scen}", prof, scen, mode, draw(outcome_values)))
    return rows


def model(rows, keep):
    """Reference policy: returns (list of (executed?, row), exit_code)."""
    result = []
    failed_before = False
    baseline_failed = set()
    exit_code = 0
    for row in rows:
        pair, _p, _s, mode, outcome = row
        if not keep:
            run = not failed_before
        else:
            run = not (mode == "ward" and pair in baseline_failed)
        result.append((run, row))
        if run:
            if outcome != "ok":
                failed_before = True
                exit_code = 1
                if mode == "baseline":
                    baseline_failed.add(pair)
    return result, exit_code


def drive(repo, rows, keep):
    stdin = "".join(TAB.join(r) + "\n" for r in rows)
    proc = run_bash(repo, DRIVER, "1" if keep else "0", libs=("common",), stdin=stdin)
    assert proc.returncode == 0, proc.stderr
    lines = [ln.split(TAB) for ln in proc.stdout.split("\n") if ln]
    return lines


@given(rows=plans(), keep=st.booleans())
def test_failure_policy(repo, rows, keep):
    lines = drive(repo, rows, keep)
    expected, exit_code = model(rows, keep)
    assert lines[-1] == ["X", str(exit_code)]
    got = lines[:-1]
    assert len(got) == len(rows)
    for line, (run, row) in zip(got, expected):
        pair, _p, _s, mode, outcome = row
        if run:
            assert line == ["E", pair, mode, outcome]
        else:
            assert line == ["S", pair, mode]
    # Exit code is 0 iff every executed row ended ok.
    executed_outcomes = [r[4] for run, r in expected if run]
    assert (exit_code == 0) == all(o == "ok" for o in executed_outcomes)


@given(rows=plans())
def test_stop_on_failure_nothing_after_first_failure(repo, rows):
    lines = drive(repo, rows, False)[:-1]
    seen_failure = False
    for line in lines:
        if line[0] == "E":
            assert not seen_failure
            seen_failure = seen_failure or line[3] != "ok"
        else:
            assert seen_failure


@given(rows=plans())
def test_keep_going_skips_only_ward_after_failed_baseline(repo, rows):
    lines = drive(repo, rows, True)[:-1]
    failed_baselines = set()
    for line in lines:
        if line[0] == "E" and line[2] == "baseline" and line[3] != "ok":
            failed_baselines.add(line[1])
        if line[0] == "S":
            assert line[2] == "ward" and line[1] in failed_baselines
        elif line[2] == "ward":
            assert line[1] not in failed_baselines


def test_exit_code_empty_and_mixed_forms(repo):
    snippet = (
        '. "$CAPTURE_DIR/lib/plan.sh"\n'
        'plan_exit_code; a=$?\n'
        'plan_exit_code ok ok; b=$?\n'
        'plan_exit_code "ok ok"; c=$?\n'
        'plan_exit_code ok "ok error"; d=$?\n'
        'printf "%s %s %s %s" "$a" "$b" "$c" "$d"\n'
    )
    proc = run_bash(repo, snippet, libs=("common",))
    assert proc.stdout == "0 0 0 1"
