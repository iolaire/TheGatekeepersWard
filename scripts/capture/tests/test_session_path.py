"""Property 8: Session path structure.

Feature: permission-capture-framework, Property 8: Session path structure

**Validates: Requirements 11.3, 9.10**
"""
from __future__ import annotations

import re

from hypothesis import given, settings
from hypothesis import strategies as st

from conftest import profile_ids, run_bash, scenario_names

timestamps = st.builds(
    lambda y, mo, d, h, mi, s: f"{y:04d}{mo:02d}{d:02d}T{h:02d}{mi:02d}{s:02d}Z",
    st.integers(2026, 2035),
    st.integers(1, 12),
    st.integers(1, 28),
    st.integers(0, 23),
    st.integers(0, 59),
    st.integers(0, 59),
)

SNIPPET = (
    'session_path "$1" "$2" "$3" "$4" baseline\n'
    'session_path "$1" "$2" "$3" "$4" ward\n'
    'run_timestamp\n'
)


@settings(deadline=None)
@given(ts=timestamps, profile=profile_ids, scenario=scenario_names)
def test_session_path_structure(repo, ts, profile, scenario):
    root = str(repo.root)
    res = run_bash(repo, SNIPPET, root, ts, profile, scenario, libs=("session",))
    assert res.returncode == 0, res.stderr
    base, ward, stamp = res.stdout.splitlines()

    assert base == f"{root}/captures/{ts}/{profile}/{scenario}/baseline"
    assert ward == f"{root}/captures/{ts}/{profile}/{scenario}/ward"

    bparts, wparts = base.split("/"), ward.split("/")
    assert bparts[:-1] == wparts[:-1]
    assert (bparts[-1], wparts[-1]) == ("baseline", "ward")
    assert bparts[-5:-1] == ["captures", ts, profile, scenario]

    assert re.fullmatch(r"\d{8}T\d{6}Z", stamp)
