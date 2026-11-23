"""Property 43: Database references stay in tccdb.sh.
**Validates: Requirements 13.1, 13.11, 14.9**

For any directory tree, scan_tcc_refs reports exactly the files that contain
TCC.db or com.apple.TCC and are not lib/tccdb.sh, a file under tests/, or a
*.md file. The same scan of the real scripts/capture tree reports nothing.
"""
from __future__ import annotations

import tempfile
from pathlib import Path

from hypothesis import given, strategies as st

from conftest import CAPTURE_SRC
from tcc_scan import scan_tcc_refs

_SEGMENT = st.sampled_from(
    ["lib", "tests", "tccdb.sh", "a.sh", "b.md", "notes.MD", "x", "profiles", "tests2", "c.txt", "d.md.txt"]
)
_PATH = st.lists(_SEGMENT, min_size=1, max_size=3).map("/".join)
_NEEDLE = st.sampled_from([b"TCC.db", b"com.apple.TCC", b"TCCxdb", b"com.apple.tcc", b"TCC.d", b""])
_CONTENT = st.tuples(st.binary(max_size=30), _NEEDLE, st.binary(max_size=30)).map(lambda t: b"".join(t))


def _expected(rel: str, data: bytes) -> bool:
    """Independent oracle written straight from the property statement."""
    has_ref = b"TCC.db" in data or b"com.apple.TCC" in data
    exempt = rel == "lib/tccdb.sh" or rel.startswith("tests/") or rel.endswith(".md")
    return has_ref and not exempt


def _consistent(tree: dict[str, bytes]) -> dict[str, bytes]:
    """Drop paths that would need a file to also be a directory."""
    keep: dict[str, bytes] = {}
    for rel in sorted(tree, key=lambda p: (p.count("/"), p)):
        parts = rel.split("/")
        prefixes = {"/".join(parts[:i]) for i in range(1, len(parts))}
        if prefixes & set(keep) or any(k.startswith(rel + "/") for k in keep):
            continue
        keep[rel] = tree[rel]
    return keep


@given(st.dictionaries(_PATH, _CONTENT, max_size=12))
def test_scan_reports_exactly_non_exempt_reference_files(tree: dict[str, bytes]) -> None:
    tree = _consistent(tree)
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, data in tree.items():
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        expected = {rel for rel, data in tree.items() if _expected(rel, data)}
        assert scan_tcc_refs(root) == expected


def test_scan_known_cases() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        files = {
            "lib/tccdb.sh": b"TCC.db",
            "lib/other.sh": b"x com.apple.TCC y",
            "tests/t.py": b"TCC.db",
            "README.md": b"TCC.db",
            "clean.sh": b"nothing",
        }
        for rel, data in files.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes(data)
        assert scan_tcc_refs(root) == {"lib/other.sh"}


def test_real_capture_tree_has_no_references_outside_tccdb() -> None:
    assert scan_tcc_refs(CAPTURE_SRC) == set()
