"""Property 36: Failed restore leaves the database unchanged.
**Validates: Requirements 16.7, 16.12, 16.13**
Takes a real snapshot of a generated temporary database, injects one fault into
the snapshot file (a NOT NULL violation part way through the rows, a column the
table lacks, or a cell outside the cell grammar), optionally changes the scope
rows, then runs tcc_restore. Afterwards every row of the database is unchanged,
the snapshot file is byte for byte the same and still pending, and the exit
status is non-zero. A malformed cell is refused before any sqlite3 write: a
logging sqlite3 wrapper must not have seen BEGIN or INSERT.
Only temporary databases selected through CAPTURE_TCC_DB_TEST are opened.
tcc_restore runs with stubs=False (real osascript parses the snapshot).
"""
from __future__ import annotations

import json
import os
import shutil
import sqlite3
from pathlib import Path

from hypothesis import HealthCheck, given, settings, strategies as st
from conftest import E2E_EXAMPLES

from conftest import (
    ACCESS_COLUMNS,
    DECLARED_SERVICES,
    Repo,
    TccDb,
    access_row,
    access_tables,
    bundle_ids,
    run_bash,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")
_NOT_NULL = (
    "client_type",
    "auth_value",
    "auth_reason",
    "auth_version",
    "indirect_object_identifier",
    "last_modified",
)
_BAD_CELLS = (
    "x:12",
    "plain",
    "",
    "i:abc",
    "i:",
    "i:1.5",
    "i:99999999999999999999",
    "t:zz",
    "t:abc",
    "b:0g",
    "r:1.5",
    "n:5",
    "t:41'; DROP TABLE access;--",
    "i:1\u0001",
)
_WRAPPER = """#!/bin/bash
# Logs the SQL fed to sqlite3, then runs the real binary. Callers that pass
# SQL as an argument give no stdin, so never block reading a terminal or pipe.
echo "ARGS: $*" >> "$SQL_LOG"
tee -a "$SQL_LOG" | /usr/bin/sqlite3 "$@"
"""


def _env(db: TccDb, state: Path, bundle: str, tooldir: Path, log: Path) -> dict[str, str]:
    return {
        "PATH": os.pathsep.join([str(tooldir), "/usr/bin", "/bin", "/usr/sbin", "/sbin"]),
        "SQL_LOG": str(log),
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _dump(db: TccDb) -> list[tuple]:
    """Every row of the database with Python types, read independently."""
    conn = sqlite3.connect(f"file:{db.path}?mode=ro", uri=True)
    try:
        cur = conn.execute(f"SELECT rowid, {','.join(ACCESS_COLUMNS)} FROM access ORDER BY rowid")
        return [tuple((type(c).__name__, c) for c in r) for r in cur.fetchall()]
    finally:
        conn.close()


def _delete_scope(db: TccDb, bundle: str) -> None:
    conn = sqlite3.connect(str(db.path))
    try:
        marks = ",".join("?" for _ in DECLARED_SERVICES)
        conn.execute(
            f"DELETE FROM access WHERE client = ? AND service IN ({marks})",
            [bundle, *DECLARED_SERVICES],
        )
        conn.commit()
    finally:
        conn.close()


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    extra = draw(access_row(bundle, draw(st.sampled_from(DECLARED_SERVICES))))
    fault = draw(st.sampled_from(["not_null", "unknown_column", "bad_cell"]))
    return {
        "bundle": bundle,
        "rows": rows + [extra],
        "fault": fault,
        "row_pick": draw(st.integers(0, 50)),
        "col_pick": draw(st.integers(0, 50)),
        "bad_cell": draw(st.sampled_from(_BAD_CELLS)),
        "drop_scope": draw(st.booleans()),
    }


def _inject(snap: Path, sc: dict) -> None:
    data = json.loads(snap.read_text())
    assert data["rows"], "scenario must put a row in scope"
    k = sc["row_pick"] % len(data["rows"])
    row = data["rows"][k]
    cols = data["columns"]
    if sc["fault"] == "not_null":
        name = _NOT_NULL[sc["col_pick"] % len(_NOT_NULL)]
        row[cols.index(name)] = "n:"
    elif sc["fault"] == "unknown_column":
        cols.append("no_such_column")
        for r in data["rows"]:
            r.append("i:1")
    else:
        # Any column except client and service, which the scope check reads.
        free = [i for i, c in enumerate(cols) if c not in ("client", "service")]
        row[free[sc["col_pick"] % len(free)]] = sc["bad_cell"]
    snap.write_text(json.dumps(data))


# Feature: permission-capture-framework, Property 36: Failed restore leaves the database unchanged
@settings(max_examples=E2E_EXAMPLES, deadline=None, suppress_health_check=list(HealthCheck))
@given(sc=scenarios())
def test_failed_restore_changes_nothing(repo: Repo, tcc_db: TccDb, tmp_path: Path, sc) -> None:
    bundle = sc["bundle"]
    tcc_db.reset(sc["rows"])
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)
    tooldir = tmp_path / "tools"
    tooldir.mkdir(exist_ok=True)
    wrapper = tooldir / "sqlite3"
    wrapper.write_text(_WRAPPER)
    wrapper.chmod(0o755)
    log = tmp_path / "sql.log"
    log.write_text("")
    env = _env(tcc_db, state, bundle, tooldir, log)

    res = run_bash(
        repo, 'b="$1"; shift; tcc_snapshot "$b" "$@"', bundle, *DECLARED_SERVICES,
        libs=LIBS, env=env, stubs=False, stdin="", timeout=30,
    )
    assert res.returncode == 0, res.stderr
    snap = state / f"tcc-snapshot-{bundle}.json"
    _inject(snap, sc)
    snap_bytes = snap.read_bytes()
    if sc["drop_scope"]:
        _delete_scope(tcc_db, bundle)
    before = _dump(tcc_db)
    log.write_text("")

    res = run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env, stubs=False, stdin="", timeout=30)

    assert res.returncode != 0, (sc, res.stdout, res.stderr)
    assert _dump(tcc_db) == before, (sc, res.stderr)
    assert snap.read_bytes() == snap_bytes
    assert not (state / f"tcc-snapshot-{bundle}.restored.json").exists()
    if sc["fault"] == "bad_cell":
        sql = log.read_text()
        assert "BEGIN" not in sql and "INSERT" not in sql and "DELETE" not in sql, sql
        assert "refusing" in res.stderr, res.stderr


def test_not_null_violation_after_delete_rolls_back(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    bundle = "dev.zcode.app"
    svc = DECLARED_SERVICES[0]
    row = dict.fromkeys(ACCESS_COLUMNS)
    row.update(
        service=svc, client=bundle, client_type=0, auth_value=2, auth_reason=3,
        auth_version=1, indirect_object_identifier="UNUSED", last_modified=5,
    )
    tcc_db.reset([row])
    state = tmp_path / "state"
    tooldir = tmp_path / "tools"
    tooldir.mkdir()
    log = tmp_path / "sql.log"
    log.write_text("")
    env = _env(tcc_db, state, bundle, tooldir, log)
    assert run_bash(repo, 'tcc_snapshot "$1" "$2"', bundle, svc, libs=LIBS, env=env, stubs=False, stdin="", timeout=30).returncode == 0
    snap = state / f"tcc-snapshot-{bundle}.json"
    data = json.loads(snap.read_text())
    data["rows"][0][data["columns"].index("auth_value")] = "n:"
    snap.write_text(json.dumps(data))
    before = _dump(tcc_db)
    res = run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env, stubs=False, stdin="", timeout=30)
    assert res.returncode != 0
    assert _dump(tcc_db) == before
    assert snap.exists()
