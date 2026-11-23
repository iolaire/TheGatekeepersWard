"""Property 33: Restore never touches rows outside the scope.
**Validates: Requirements 15.6, 17.3**
Takes a snapshot of a generated temporary database, applies in-scope changes
(deletes, new rows, replaced rows), runs tcc_restore, and checks with Python's
sqlite3 that every row outside the scope (other bundle IDs, the client `All`,
and the same bundle ID in undeclared services) is identical to what it was
before the snapshot, and that the snapshot file never holds such a row. The
user database is never opened.
"""
from __future__ import annotations

import json
import shutil
import sqlite3
from pathlib import Path

from hypothesis import given, strategies as st, settings
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
S_I = ACCESS_COLUMNS.index("service")
C_I = ACCESS_COLUMNS.index("client")


def _env(db: TccDb, state: Path, bundle: str) -> dict[str, str]:
    return {
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _outside(rows: list[tuple], bundle: str) -> list[tuple]:
    return [r for r in rows if not (r[C_I] == bundle and r[S_I] in DECLARED_SERVICES)]


def _mutate_scope(db: TccDb, bundle: str, new_rows: list[dict], delete_first: bool) -> None:
    """Change only rows whose client is bundle and service is declared."""
    conn = sqlite3.connect(str(db.path))
    try:
        if delete_first:
            marks = ",".join("?" for _ in DECLARED_SERVICES)
            conn.execute(
                f"DELETE FROM access WHERE client = ? AND service IN ({marks})",
                [bundle, *DECLARED_SERVICES],
            )
        place = ",".join("?" for _ in ACCESS_COLUMNS)
        for row in new_rows:
            conn.execute(
                f"INSERT OR REPLACE INTO access ({','.join(ACCESS_COLUMNS)}) VALUES ({place})",
                [row[c] for c in ACCESS_COLUMNS],
            )
        conn.commit()
    finally:
        conn.close()


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    changes = [
        draw(access_row(bundle, draw(st.sampled_from(DECLARED_SERVICES))))
        for _ in range(draw(st.integers(0, 3)))
    ]
    return bundle, rows, changes, draw(st.booleans())


# Feature: permission-capture-framework, Property 33: Restore never touches rows outside the scope
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_restore_never_touches_rows_outside_scope(
    repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario
) -> None:
    bundle, rows, changes, delete_first = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)
    outside_before = _outside(tcc_db.read(), bundle)
    env = _env(tcc_db, state, bundle)

    snap = run_bash(
        repo, 'b="$1"; shift; tcc_snapshot "$b" "$@"', bundle, *DECLARED_SERVICES,
        libs=LIBS, env=env,
    )
    assert snap.returncode == 0, snap.stderr

    # The snapshot file holds only scope rows.
    doc = json.loads((state / f"tcc-snapshot-{bundle}.json").read_text(encoding="utf-8"))
    for cells in doc["rows"]:
        assert bytes.fromhex(cells[C_I][2:]).decode("utf-8") == bundle
        assert bytes.fromhex(cells[S_I][2:]).decode("utf-8") in DECLARED_SERVICES

    _mutate_scope(tcc_db, bundle, changes, delete_first)
    assert _outside(tcc_db.read(), bundle) == outside_before  # mutation stayed in scope

    # stubs=False: tcc_restore parses the snapshot with the real osascript (JXA),
    # which the canned osascript stub would answer with an empty string.
    res = run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env, stubs=False)
    assert res.returncode == 0, res.stderr

    assert _outside(tcc_db.read(), bundle) == outside_before


def test_restore_keeps_all_client_and_undeclared_rows(
    repo: Repo, tcc_db: TccDb, tmp_path: Path
) -> None:
    bundle = "dev.zcode.app"
    base = {
        "client_type": 0, "auth_value": 2, "auth_reason": 4, "auth_version": 1,
        "csreq": b"", "policy_id": None, "indirect_object_identifier_type": None,
        "indirect_object_identifier": "UNUSED", "indirect_object_code_identity": None,
        "flags": 0, "last_modified": 7,
    }
    rows = [
        {**base, "service": DECLARED_SERVICES[0], "client": bundle},
        {**base, "service": DECLARED_SERVICES[0], "client": "All"},
        {**base, "service": "kTCCServiceCamera", "client": bundle},
        {**base, "service": DECLARED_SERVICES[0], "client": "dev.other.app"},
    ]
    tcc_db.reset(rows)
    state = tmp_path / "state"
    outside_before = _outside(tcc_db.read(), bundle)
    assert len(outside_before) == 3
    env = _env(tcc_db, state, bundle)
    assert run_bash(
        repo, 'tcc_snapshot "$1" "$2"', bundle, DECLARED_SERVICES[0], libs=LIBS, env=env
    ).returncode == 0
    _mutate_scope(tcc_db, bundle, [], True)
    res = run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env, stubs=False)
    assert res.returncode == 0, res.stderr
    assert _outside(tcc_db.read(), bundle) == outside_before
    assert len([r for r in tcc_db.read() if r[C_I] == bundle and r[S_I] == DECLARED_SERVICES[0]]) == 1
