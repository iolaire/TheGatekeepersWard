"""Property 31: Restore is idempotent.
**Validates: Requirements 16.10**
Takes a snapshot of a temporary access database, perturbs the scope rows, runs
lib/tccdb.sh tcc_restore twice with the same snapshot, and compares every row of
the whole database after the first and second restore. Rows are read by Python's
sqlite3, independent of the code under test. The user database is never opened.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from hypothesis import given, strategies as st, settings
from conftest import E2E_EXAMPLES

from conftest import (
    DECLARED_SERVICES,
    Repo,
    TccDb,
    access_tables,
    bundle_ids,
    run_bash,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")


def _env(db: TccDb, state: Path, bundle: str) -> dict[str, str]:
    return {
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


# Real osascript and sqlite3: tcc_restore parses the snapshot through osascript.
def _call(repo: Repo, db: TccDb, state: Path, bundle: str, snippet: str, *args: str):
    return run_bash(repo, snippet, bundle, *args, libs=LIBS, env=_env(db, state, bundle), stubs=False)


def _perturb(db: TccDb, bundle: str) -> None:
    """Change the scope after the snapshot: delete one row, alter another, add one."""
    import sqlite3

    conn = sqlite3.connect(str(db.path))
    try:
        conn.execute(
            "DELETE FROM access WHERE rowid = (SELECT MIN(rowid) FROM access WHERE client = ?)",
            (bundle,),
        )
        conn.execute("UPDATE access SET auth_value = 7 WHERE client = ?", (bundle,))
        conn.execute(
            "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) "
            "VALUES (?, ?, 0, 2, 0, 1)",
            (DECLARED_SERVICES[0], bundle),
        )
        conn.commit()
    finally:
        conn.close()


def _norm(rows: list[tuple]) -> list[tuple]:
    """Order-independent, type-aware form of the whole table."""
    return sorted([(type(c).__name__, repr(c)) for c in r] for r in rows)


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    services = draw(st.lists(st.sampled_from(DECLARED_SERVICES), min_size=1, max_size=2, unique=True))
    perturb = draw(st.booleans())
    return bundle, rows, services, perturb


# Feature: permission-capture-framework, Property 31: Restore is idempotent
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_restore_is_idempotent(repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario) -> None:
    bundle, rows, services, perturb = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)

    snap = _call(repo, tcc_db, state, bundle, 'b="$1"; shift; tcc_snapshot "$b" "$@"', *services)
    assert snap.returncode == 0, snap.stderr

    if perturb:
        _perturb(tcc_db, bundle)

    first = _call(repo, tcc_db, state, bundle, 'tcc_restore "$1"')
    assert first.returncode == 0, (first.stdout, first.stderr)
    after_first = tcc_db.read()

    second = _call(repo, tcc_db, state, bundle, 'tcc_restore "$1"')
    assert second.returncode == 0, (second.stdout, second.stderr)
    after_second = tcc_db.read()

    assert _norm(after_second) == _norm(after_first)

    verify = _call(repo, tcc_db, state, bundle, 'tcc_verify "$1"')
    assert verify.returncode == 0, (verify.stdout, verify.stderr)
    assert verify.stdout.strip() == ""
