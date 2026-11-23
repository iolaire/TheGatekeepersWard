"""Property 9: an existing Session_Directory is never modified.

**Validates: Requirements 11.4**

session_create must exit 1 with "session directory already exists: <path>"
and leave every file and subdirectory of the existing directory untouched.
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

from hypothesis import given
from hypothesis import strategies as st

from conftest import file_names, make_repo, run_bash, scenario_names, profile_ids

# A tree entry: relative path of 1-3 segments plus file content.
_entry = st.tuples(
    st.lists(file_names, min_size=1, max_size=3),
    st.binary(min_size=0, max_size=64),
)
_trees = st.lists(_entry, min_size=0, max_size=8)
_modes = st.sampled_from(["baseline", "ward"])


def _populate(session: Path, tree) -> None:
    for segments, data in tree:
        target = session.joinpath(*segments)
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.is_dir():
                continue
            target.write_bytes(data)
        except (FileExistsError, NotADirectoryError):
            # A segment collided with an earlier file; skip this entry.
            continue


def _snapshot(session: Path) -> dict:
    """Everything observable: names, types, bytes, modes and mtimes."""
    snap: dict = {}
    for dirpath, dirnames, filenames in os.walk(session):
        dirnames.sort()
        d = Path(dirpath)
        st_d = d.stat()
        snap[str(d.relative_to(session))] = (
            "dir",
            tuple(sorted(dirnames + filenames)),
            st_d.st_mode,
            st_d.st_mtime_ns,
        )
        for f in filenames:
            p = d / f
            st_f = p.stat()
            snap[str(p.relative_to(session))] = (
                "file",
                p.read_bytes(),
                st_f.st_mode,
                st_f.st_mtime_ns,
            )
    return snap


@given(
    profile=profile_ids,
    scenario=scenario_names,
    mode=_modes,
    tree=_trees,
)
def test_existing_session_directory_is_never_modified(profile, scenario, mode, tree):
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        script = (
            'path="$(session_path "$CAPTURE_REPO_ROOT" "$1" "$2" "$3" "$4")"\n'
            'printf "%s" "$path" >"$5"\n'
            'session_create "$path"\n'
        )
        ts = "20260101T000000Z"
        session = Path(
            repo.root, "captures", ts, profile, scenario, mode
        )
        session.mkdir(parents=True)
        _populate(session, tree)
        before = _snapshot(session)

        path_file = Path(tmp) / "path.txt"
        result = run_bash(
            repo, script, ts, profile, scenario, mode, str(path_file),
            libs=("session",),
        )

        assert result.returncode == 1
        assert (
            f"session directory already exists: {session}" in result.stderr
        )
        assert _snapshot(session) == before
