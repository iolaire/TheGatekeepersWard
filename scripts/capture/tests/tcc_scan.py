"""Scan helper for Property 43: database references stay in lib/tccdb.sh.

scan_tcc_refs(root) returns the root-relative POSIX paths of regular files
that contain a TCC database reference, excluding the files allowed to hold one.
"""
from __future__ import annotations

from pathlib import Path

# Byte needles; files are read as bytes so binary content is scanned too.
NEEDLES = (b"TCC.db", b"com.apple.TCC")
ALLOWED_FILE = "lib/tccdb.sh"
ALLOWED_DIR = "tests"
ALLOWED_SUFFIX = ".md"


def is_exempt(rel: str) -> bool:
    """True when the root-relative POSIX path may legitimately hold a reference."""
    return rel == ALLOWED_FILE or rel.startswith(ALLOWED_DIR + "/") or rel.endswith(ALLOWED_SUFFIX)


def scan_tcc_refs(root: Path) -> set[str]:
    """Return relative paths under root that contain a needle and are not exempt.

    Symlinks are not followed, so a link cannot pull in content from outside
    the tree.
    """
    root = Path(root)
    found: set[str] = set()
    for path in root.rglob("*"):
        if path.is_symlink() or not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        if is_exempt(rel):
            continue
        data = path.read_bytes()
        if any(needle in data for needle in NEEDLES):
            found.add(rel)
    return found
