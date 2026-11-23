"""Property 28: Export copies the selected files and nothing else.

**Validates: Requirements 11.10, 11.11**

For any set of files under captures/, `capture.sh export <dir>` copies exactly
the files named *.png or flow.* (laid out as <ts>/<profile>/<scenario>/<mode>/<file>),
byte for byte, under the name <ts>__<profile>__<scenario>__<mode>__<file>. It
creates <dir> when absent and leaves every source file unchanged. When nothing
matches it exits non-zero and creates no files.
"""

from __future__ import annotations

import tempfile
from pathlib import Path

from hypothesis import given
from hypothesis import strategies as st

from conftest import file_names, make_repo, profile_ids, run_capture, scenario_names

_timestamps = st.sampled_from(
    ["20260101T000000Z", "20260102T101010Z", "20261203T235959Z"]
)
_modes = st.sampled_from(["baseline", "ward"])
_flow_names = st.sampled_from([".mov", ".mp4", ".log", ".json", ".txt"]).map(
    lambda ext: "flow" + ext
)
_names = st.one_of(file_names, _flow_names)

_entries = st.tuples(
    _timestamps, profile_ids, scenario_names, _modes, _names, st.binary(max_size=200)
)

# Files that sit at the wrong depth must never be copied, even when named *.png.
_stray = st.tuples(
    st.sampled_from(["stray.png", "flow.mov", "a/stray.png", "a/b/flow.mov", "a/b/c/d/e/deep.png"]),
    st.binary(max_size=50),
)


def _selected(name: str) -> bool:
    return name.endswith(".png") or name.startswith("flow.")


def _snapshot(root: Path) -> dict[str, bytes]:
    return {
        str(p.relative_to(root)): p.read_bytes() for p in root.rglob("*") if p.is_file()
    }


@given(
    entries=st.lists(_entries, max_size=12),
    strays=st.lists(_stray, max_size=3),
    nested=st.booleans(),
)
def test_export_copies_selected_files_only(entries, strays, nested):
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        captures = repo.captures_dir
        expected: dict[str, bytes] = {}
        for ts, profile, scenario, mode, name, data in entries:
            rel = f"{ts}/{profile}/{scenario}/{mode}/{name}"
            path = captures / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if _selected(name):
                expected[f"{ts}__{profile}__{scenario}__{mode}__{name}"] = data
        for rel, data in strays:
            path = captures / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if not path.exists():
                path.write_bytes(data)

        before = _snapshot(captures)
        dest = Path(tmp) / "out" / "nested" / "dir" if nested else Path(tmp) / "out"
        assert not dest.exists()

        result = run_capture(repo, "export", str(dest))

        assert _snapshot(captures) == before  # sources unchanged
        if expected:
            assert result.returncode == 0, result.stderr
            assert dest.is_dir()
            assert _snapshot(dest) == expected
        else:
            assert result.returncode != 0
            assert "nothing to export" in result.stderr + result.stdout
            assert not dest.exists()


def test_export_destination_not_writable_is_distinct_error(tmp_path):
    repo = make_repo(tmp_path)
    src = repo.captures_dir / "20260101T000000Z" / "p" / "s" / "ward" / "hud.png"
    src.parent.mkdir(parents=True)
    src.write_bytes(b"x")
    blocker = tmp_path / "blocker"
    blocker.write_text("a file, not a directory")

    result = run_capture(repo, "export", str(blocker / "sub"))

    assert result.returncode != 0
    out = result.stderr + result.stdout
    assert "destination not writable" in out
    assert "nothing to export" not in out
