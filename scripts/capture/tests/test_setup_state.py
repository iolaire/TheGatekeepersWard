"""Property 25: Setup state is never overwritten.

Feature: permission-capture-framework, Property 25: Setup state is never overwritten
**Validates: Requirements 1.3**
"""
from __future__ import annotations

import json

from hypothesis import given, settings
from hypothesis import strategies as st

from conftest import run_bash

PERMS = [
    "accessibility",
    "screen-recording",
    "automation-system-events",
    "automation-finder",
    "full-disk-access",
]

# A recorded state: any subset of the five permissions, each true or false.
states = st.dictionaries(st.sampled_from(PERMS), st.booleans(), max_size=5)
# Names to skip (the optional third argument): any subset of the five.
skips = st.lists(st.sampled_from(PERMS), unique=True, max_size=5)


def render(state: dict) -> str:
    """Render a state as flat JSON, one `"name": bool` per line (or empty)."""
    if not state:
        return ""
    lines = [f'  "{k}": {"true" if v else "false"}' for k, v in state.items()]
    return "{\n" + ",\n".join(lines) + "\n}\n"


SNIPPET = 'setup_state_merge "$1" "$2" "$3"\n'


def merge(repo, old_text: str, new: dict, skip: list[str]) -> tuple[str, dict]:
    res = run_bash(
        repo,
        SNIPPET,
        old_text,
        render(new),
        " ".join(skip),
        libs=("common", "defaults", "setup"),
        stdin="",
        timeout=60,
    )
    assert res.returncode == 0, res.stderr
    return res.stdout, json.loads(res.stdout)


@settings(deadline=None)
@given(old=states, new=states)
def test_setup_state_never_overwritten(repo, old, new):
    _, merged = merge(repo, render(old), new, [])
    assert list(merged) == PERMS
    for name in PERMS:
        if name in old:
            # Recorded values are kept unchanged.
            assert merged[name] is old[name]
        else:
            # Unrecorded permissions are filled from the new observation.
            assert merged[name] is new.get(name, False)


@settings(deadline=None)
@given(old=states, new=states, skip=skips)
def test_setup_state_skip_list(repo, old, new, skip):
    _, merged = merge(repo, render(old), new, skip)
    # A skipped permission is left out unless the old file records it.
    expected = [n for n in PERMS if n in old or n not in skip]
    assert list(merged) == expected
    for name in expected:
        if name in old:
            assert merged[name] is old[name]
        else:
            assert merged[name] is new.get(name, False)


@settings(deadline=None)
@given(old=states, new=states, skip=skips)
def test_setup_state_merge_idempotent(repo, old, new, skip):
    first_text, first = merge(repo, render(old), new, skip)
    # Re-merging the merged text with the same observation changes nothing.
    text_again, second = merge(repo, first_text, new, skip)
    assert second == first
    assert text_again == first_text
