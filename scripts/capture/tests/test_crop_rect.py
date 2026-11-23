"""Property 16: Pair crop rectangle.

**Validates: Requirements 7.4**

For any two window rectangles and any display rectangle that contains at least
part of each, crop_rect with margin 24 returns a rectangle that lies inside the
display, contains the part of each window inside the display, and equals the
24-point expansion of the windows' union exactly when that expansion lies
inside the display. Swapping the two windows gives the same result.
"""
from __future__ import annotations

from hypothesis import given, settings, strategies as st

from conftest import Repo, rectangles, run_bash

LIBS = ("common", "shots")
MARGIN = 24


def fmt(r: tuple[int, int, int, int]) -> str:
    return " ".join(str(v) for v in r)


def crop(repo: Repo, prompt, hud, display, margin: int = MARGIN):
    proc = run_bash(
        repo,
        'crop_rect "$1" "$2" "$3" "$4"',
        fmt(prompt),
        fmt(hud),
        str(margin),
        fmt(display),
        libs=LIBS,
    )
    assert proc.returncode == 0, proc.stderr
    parts = proc.stdout.split()
    assert len(parts) == 4, proc.stdout
    x, y, w, h = (float(p) for p in parts)
    return x, y, w, h


def overlaps(a, b) -> bool:
    return (
        a[0] < b[0] + b[2]
        and b[0] < a[0] + a[2]
        and a[1] < b[1] + b[3]
        and b[1] < a[1] + a[3]
    )


def inter(a, b) -> tuple[int, int, int, int]:
    """Edges (l, t, r, b) of the intersection of two x y w h rectangles."""
    return (
        max(a[0], b[0]),
        max(a[1], b[1]),
        min(a[0] + a[2], b[0] + b[2]),
        min(a[1] + a[3], b[1] + b[3]),
    )


def union_expanded(a, b, m: int) -> tuple[int, int, int, int]:
    return (
        min(a[0], b[0]) - m,
        min(a[1], b[1]) - m,
        max(a[0] + a[2], b[0] + b[2]) + m,
        max(a[1] + a[3], b[1] + b[3]) + m,
    )


@st.composite
def scenes(draw):
    """Two windows and a display, each window overlapping the display."""
    prompt = draw(rectangles())
    hud = draw(rectangles())
    # Mix displays that are generous (expansion fits) and tight ones.
    if draw(st.booleans()):
        l, t, r, b = union_expanded(prompt, hud, draw(st.integers(0, 60)))
        display = (l, t, r - l, b - t)
    else:
        display = draw(rectangles())
    return prompt, hud, display


@given(scene=scenes())
def test_crop_rect_properties(repo: Repo, scene) -> None:
    prompt, hud, display = scene
    if not (overlaps(prompt, display) and overlaps(hud, display)):
        return
    x, y, w, h = crop(repo, prompt, hud, display)
    l, t, r, b = x, y, x + w, y + h
    dl, dt, dr, db = display[0], display[1], display[0] + display[2], display[1] + display[3]

    # Inside the display, non-empty.
    assert w > 0 and h > 0
    assert dl <= l and dt <= t and r <= dr and b <= db

    # Contains the part of each window inside the display.
    for win in (prompt, hud):
        il, it, ir, ib = inter(win, display)
        assert l <= il and t <= it and ir <= r and ib <= b

    # Smallest: equals the expanded union when that fits in the display;
    # otherwise equals the expanded union clamped to the display.
    el, et, er, eb = union_expanded(prompt, hud, MARGIN)
    expected = (max(el, dl), max(et, dt), min(er, dr), min(eb, db))
    assert (l, t, r, b) == expected
    if dl <= el and dt <= et and er <= dr and eb <= db:
        assert (l, t, r, b) == (el, et, er, eb)

    # Symmetric under swapping the windows.
    assert crop(repo, hud, prompt, display) == (x, y, w, h)
