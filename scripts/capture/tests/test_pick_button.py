"""Property 18: Button selection.

**Validates: Requirements 10.1, 10.4**

Drives pick_button in lib/resolve.sh through bash. Labels go on stdin, the
choice is an argument, and the label lists come from the environment.
"""
from __future__ import annotations

from hypothesis import given, strategies as st

from conftest import Repo, button_labels, run_bash

SNIPPET = 'pick_button "$1"'
ENV_BASE = {"LC_ALL": "C"}

# Entries for the comma-separated lists: lower-case, no comma, no edge space.
_entries = st.one_of(
    st.sampled_from(["ok", "allow", "don't allow", "deny", "cancel", "allow once"]),
    st.text(alphabet="abcdefghijklmnopqrstuvwxyz '", min_size=1, max_size=10).filter(
        lambda s: s.strip() == s and s != ""
    ),
)
_lists = st.lists(_entries, min_size=1, max_size=5)


def normalize(s: str) -> str:
    for c in "\u2019\u2018\u02bc":
        s = s.replace(c, "'")
    s = "".join(chr(ord(c) + 32) if "A" <= c <= "Z" else c for c in s)
    return s.strip(" \t\n\r\x0b\x0c")


def expected(labels: list[str], entries: list[str]) -> str | None:
    wanted = {normalize(e) for e in entries if normalize(e)}
    for label in labels:
        n = normalize(label)
        if label and n and n in wanted:
            return label
    return None


def run_pick(repo: Repo, labels, choice, allow, deny):
    return run_bash(
        repo,
        SNIPPET,
        choice,
        libs=("resolve",),
        env={
            **ENV_BASE,
            "CAPTURE_ALLOW_LABELS": ",".join(allow),
            "CAPTURE_DENY_LABELS": ",".join(deny),
        },
        stdin="".join(l + "\n" for l in labels),
    )


@given(
    labels=st.lists(button_labels, min_size=0, max_size=8),
    choice=st.sampled_from(["allow", "deny"]),
    allow=_lists,
    deny=_lists,
)
def test_pick_button_returns_first_normalized_match(repo, labels, choice, allow, deny):
    proc = run_pick(repo, labels, choice, allow, deny)
    want = expected(labels, allow if choice == "allow" else deny)
    if want is None:
        assert proc.returncode == 1
        assert proc.stdout == ""
    else:
        assert proc.returncode == 0
        assert proc.stdout == want + "\n"


@given(
    labels=st.lists(button_labels, min_size=0, max_size=8),
    allow=_lists,
    deny=_lists,
)
def test_pick_button_never_crosses_lists(repo, labels, allow, deny):
    # Keep the lists disjoint so "never returns a label from the other list"
    # is well defined.
    allow_n = {normalize(e) for e in allow}
    deny = [d for d in deny if normalize(d) not in allow_n]
    if not deny:
        deny = ["zzz-deny-only"]
    deny_n = {normalize(e) for e in deny}
    for choice, other in (("allow", deny_n), ("deny", allow_n)):
        proc = run_pick(repo, labels, choice, allow, deny)
        if proc.returncode == 0:
            assert normalize(proc.stdout.rstrip("\n")) not in other


def test_pick_button_curly_apostrophe_and_case(repo):
    proc = run_pick(
        repo,
        ["Cancel", "Don\u2019t Allow", "OK"],
        "deny",
        ["ok", "allow"],
        ["don't allow", "deny"],
    )
    assert (proc.returncode, proc.stdout) == (0, "Don\u2019t Allow\n")
    proc = run_pick(repo, ["Cancel", "ALLOW", "OK"], "allow", ["ok", "allow"], ["deny"])
    assert (proc.returncode, proc.stdout) == (0, "ALLOW\n")


def test_pick_button_invalid_choice_returns_1(repo):
    proc = run_pick(repo, ["OK"], "none", ["ok"], ["deny"])
    assert proc.returncode == 1
    assert proc.stdout == ""
