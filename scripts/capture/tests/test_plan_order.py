"""Property 19: Session planning order.

**Validates: Requirements 9.7, 12.3, 12.4**

plan_sessions emits profiles in byte order of profile_id, scenarios in
declared order, and within a pair baseline before ward (or only the given
mode). With a single scenario name, profiles lacking it are named on stderr
and produce no rows.
"""
from __future__ import annotations

from hypothesis import given
from hypothesis import strategies as st

from conftest import profile_ids, run_bash, scenario_names

SNIPPET = 'plan_sessions "$1" "$2" "$3"'

catalogs = st.dictionaries(
    profile_ids,
    st.lists(scenario_names, min_size=1, max_size=6, unique=True),
    min_size=0,
    max_size=6,
)


def _stdin(catalog: dict[str, list[str]], order: list[str]) -> str:
    return "".join(f"{pid}\t{','.join(catalog[pid])}\n" for pid in order)


def _plan(repo, catalog, order, mode, all_scen, want):
    res = run_bash(
        repo,
        SNIPPET,
        mode,
        "1" if all_scen else "0",
        want,
        libs=("common", "plan"),
        stdin=_stdin(catalog, order),
    )
    assert res.returncode == 0, res.stderr
    rows = [line.split("\t") for line in res.stdout.split("\n") if line]
    return rows, res.stderr


def _modes(mode: str) -> list[str]:
    return [mode] if mode else ["baseline", "ward"]


@given(
    catalog=catalogs,
    seed=st.randoms(use_true_random=False),
    mode=st.sampled_from(["", "baseline", "ward"]),
)
def test_all_scenarios_order(repo, catalog, seed, mode):
    order = list(catalog)
    seed.shuffle(order)
    rows, err = _plan(repo, catalog, order, mode, True, "")
    expected = [
        [f"{pid}:{s}", pid, s, m]
        for pid in sorted(catalog, key=lambda p: p.encode())
        for s in catalog[pid]
        for m in _modes(mode)
    ]
    assert rows == expected
    assert err == ""


@given(
    catalog=catalogs,
    seed=st.randoms(use_true_random=False),
    mode=st.sampled_from(["", "baseline", "ward"]),
    want=scenario_names,
    pick=st.booleans(),
)
def test_single_scenario_order_and_skips(repo, catalog, seed, mode, want, pick):
    # Half the time, make sure at least one profile has the wanted scenario.
    if pick and catalog:
        first = sorted(catalog)[0]
        if want not in catalog[first]:
            catalog[first] = catalog[first] + [want]
    order = list(catalog)
    seed.shuffle(order)
    rows, err = _plan(repo, catalog, order, mode, False, want)
    sorted_ids = sorted(catalog, key=lambda p: p.encode())
    expected = [
        [f"{pid}:{want}", pid, want, m]
        for pid in sorted_ids
        if want in catalog[pid]
        for m in _modes(mode)
    ]
    assert rows == expected
    expected_err = [
        f"skipping {pid}: no scenario {want}"
        for pid in sorted_ids
        if want not in catalog[pid]
    ]
    assert [line for line in err.split("\n") if line] == expected_err
