"""Property 12: Option validators.

**Validates: Requirements 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3**

Drives lib/validate.sh through bash with values passed as argv.
"""

from __future__ import annotations

import re

from hypothesis import given, strategies as st

from conftest import Repo, run_bash

# Ranges from design.md: launch timeout, prompt timeout, dwell.
RANGES = {"launch": (1, 300), "prompt": (1, 300), "dwell": (1, 60)}

# Arbitrary text without NUL (argv cannot carry it) or surrogates.
any_text = st.text(
    alphabet=st.characters(blacklist_categories=("Cs",), blacklist_characters="\x00"),
    max_size=30,
)
# Digit strings of at most 18 digits, with leading zeros allowed.
digit_text = st.text(alphabet="0123456789", min_size=1, max_size=18)
# Mix that hits boundaries, signs, spaces, newlines and non-ASCII digits.
range_candidates = st.one_of(
    any_text,
    digit_text,
    st.integers(-5, 400).map(str),
    st.sampled_from(["0", "1", "60", "61", "300", "301", "+5", "-1", "5 ", " 5", "5\n",
                     "1.0", "0x10", "\u0665", "1e2", ""]),
)

DIGITS = re.compile(r"[0-9]+\Z")


def _in_range(v: str, lo: int, hi: int) -> bool:
    return bool(DIGITS.match(v)) and lo <= int(v) <= hi


def _ok(repo: Repo, fn: str, *args: str) -> bool:
    r = run_bash(repo, f'{fn} "$@"', *args, libs=("validate",), stubs=False)
    assert r.returncode in (0, 1), r.stderr
    return r.returncode == 0


@given(v=any_text | st.sampled_from(["allow", "deny", "none", "Allow", "deny ", "deny\n", ""]))
def test_valid_resolve_iff_allow_deny_none(repo: Repo, v: str) -> None:
    assert _ok(repo, "valid_resolve", v) == (v in ("allow", "deny", "none"))


@given(v=range_candidates)
def test_valid_range_matches_integer_oracle(repo: Repo, v: str) -> None:
    # One bash run checks all three documented ranges.
    snippet = (
        'for r in "1 300" "1 300" "1 60"; do set -- "$V" $r; '
        'if valid_range "$@"; then printf 1; else printf 0; fi; done'
    )
    r = run_bash(repo, snippet, libs=("validate",), stubs=False, env={"V": v})
    assert r.returncode == 0, r.stderr
    expected = "".join("1" if _in_range(v, lo, hi) else "0" for lo, hi in RANGES.values())
    assert r.stdout == expected


@given(idx=range_candidates, n=st.integers(0, 8))
def test_valid_display_iff_within_count(repo: Repo, idx: str, n: int) -> None:
    assert _ok(repo, "valid_display", idx, str(n)) == _in_range(idx, 1, n)


@given(idx=st.integers(-3, 12), n=st.integers(1, 8))
def test_valid_display_integer_bounds(repo: Repo, idx: int, n: int) -> None:
    assert _ok(repo, "valid_display", str(idx), str(n)) == (1 <= idx <= n)


@given(v=st.text(min_size=1, max_size=20, alphabet=st.characters(
    # "\r" excluded: subprocess text mode translates it to "\n" on read.
    blacklist_categories=("Cs",), blacklist_characters="\x00\r")))
def test_with_default_returns_value_when_present(repo: Repo, v: str) -> None:
    r = run_bash(repo, 'with_default "$1" zzz', v, libs=("validate",), stubs=False)
    assert r.returncode == 0
    assert r.stdout == v + "\n"


def test_with_default_documented_defaults(repo: Repo) -> None:
    snippet = (
        'with_default "" "$CAPTURE_DEFAULT_LAUNCH_TIMEOUT"; '
        'with_default "" "$CAPTURE_DEFAULT_PROMPT_TIMEOUT"; '
        'with_default "" "$CAPTURE_DEFAULT_DWELL"; '
        'with_default "" "$CAPTURE_DEFAULT_RESOLVE"; '
        'with_default "" "$CAPTURE_DEFAULT_DISPLAY"'
    )
    r = run_bash(repo, snippet, libs=("validate",), stubs=False)
    assert r.stdout.split() == ["20", "45", "4", "deny", "1"]
