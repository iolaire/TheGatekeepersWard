"""Property 14: HUD and menu bar item matching.

**Validates: Requirements 6.4, 9.4**

For any ordered list of window rows, match_hud returns the first row with owner
Gatekeeper's Ward, layer 3, alpha above 0.9 and width within 2 points of 400.
match_ward_item returns the first row with owner Gatekeeper's Ward and layer at
or above 24. A HUD-shaped row with alpha 0.9 or less, or a different width, is
never returned by match_hud.
"""

from __future__ import annotations

from hypothesis import given, strategies as st

from conftest import (
    Repo,
    format_window_list,
    format_window_row,
    run_bash,
    window_lists,
    window_rows,
)

WARD = "Gatekeeper's Ward"
LIBS = ("common", "defaults", "windows")


def ref_hud(row: dict) -> bool:
    return (
        row["owner"] == WARD
        and row["layer"] == 3
        and row["alpha"] > 0.9
        and abs(row["w"] - 400) <= 2
    )


def ref_item(row: dict) -> bool:
    return row["owner"] == WARD and row["layer"] >= 24


def first(rows: list[dict], pred) -> str:
    for r in rows:
        if pred(r):
            return format_window_row(r) + "\n"
    return ""


def run_match(repo: Repo, fn: str, rows: list[dict]) -> str:
    result = run_bash(repo, f'{fn} <<<"$1"', format_window_list(rows).rstrip("\n"),
                      libs=LIBS, stubs=False)
    assert result.returncode == 0, result.stderr
    return result.stdout


@st.composite
def hud_shaped(draw) -> dict:
    """A Ward row that is near the HUD shape, valid or off by one criterion."""
    row = draw(window_rows())
    row["owner"] = WARD
    row["layer"] = draw(st.sampled_from([3, 3, 3, 2, 4, 24, 25]))
    row["alpha"] = draw(st.sampled_from([0.9, 0.91, 1.0, 0.5, 0.0]))
    row["w"] = draw(st.sampled_from([400, 398, 402, 397, 403, 399, 401, 0, 260]))
    return row


mixed_lists = st.lists(st.one_of(window_rows(), hud_shaped()), min_size=0, max_size=12)


@given(rows=mixed_lists)
def test_match_hud_returns_first_hud_row(repo: Repo, rows: list[dict]) -> None:
    assert run_match(repo, "match_hud", rows) == first(rows, ref_hud)


@given(rows=mixed_lists)
def test_match_ward_item_returns_first_item_row(repo: Repo, rows: list[dict]) -> None:
    assert run_match(repo, "match_ward_item", rows) == first(rows, ref_item)


@given(rows=window_lists, bad=hud_shaped(), data=st.data())
def test_hud_shaped_row_failing_alpha_or_width_never_returned(
    repo: Repo, rows: list[dict], bad: dict, data: st.DataObject
) -> None:
    if data.draw(st.booleans()):
        bad["alpha"] = data.draw(st.sampled_from([0.9, 0.5, 0.0]))
    else:
        bad["w"] = data.draw(st.sampled_from([397, 403, 0, 260, 800]))
    bad["layer"] = 3
    bad["number"] = 999999  # unique, so the output identifies it
    pos = data.draw(st.integers(0, len(rows)))
    full = rows[:pos] + [bad] + rows[pos:]
    out = run_match(repo, "match_hud", full)
    assert not out.startswith("999999\t")
    assert out == first(full, ref_hud)


def test_match_hud_boundaries(repo: Repo) -> None:
    base = {"number": 1, "owner": WARD, "layer": 3, "alpha": 1.0,
            "x": 0, "y": 0, "w": 400, "h": 300}
    for w, ok in [(398, True), (402, True), (397, False), (403, False)]:
        assert (run_match(repo, "match_hud", [dict(base, w=w)]) != "") is ok
    assert run_match(repo, "match_hud", [dict(base, alpha=0.9)]) == ""
    assert run_match(repo, "match_hud", [dict(base, alpha=0.91)]) != ""
    assert run_match(repo, "match_ward_item", [dict(base, layer=23)]) == ""
    assert run_match(repo, "match_ward_item", [dict(base, layer=24)]) != ""


def test_match_ward_registered_accepts_any_layer_owned_by_the_ward() -> None:
    """macOS 26+: the status item is not in the window list, so any Ward window counts."""
    import tempfile
    from pathlib import Path
    from conftest import make_repo, run_bash
    rows = "1\tFinder\t0\t1\t0\t0\t10\t10\n15432\tGatekeeper's Ward\t3\t1\t0\t1240\t400\t200\n"
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        res = run_bash(repo, 'printf "%s" "$1" | match_ward_registered', rows,
                       libs=("common", "defaults", "windows"), stdin="", timeout=60)
        assert res.stdout.strip().split("\t")[0] == "15432"
        res = run_bash(repo, 'printf "%s" "$1" | match_ward_registered', "1\tFinder\t0\t1\t0\t0\t10\t10\n",
                       libs=("common", "defaults", "windows"), stdin="", timeout=60)
        assert res.stdout.strip() == ""
