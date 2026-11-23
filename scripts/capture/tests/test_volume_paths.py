"""Property 17: Removable-volume path extraction.

**Validates: Requirements 5.5, 5.6**

Drives app_extract_volume_paths and app_check_paths in lib/app.sh through bash
with values passed as argv. osascript is the stub, so Finder is never used.
"""
from __future__ import annotations

import os
from pathlib import Path

import pytest
from hypothesis import given, strategies as st

from conftest import Repo, make_repo, run_bash

_NAME_BAD = set(" \t\n\r/\"'`,;:()[]{}<>|\\.")
_name_char = st.characters(
    blacklist_categories=("Cc", "Cs", "Zs", "Zl", "Zp"),
    blacklist_characters="".join(sorted(_NAME_BAD)),
)
# Volume names: start with a non-dot character, may hold spaces and inner dots,
# never end with "." (trailing dots are sentence punctuation).
_name_body = st.text(
    alphabet=st.one_of(_name_char, st.sampled_from([" ", ".", "-", "_", "!", "&", "#"])),
    min_size=0,
    max_size=20,
)
volume_names = st.builds(lambda h, b: h + b, _name_char, _name_body).filter(
    lambda n: not n.endswith(".")
)

# Filler text: arbitrary, but no "/" so it cannot form "/Volumes/" by itself.
filler = st.text(
    alphabet=st.characters(blacklist_categories=("Cs",), blacklist_characters="/\x00"),
    max_size=60,
)


def encode(name: str) -> str:
    """Write a name as it appears in a prompt: spaces are backslash-escaped."""
    return name.replace(" ", "\\ ")


@st.composite
def prompts(draw) -> tuple[str, list[str]]:
    names = draw(st.lists(volume_names, min_size=0, max_size=5))
    parts = [draw(filler)]
    for n in names:
        parts.append(" /Volumes/" + encode(n) + " ")
        parts.append(draw(filler))
    return "".join(parts), ["/Volumes/" + n for n in names]


def _extract(repo: Repo, prompt: str) -> list[str]:
    r = run_bash(repo, 'app_extract_volume_paths "$1"', prompt, libs=("app",))
    assert r.returncode == 0, r.stderr
    return r.stdout.split("\n")[:-1] if r.stdout else []


@given(case=prompts())
def test_extractor_returns_embedded_paths_in_order(tmp_path_factory, case):
    prompt, expected = case
    repo = make_repo(tmp_path_factory.mktemp("vol"))
    # A name with a line break inside filler cannot occur; names have no newlines.
    assert _extract(repo, prompt) == expected


@given(case=prompts().filter(lambda c: len(c[1]) > 0))
def test_missing_path_fails_and_sends_nothing(tmp_path_factory, case):
    prompt, paths = case
    paths = [p for p in paths if not Path(p).is_dir()]
    if not paths:  # a generated name collided with a real mounted volume
        return
    repo = make_repo(tmp_path_factory.mktemp("vol"))
    r = run_bash(
        repo,
        'app_check_paths "$1"',
        prompt,
        libs=("app",),
        env={"STUB_OSASCRIPT_OUT": "true"},
    )
    assert r.returncode == 1
    assert "removable volume path not found: " in r.stderr
    # Only read-only disk-exists queries may reach osascript; never a send.
    for call in repo.calls("osascript"):
        assert "disk-exists" in call


@given(prompt=filler)
def test_empty_list_passes(tmp_path_factory, prompt):
    repo = make_repo(tmp_path_factory.mktemp("vol"))
    r = run_bash(repo, 'app_check_paths "$1"', prompt, libs=("app",))
    assert r.returncode == 0, r.stderr
    assert repo.calls("osascript") == []


def _mounted() -> list[str]:
    try:
        return [
            n
            for n in os.listdir("/Volumes")
            if os.path.isdir(f"/Volumes/{n}")
            and n
            and not n.endswith(".")
            and not (set(n) & (_NAME_BAD - {" ", "."}))
            and not n.startswith(".")
        ]
    except OSError:
        return []


@pytest.mark.skipif(not _mounted(), reason="no mounted volume to use")
@given(data=st.data())
def test_existing_volumes_pass_only_when_finder_lists_disk(tmp_path_factory, data):
    names = data.draw(st.lists(st.sampled_from(_mounted()), min_size=1, max_size=3))
    text = data.draw(filler)
    prompt = text + "".join(f" /Volumes/{encode(n)} then" for n in names)
    repo = make_repo(tmp_path_factory.mktemp("vol"))
    ok = run_bash(
        repo, 'app_check_paths "$1"', prompt, libs=("app",), env={"STUB_OSASCRIPT_OUT": "true"}
    )
    assert ok.returncode == 0, ok.stderr
    queried = [c[-1] for c in repo.calls("osascript") if "disk-exists" in c]
    assert queried == names
    # Finder reports no such disk: the check fails.
    bad = run_bash(
        repo, 'app_check_paths "$1"', prompt, libs=("app",), env={"STUB_OSASCRIPT_OUT": "false"}
    )
    assert bad.returncode == 1
    assert "removable volume path not found: " in bad.stderr
