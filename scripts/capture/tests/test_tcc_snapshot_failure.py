"""Property 41: A failed snapshot blocks every reset.
**Validates: Requirements 15.7, 15.8, 17.8**
Drives `capture.sh reset <profile>` against a temporary access database selected
through CAPTURE_TCC_DB_TEST (HOME is a temporary directory too, so the user
database is never reachable). One failure is injected per example:
unreadable database, missing database, `sqlite3` missing from PATH, a failing
columns query, a failing rows query, a write that cannot complete (read-only
state directory), and a snapshot file whose row count differs from the query's
(count query off by one, or the rows query losing its last row).
Each must leave the tccutil stub uncalled, exit non-zero, print the reason,
leave no snapshot or temporary file, and leave the database byte-identical.
"""
from __future__ import annotations

import hashlib
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest
from hypothesis import given, strategies as st, settings

from conftest import Repo, TccDb, access_row, access_tables, E2E_EXAMPLES

BUNDLE = "dev.zcode.app"  # bundle_id of profiles/zcode.profile
PROFILE = "zcode"
SERVICES = ("SystemPolicyDesktopFolder", "SystemPolicyRemovableVolumes")  # zcode scenarios
# Rows in the access table carry the DB form of each service name.
DB_SERVICES = tuple("kTCCService" + s for s in SERVICES)
UNDECLARED = ("kTCCServiceCamera", "kTCCServiceMicrophone")

# Wrapper placed ahead of the sqlite3 stub. It reads the SQL script from stdin
# (the probe passes its query as an argument and has an empty stdin), then
# either injects the failure named in WRAP_SQL_FAIL or passes through to the
# real sqlite3. It also refuses any real TCC database path.
WRAPPER = r"""#!/bin/bash
for a in "$@"; do
  case "$a" in
    *com.apple.TCC*|*/TCC.db) echo "wrapper: refusing real TCC database" >&2; exit 99 ;;
  esac
done
in="$(cat)"
mode="${WRAP_SQL_FAIL:-}"
case "$mode:$in" in
  columns:*pragma_table_info*)
    echo "Error: injected columns failure" >&2; exit 1 ;;
  rows:*typeof*)
    echo "Error: injected rows failure" >&2; exit 1 ;;
  count:*"count(*)"*)
    out="$(printf '%s\n' "$in" | /usr/bin/sqlite3 "$@")" || exit $?
    echo $((out + 1)); exit 0 ;;
  short:*typeof*)
    printf '%s\n' "$in" | /usr/bin/sqlite3 "$@" | sed '$d'
    exit "${PIPESTATUS[0]}" ;;
esac
printf '%s\n' "$in" | /usr/bin/sqlite3 "$@"
"""

KINDS = (
    "unreadable",
    "missing_db",
    "no_sqlite3",
    "columns_fail",
    "rows_fail",
    "state_readonly",
    "count_mismatch",
    "rows_short",
)
# kind -> (wrapper mode, text the reason must contain)
REASON = {
    "unreadable": "cannot read the TCC database",
    "missing_db": "database not found",
    "no_sqlite3": "sqlite3 not found",
    "columns_fail": "injected columns failure",
    "rows_fail": "injected rows failure",
    "state_readonly": "cannot write snapshot file",
    "count_mismatch": "snapshot verification failed",
    "rows_short": "snapshot verification failed",
}
WRAP_MODE = {"columns_fail": "columns", "rows_fail": "rows", "count_mismatch": "count", "rows_short": "short"}
OPEN_ERRORS = ("unreadable", "missing_db")  # must name the Full Disk Access pane


@pytest.fixture(scope="module")
def no_sqlite3_bin(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """A bin directory with the stubs (minus sqlite3) and every system tool except sqlite3."""
    d = tmp_path_factory.mktemp("nosqlite-bin")
    stubs = Path(__file__).resolve().parent / "stubs"
    for stub in stubs.iterdir():
        if stub.name == "sqlite3":
            continue
        shutil.copy2(stub, d / stub.name)
        (d / stub.name).chmod(0o755)
    for sysdir in ("/usr/bin", "/bin", "/usr/sbin", "/sbin"):
        for entry in os.scandir(sysdir):
            if entry.name == "sqlite3" or (d / entry.name).exists():
                continue
            (d / entry.name).symlink_to(entry.path)
    assert not (d / "sqlite3").exists()
    return d


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _run_reset(repo: Repo, db: TccDb, state: Path, home: Path, path: str, extra_args=(), wrap_mode: str = ""):
    env = dict(os.environ)
    env.update(
        {
            "PATH": path,
            "HOME": str(home),
            "STUB_CALL_LOG": str(repo.call_log),
            "CAPTURE_STATE_DIR": str(state),
            "WRAP_SQL_FAIL": wrap_mode,
            **db.env,
        }
    )
    env.pop("CAPTURE_PROFILES_DIR", None)
    return subprocess.run(
        ["/bin/bash", str(repo.capture_dir / "capture.sh"), "reset", PROFILE, *extra_args],
        capture_output=True,
        text=True,
        input="",
        env=env,
        cwd=repo.root,
        timeout=60,
    )


def _wrapper_dir(base: Path) -> Path:
    d = base / "wrap-bin"
    d.mkdir(exist_ok=True)
    w = d / "sqlite3"
    w.write_text(WRAPPER)
    w.chmod(0o755)
    return d


def _stub_path(repo: Repo, *front: Path) -> str:
    return os.pathsep.join([*map(str, front), str(repo.stubs_dir), os.environ.get("PATH", "")])


@st.composite
def scenarios(draw):
    kind = draw(st.sampled_from(KINDS))
    table = draw(access_tables(BUNDLE, declared=DB_SERVICES, undeclared=UNDECLARED))
    # At least one scope row, so the rows_short injection always changes the count.
    table.append(draw(access_row(BUNDLE, draw(st.sampled_from(DB_SERVICES)))))
    use_service = draw(st.booleans())
    return kind, table, use_service


# Feature: permission-capture-framework, Property 41: A failed snapshot blocks every reset
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_failed_snapshot_blocks_every_reset(
    repo: Repo, tcc_db: TccDb, tmp_path: Path, no_sqlite3_bin: Path, scenario
) -> None:
    kind, table, use_service = scenario
    tcc_db.reset(table)
    repo.call_log.unlink(missing_ok=True)
    state = tmp_path / "state"
    state.mkdir(exist_ok=True)
    for f in state.iterdir():
        f.unlink()
    home = tmp_path / "home"
    home.mkdir(exist_ok=True)
    before = _sha(tcc_db.path)
    extra = ("--service", SERVICES[0]) if use_service else ()

    path = _stub_path(repo, _wrapper_dir(tmp_path))
    if kind == "no_sqlite3":
        path = str(no_sqlite3_bin)
    try:
        if kind == "unreadable":
            tcc_db.path.chmod(0)
        elif kind == "missing_db":
            tcc_db.path.unlink()
        elif kind == "state_readonly":
            state.chmod(stat.S_IRUSR | stat.S_IXUSR)
        res = _run_reset(repo, tcc_db, state, home, path, extra, WRAP_MODE.get(kind, ""))
    finally:
        state.chmod(0o755)
        if tcc_db.path.exists():
            tcc_db.path.chmod(0o600)

    out = res.stdout + res.stderr
    assert res.returncode != 0, out
    assert REASON[kind] in out, out
    if kind in OPEN_ERRORS:
        assert "Full Disk Access" in out, out
    assert repo.calls("tccutil") == [], out  # no reset call of any kind
    assert list(state.iterdir()) == [], list(state.iterdir())  # no snapshot, no temp file
    if kind != "missing_db":
        assert _sha(tcc_db.path) == before  # database untouched


def test_harness_control_snapshot_then_resets(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    """Without an injected failure the same harness snapshots, then resets (guards the property)."""
    tcc_db.reset([])
    state = tmp_path / "state"
    home = tmp_path / "home"
    home.mkdir()
    res = _run_reset(repo, tcc_db, state, home, _stub_path(repo, _wrapper_dir(tmp_path)))
    assert res.returncode == 0, res.stdout + res.stderr
    assert (state / f"tcc-snapshot-{BUNDLE}.json").is_file()
    assert [c[1:] for c in repo.calls("tccutil")] == [["reset", s, BUNDLE] for s in SERVICES]


def test_absent_user_database_folder_blocks_reset_with_no_restore_hint(
    repo: Repo, tcc_db: TccDb, tmp_path: Path
) -> None:
    """Probe exit 3: the message points to --no-restore, no Full Disk Access hint, no reset."""
    tcc_db.reset([])
    state = tmp_path / "state"
    home = tmp_path / "home"
    home.mkdir()
    nodb = tmp_path.resolve() / "no-such-dir" / "TCC-test.sqlite"
    res = _run_reset(repo, TccDb(path=nodb), state, home, _stub_path(repo, _wrapper_dir(tmp_path)))
    out = res.stdout + res.stderr
    assert res.returncode != 0, out
    assert "no user TCC database on this macOS" in out, out
    assert "use --no-restore" in out, out
    assert "Full Disk Access" not in out, out
    assert repo.calls("tccutil") == [], out
    assert not state.exists() or list(state.iterdir()) == []
