"""Property 29: Snapshot is exact and scoped.
**Validates: Requirements 15.2, 15.5, 15.6, 17.3, 17.6**
Drives lib/tccdb.sh tcc_snapshot against a temporary access database selected
through CAPTURE_TCC_DB_TEST. The snapshot file is decoded in Python and compared
with the scope rows read directly by Python's sqlite3 (read-only). The user
database is never opened.
"""
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from hypothesis import given, strategies as st, settings
from conftest import E2E_EXAMPLES

from conftest import (
    ACCESS_COLUMNS,
    DECLARED_SERVICES,
    Repo,
    TccDb,
    access_tables,
    bundle_ids,
    run_bash,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")


def _scope_rows_direct(db: TccDb, bundle: str, services: list[str]) -> list[tuple]:
    """Scope rows ordered by service, rowid, read independently of the code under test."""
    import sqlite3

    conn = sqlite3.connect(f"file:{db.path}?mode=ro", uri=True)
    try:
        marks = ",".join("?" for _ in services)
        cur = conn.execute(
            f"SELECT {','.join(ACCESS_COLUMNS)} FROM access "
            f"WHERE client = ? AND service IN ({marks}) ORDER BY service, rowid",
            [bundle, *services],
        )
        return [tuple(r) for r in cur.fetchall()]
    finally:
        conn.close()


def _decode_cell(cell: str):
    tag, _, body = cell.partition(":")
    if tag == "i":
        return int(body)
    if tag == "t":
        return bytes.fromhex(body).decode("utf-8")
    if tag == "b":
        return bytes.fromhex(body)
    assert tag == "n" and body == "", cell
    return None


def _same(a, b) -> bool:
    """Equal in value and type (so 1 != True, and bytes != str)."""
    return type(a) is type(b) and a == b


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _snapshot(repo: Repo, db: TccDb, state: Path, bundle: str, services: list[str]):
    return run_bash(
        repo,
        'b="$1"; shift; tcc_snapshot "$b" "$@"',
        bundle,
        *services,
        libs=LIBS,
        env={
            **db.env,
            "CAPTURE_STATE_DIR": str(state),
            "TCC_KNOWN_BUNDLES": bundle,
            "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
            "TCC_RUN_TS": "20261120T153040Z",
        },
    )


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    services = draw(st.lists(st.sampled_from(DECLARED_SERVICES), min_size=1, max_size=2, unique=True))
    return bundle, rows, services


# Feature: permission-capture-framework, Property 29: Snapshot is exact and scoped
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_snapshot_is_exact_and_scoped(repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario) -> None:
    bundle, rows, services = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)
    before = _sha(tcc_db.path)

    res = _snapshot(repo, tcc_db, state, bundle, services)
    assert res.returncode == 0, res.stderr
    assert _sha(tcc_db.path) == before  # database byte-identical

    snap_file = state / f"tcc-snapshot-{bundle}.json"
    assert snap_file.is_file()
    assert [p.name for p in state.iterdir()] == [snap_file.name]  # no temp leftovers
    snap = json.loads(snap_file.read_text(encoding="utf-8"))

    assert snap["bundle_id"] == bundle
    assert snap["services"] == services
    assert snap["columns"] == list(ACCESS_COLUMNS)

    expected = _scope_rows_direct(tcc_db, bundle, services)
    decoded = [tuple(_decode_cell(c) for c in row) for row in snap["rows"]]
    assert len(decoded) == len(expected)
    for got, want in zip(decoded, expected):
        assert len(got) == len(want)
        assert all(_same(g, w) for g, w in zip(got, want)), (got, want)

    present = {r[ACCESS_COLUMNS.index("service")] for r in expected}
    assert snap["services_without_row"] == [s for s in services if s not in present]

    # No row outside the scope appears.
    c_i = ACCESS_COLUMNS.index("client")
    s_i = ACCESS_COLUMNS.index("service")
    assert all(r[c_i] == bundle and r[s_i] in services for r in decoded)
    if not expected:
        assert snap["rows"] == []
        assert snap["services_without_row"] == services


def test_snapshot_empty_scope_lists_all_services(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    tcc_db.reset([])
    state = tmp_path / "state"
    before = _sha(tcc_db.path)
    res = _snapshot(repo, tcc_db, state, "dev.zcode.app", list(DECLARED_SERVICES))
    assert res.returncode == 0, res.stderr
    snap = json.loads((state / "tcc-snapshot-dev.zcode.app.json").read_text())
    assert snap["rows"] == []
    assert snap["services_without_row"] == list(DECLARED_SERVICES)
    assert _sha(tcc_db.path) == before
