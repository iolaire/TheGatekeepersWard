"""Property 13: Prompt window matching.
**Validates: Requirements 6.1**
Drives lib/windows.sh match_prompt through bash with the window list on stdin.
"""
from __future__ import annotations

from hypothesis import given, strategies as st

from conftest import Repo, format_window_list, run_bash, window_rows

SNIPPET = 'match_prompt "$@"'

OWNERS = ["UserNotificationCenter", "Gatekeeper's Ward", "Finder", "ZCode", "usernotificationcenter"]


@st.composite
def prompt_rows(draw, owner: str, layer: int) -> dict:
    row = draw(window_rows())
    row.update(owner=owner, layer=layer, w=draw(st.integers(1, 3000)), h=draw(st.integers(1, 3000)))
    return row


@st.composite
def near_rows(draw, owner: str, layer: int) -> dict:
    """A row that is wrong in at least one of owner, layer or size."""
    row = draw(window_rows())
    kind = draw(st.sampled_from(["owner", "layer", "w", "h", "any"]))
    if kind in ("owner", "any"):
        row["owner"] = draw(st.sampled_from([o for o in OWNERS if o != owner]))
    if kind in ("layer", "any"):
        row["layer"] = draw(st.integers(-5, 30).filter(lambda v: v != layer))
    if kind in ("w", "any"):
        row["w"] = 0
    if kind == "h":
        row["h"] = 0
    return row


def _qualifies(row: dict, owner: str, layer: int) -> bool:
    return row["owner"] == owner and row["layer"] == layer and row["w"] > 0 and row["h"] > 0


def _run(repo: Repo, rows: list[dict], *args: str) -> str:
    result = run_bash(repo, SNIPPET, *args, libs=("common", "defaults", "windows"),
                      stdin=format_window_list(rows))
    assert result.returncode == 0, result.stderr
    return result.stdout


@st.composite
def scenario(draw):
    owner = draw(st.sampled_from(OWNERS))
    layer = draw(st.integers(0, 12))
    rows = draw(st.lists(st.one_of(window_rows(), prompt_rows(owner, layer), near_rows(owner, layer)),
                         max_size=12))
    return owner, layer, rows


@given(scenario())
def test_returns_first_qualifying_row_or_nothing(repo: Repo, case) -> None:
    owner, layer, rows = case
    expected = next((r for r in rows if _qualifies(r, owner, layer)), None)
    out = _run(repo, rows, owner, str(layer))
    if expected is None:
        assert out == ""
    else:
        assert out == format_window_list([expected])


@given(
    st.sampled_from(OWNERS), st.integers(0, 12), st.data(),
)
def test_non_matching_rows_do_not_change_result(repo: Repo, owner: str, layer: int, data) -> None:
    match = data.draw(prompt_rows(owner, layer))
    before = data.draw(st.lists(near_rows(owner, layer), max_size=5))
    after = data.draw(st.lists(near_rows(owner, layer), max_size=5))
    assert not any(_qualifies(r, owner, layer) for r in before + after)
    assert _run(repo, before + [match] + after, owner, str(layer)) == format_window_list([match])
    assert _run(repo, before + after, owner, str(layer)) == ""


def test_defaults_use_configured_owner_and_layer(repo: Repo) -> None:
    rows = [
        {"number": 1, "owner": "Finder", "layer": 8, "alpha": 1.0, "x": 0, "y": 0, "w": 10, "h": 10},
        {"number": 2, "owner": "UserNotificationCenter", "layer": 7, "alpha": 1.0, "x": 0, "y": 0, "w": 10, "h": 10},
        {"number": 3, "owner": "UserNotificationCenter", "layer": 8, "alpha": 1.0, "x": 5, "y": 6, "w": 260, "h": 282},
    ]
    assert _run(repo, rows) == format_window_list([rows[2]])
