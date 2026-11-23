"""Property 32: Rows created after the snapshot are removed.
**Validates: Requirements 16.5, 16.6, 17.9**
Takes a snapshot of a generated temporary database, inserts extra scope rows
(declared services with or without a row in the snapshot, any client_type and
indirect_object_identifier), runs tcc_restore, and checks that none of the
extra rows remain. With a snapshot of zero rows, no scope row may remain.
The user database is never opened.
"""
from __future__ import annotations

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
    scope_rows,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")
_S, _C, _T, _I = (ACCESS_COLUMNS.index(c) for c in ("service", "client", "client_type", "indirect_object_identifier"))


def _env(db: TccDb, state: Path, bundle: str) -> dict[str, str]:
    return {
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _snapshot(repo: Repo, db: TccDb, state: Path, bundle: str):
    return run_bash(
        repo, 'b="$1"; shift; tcc_snapshot "$b" "$@"', bundle, *DECLARED_SERVICES,
        libs=LIBS, env=_env(db, state, bundle), stubs=False,
    )


def _restore(repo: Repo, db: TccDb, state: Path, bundle: str):
    return run_bash(
        repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=_env(db, state, bundle), stubs=False,
    )


def _key(row: tuple) -> tuple:
    return (row[_S], row[_C], row[_T], row[_I])


def _insert(db: TccDb, extras: list[dict]) -> None:
    conn = sqlite3.connect(str(db.path))
    try:
        marks = ",".join("?" for _ in ACCESS_COLUMNS)
        for row in extras:
            conn.execute(
                f"INSERT OR IGNORE INTO access ({','.join(ACCESS_COLUMNS)}) VALUES ({marks})",
                [row[c] for c in ACCESS_COLUMNS],
            )
        conn.commit()
    finally:
        conn.close()


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    if draw(st.booleans()):  # make an empty-scope snapshot common
        rows = [r for r in rows if not (r["client"] == bundle and r["service"] in DECLARED_SERVICES)]
    extras = [
        draw(access_row(bundle, draw(st.sampled_from(DECLARED_SERVICES))))
        for _ in range(draw(st.integers(1, 5)))
    ]
    return bundle, rows, extras


# Feature: permission-capture-framework, Property 32: Rows created after the snapshot are removed
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_created_rows_are_removed(repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario) -> None:
    bundle, rows, extras = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)

    res = _snapshot(repo, tcc_db, state, bundle)
    assert res.returncode == 0, res.stderr
    before = tcc_db.read()
    before_scope = scope_rows(before, bundle, DECLARED_SERVICES)
    before_keys = {_key(r) for r in before}

    _insert(tcc_db, extras)
    created = {_key(tuple(e[c] for c in ACCESS_COLUMNS)) for e in extras} - before_keys
    after_insert = tcc_db.read()
    assert created <= {_key(r) for r in after_insert}

    res = _restore(repo, tcc_db, state, bundle)
    assert res.returncode == 0, res.stdout + res.stderr

    after = tcc_db.read()
    assert not (created & {_key(r) for r in after})
    after_scope = scope_rows(after, bundle, DECLARED_SERVICES)
    assert after_scope == before_scope
    if not before_scope:
        assert after_scope == []
    # Rows outside the scope are untouched.
    assert [r for r in after if r not in after_scope] == [r for r in before if r not in before_scope]


def test_empty_snapshot_removes_every_scope_row(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    bundle = "dev.zcode.app"
    tcc_db.reset([])
    state = tmp_path / "state"
    assert _snapshot(repo, tcc_db, state, bundle).returncode == 0
    extra = {
        "service": DECLARED_SERVICES[0], "client": bundle, "client_type": 0,
        "auth_value": 2, "auth_reason": 1, "auth_version": 1, "csreq": b"\x00\x01",
        "policy_id": None, "indirect_object_identifier_type": None,
        "indirect_object_identifier": "UNUSED", "indirect_object_code_identity": None,
        "flags": 0, "last_modified": 1,
    }
    _insert(tcc_db, [extra, {**extra, "service": DECLARED_SERVICES[1], "client_type": 1}])
    assert len(tcc_db.read()) == 2
    res = _restore(repo, tcc_db, state, bundle)
    assert res.returncode == 0, res.stdout + res.stderr
    assert tcc_db.read() == []
