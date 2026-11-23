"""Property 2: Profile loading ignores non-profile files.
**Validates: Requirements 4.1, 4.5, 4.9**
Drives lib/profile.sh (profile_load_all, cmd_list) through bash. The profiles
directory is a throwaway directory selected with CAPTURE_PROFILES_DIR.
"""
from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from hypothesis import given, strategies as st, settings

from conftest import Repo, run_bash, E2E_EXAMPLES

LIBS = ("common", "defaults", "validate", "profile")

_STEM_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789-_."

# Stems of valid profiles: no leading dot (the glob skips hidden files), and
# unique, so file names never collide on a case-insensitive file system.
stems = st.text(alphabet=_STEM_CHARS, min_size=1, max_size=15).filter(
    lambda s: not s.startswith(".")
)

# Names of other files: none ends in ".profile".
_other_names = st.builds(
    lambda stem, suffix: stem + suffix,
    st.text(alphabet=_STEM_CHARS, min_size=0, max_size=15),
    st.sampled_from(
        ["", ".txt", ".md", ".profile.example", ".profile.bak", ".profile~",
         "profile", ".sh", ".example", ".profile.swp", "-profile"]
    ),
).filter(lambda n: n not in ("", ".", "..") and not n.endswith(".profile"))

# Contents of other files: valid-looking, invalid, empty, binary-ish.
_other_content = st.one_of(
    st.just(""),
    st.text(max_size=80).filter(lambda s: "\x00" not in s),
    st.just("this is not = a valid\nprofile at all\n"),
)


def _valid_profile(stem: str) -> str:
    return (
        f"profile_id = {stem}\n"
        "display_name = Test App\n"
        "bundle_id = com.example.app\n"
        "launch = open -b com.example.app\n"
        "input_locator = ax:text area 1\n"
        "send_action = key:return\n"
        "scenario.main.prompt = List the Desktop\n"
        "scenario.main.service = SystemPolicyDesktopFolder\n"
    )


def _load(repo: Repo, d: Path) -> tuple[int, list[tuple[str, str]]]:
    snippet = (
        'profile_load_all "$1"; rc=$?; echo "rc=$rc"; '
        'for i in "${!CAPTURE_PROFILE_IDS[@]}"; do '
        'printf "%s\\t%s\\n" "${CAPTURE_PROFILE_IDS[$i]}" "${CAPTURE_PROFILE_FILES[$i]}"; done'
    )
    r = run_bash(repo, snippet, str(d), libs=LIBS, stubs=False)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.split("\n")
    assert lines[0].startswith("rc=")
    rows = [tuple(ln.split("\t")) for ln in lines[1:] if ln]
    return int(lines[0][3:]), rows  # type: ignore[return-value]


def _list(repo: Repo, d: Path) -> list[str]:
    r = run_bash(repo, "cmd_list", libs=LIBS, stubs=False, env={"CAPTURE_PROFILES_DIR": str(d)})
    assert r.returncode == 0, r.stderr
    return [ln for ln in r.stdout.split("\n") if ln]


def _populate(d: Path, profile_stems: list[str], others: list[tuple[str, str]]) -> None:
    for s in profile_stems:
        (d / f"{s}.profile").write_text(_valid_profile(s))
    for name, content in others:
        (d / name).write_text(content)


@st.composite
def directories(draw):
    """(profile stems, other files) with names unique ignoring case."""
    ps = draw(st.lists(stems, min_size=0, max_size=6, unique_by=str.lower))
    taken = {f"{p}.profile".lower() for p in ps}
    others = draw(
        st.lists(st.tuples(_other_names, _other_content), min_size=0, max_size=8,
                 unique_by=lambda t: t[0].lower())
    )
    others = [o for o in others if o[0].lower() not in taken]
    return ps, others


@given(data=directories())
def test_loads_exactly_profile_files(repo: Repo, data) -> None:
    ps, others = data
    d = Path(tempfile.mkdtemp(prefix="profdir-"))
    try:
        _populate(d, ps, others)
        (d / "subdir.profile.d").mkdir()  # directories never count
        rc, rows = _load(repo, d)
        assert rc == 0
        ids_loaded = [i for i, _ in rows]
        assert sorted(ids_loaded) == sorted(ps)
        assert sorted(f for _, f in rows) == sorted(str(d / f"{p}.profile") for p in ps)
        # IDs are the file-name stems.
        assert all(Path(f).name == f"{i}.profile" for i, f in rows)
    finally:
        shutil.rmtree(d, ignore_errors=True)


@settings(max_examples=E2E_EXAMPLES)
@given(data=directories(), new_stem=stems)
def test_adding_one_profile_adds_exactly_one_list_entry(repo: Repo, data, new_stem: str) -> None:
    ps, others = data
    if new_stem.lower() in {p.lower() for p in ps} or any(
        o[0].lower() == f"{new_stem}.profile".lower() for o in others
    ):
        return
    d = Path(tempfile.mkdtemp(prefix="profdir-"))
    try:
        _populate(d, ps, others)
        before = _list(repo, d) if ps else None
        (d / f"{new_stem}.profile").write_text(_valid_profile(new_stem))
        after = _list(repo, d)
        assert len(after) == len(ps) + 1
        assert sum(1 for ln in after if ln.split("\t")[0] == new_stem) == 1
        if before is not None:
            remaining = list(after)
            for ln in before:
                remaining.remove(ln)  # every earlier line is unchanged
            assert len(remaining) == 1 and remaining[0].split("\t")[0] == new_stem
    finally:
        shutil.rmtree(d, ignore_errors=True)


def test_missing_directory_loads_nothing(repo: Repo, tmp_path: Path) -> None:
    rc, rows = _load(repo, tmp_path / "absent")
    assert rc == 0 and rows == []
