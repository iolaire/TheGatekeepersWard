"""Property 39: Backup is byte-identical and never overwritten.
**Validates: Requirements 15.9, 17.7, 17.8**
For any generated database and any existing backup files, tcc_backup creates a
new file whose bytes equal the database's, leaves every earlier backup file
unchanged, and when called again for the same run changes nothing. When the
copy cannot be verified (size differs or the file is unreadable), it removes
the copy and returns non-zero.
Only temporary databases are used (CAPTURE_TCC_DB_TEST under the system
temporary directory). The real sqlite3 runs, never the stub.
"""
from __future__ import annotations
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path
import pytest
from hypothesis import given, settings, strategies as st
from conftest import Repo, make_repo, run_bash
LIBS = ("common", "tccdb")
_SNIPPET = 'tcc_backup "$1"'
run_ids = st.builds(
    lambda h, t: h + t,
    st.sampled_from("0123456789ABCDEFabcdef"),
    st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789._-", max_size=16),
)
cell_text = st.text(alphabet=st.characters(blacklist_categories=("Cs",), blacklist_characters="\x00"), max_size=20)
row = st.tuples(cell_text, cell_text, st.integers(0, 5), st.binary(max_size=40))
rows = st.lists(row, max_size=30)
junk_files = st.dictionaries(
    st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789._-", min_size=1, max_size=12).map(
        lambda s: "TCC.db.backup-old-" + s
    ),
    st.binary(max_size=200),
    max_size=4,
)
def _make_db(path: Path, data: list[tuple[str, str, int, bytes]]) -> None:
    conn = sqlite3.connect(path)
    try:
        conn.execute(
            "CREATE TABLE access (service TEXT, client TEXT, auth_value INTEGER, csreq BLOB)"
        )
        conn.executemany("INSERT INTO access VALUES (?,?,?,?)", data)
        conn.commit()
    finally:
        conn.close()
def _backup(repo: Repo, db: Path, state: Path, run: str):
    return run_bash(
        repo,
        _SNIPPET,
        run,
        libs=LIBS,
        env={"CAPTURE_TCC_DB_TEST": str(db), "CAPTURE_STATE_DIR": str(state)},
        stubs=False,
    )
def _listing(state: Path) -> dict[str, bytes]:
    return {p.name: p.read_bytes() for p in sorted(state.iterdir()) if p.is_file()}
@pytest.fixture
def work() -> Path:
    # Under the system temporary directory, which the module accepts for tests.
    d = Path(tempfile.mkdtemp(prefix="tccbackup-"))
    try:
        yield d
    finally:
        for p in d.rglob("*"):
            try:
                p.chmod(0o700)
            except OSError:
                pass
        shutil.rmtree(d, ignore_errors=True)
@given(data=rows, run=run_ids, earlier=junk_files)
def test_backup_is_byte_identical_and_idempotent(data, run, earlier):
    base = Path(tempfile.mkdtemp(prefix="tccbackup-"))
    try:
        repo = make_repo(base)
        db = base / "TCC.db"
        _make_db(db, data)
        state = base / "state"
        state.mkdir()
        for name, blob in earlier.items():
            (state / name).write_bytes(blob)
        before = _listing(state)
        proc = _backup(repo, db, state, run)
        assert proc.returncode == 0, proc.stderr
        dest = state / f"TCC.db.backup-{run}"
        assert dest.read_bytes() == db.read_bytes()
        after = _listing(state)
        for name, blob in before.items():
            assert after[name] == blob
        assert set(after) == set(before) | {dest.name}
        # Same run again: nothing changes, even when the database has changed.
        conn = sqlite3.connect(db)
        conn.execute("INSERT INTO access VALUES ('x','y',1,NULL)")
        conn.commit()
        conn.close()
        proc2 = _backup(repo, db, state, run)
        assert proc2.returncode == 0, proc2.stderr
        assert _listing(state) == after
    finally:
        for p in base.rglob("*"):
            try:
                p.chmod(0o700)
            except OSError:
                pass
        shutil.rmtree(base, ignore_errors=True)
@given(blob=st.binary(min_size=1, max_size=300), run=run_ids, earlier=junk_files)
@settings(max_examples=25)
def test_unverifiable_copy_is_removed(blob, run, earlier):
    """A file sqlite3 cannot read as a database with an access table fails and leaves no copy."""
    base = Path(tempfile.mkdtemp(prefix="tccbackup-"))
    try:
        repo = make_repo(base)
        db = base / "TCC.db"
        db.write_bytes(b"not a database " + blob)
        state = base / "state"
        state.mkdir()
        for name, content in earlier.items():
            (state / name).write_bytes(content)
        before = _listing(state)
        proc = _backup(repo, db, state, run)
        assert proc.returncode != 0
        assert _listing(state) == before
        assert not (state / f"TCC.db.backup-{run}").exists()
        assert not (state / f"TCC.db.backup-{run}-wal").exists()
        assert not (state / f"TCC.db.backup-{run}-shm").exists()
    finally:
        shutil.rmtree(base, ignore_errors=True)
@pytest.mark.skipif(os.geteuid() == 0, reason="root can read any file")
def test_unreadable_database_fails_without_copy(work):
    repo = make_repo(work)
    db = work / "TCC.db"
    _make_db(db, [("a", "b", 1, b"c")])
    state = work / "state"
    state.mkdir()
    keep = state / "TCC.db.backup-earlier"
    keep.write_bytes(b"earlier")
    db.chmod(0)
    proc = _backup(repo, db, state, "r1")
    db.chmod(0o600)
    assert proc.returncode != 0
    assert _listing(state) == {"TCC.db.backup-earlier": b"earlier"}


def test_missing_database_fails_without_copy(work):
    repo = make_repo(work)
    state = work / "state"
    state.mkdir()
    proc = _backup(repo, work / "absent.db", state, "r1")
    assert proc.returncode != 0
    assert _listing(state) == {}
