"""Property 5: Bundle-ID guard.
**Validates: Requirements 3.2, 13.2, 13.3**
Drives lib/reset.sh guard_bundle_id through bash with every value as argv.
"""
from __future__ import annotations

from hypothesis import given
from hypothesis import strategies as st

from conftest import Repo, bundle_ids, run_bash

LIBS = ("common", "defaults", "validate", "profile", "reset")

# Any text bash can take as an argument: no NUL, no surrogates.
any_id = st.text(
    alphabet=st.characters(blacklist_categories=("Cs",), blacklist_characters="\x00"),
    max_size=40,
)

# "all" in any combination of ASCII letter case.
all_variants = st.tuples(*[st.booleans()] * 3).map(
    lambda flags: "".join(c.upper() if f else c for c, f in zip("all", flags))
)

known_sets = st.lists(
    st.one_of(bundle_ids, any_id, all_variants), min_size=0, max_size=6
)


def _guard(repo: Repo, ident: str, known: list[str]):
    return run_bash(repo, 'guard_bundle_id "$@"', ident, *known, libs=LIBS)


def _expected(ident: str, known: list[str]) -> bool:
    return ident != "" and ident.lower() != "all" and ident in known


def _contains(stderr: str, ident: str) -> bool:
    # text-mode capture turns \r and \r\n into \n
    return ident.replace("\r\n", "\n").replace("\r", "\n") in stderr


# Feature: permission-capture-framework, Property 5: Bundle-ID guard
@given(ident=st.one_of(any_id, bundle_ids, all_variants), known=known_sets, pick=st.booleans())
def test_guard_accepts_iff_nonempty_not_all_and_known(
    repo: Repo, ident: str, known: list[str], pick: bool
) -> None:
    if pick and known:
        ident = known[0]  # make the accepting branch common
    res = _guard(repo, ident, known)
    if _expected(ident, known):
        assert res.returncode == 0
        assert res.stderr == ""
    else:
        assert res.returncode == 1
        assert "refusing tccutil reset for bundle id" in res.stderr
        assert _contains(res.stderr, ident)
    assert repo.calls("tccutil") == []


def test_guard_rejects_all_even_when_listed(repo: Repo) -> None:
    for variant in ("All", "all", "ALL", "aLl"):
        res = _guard(repo, variant, [variant, "dev.demo.app"])
        assert res.returncode == 1
        assert variant in res.stderr
    assert _guard(repo, "", ["", "dev.demo.app"]).returncode == 1
    assert _guard(repo, "dev.demo.app", ["dev.demo.app"]).returncode == 0
