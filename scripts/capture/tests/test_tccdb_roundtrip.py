"""Property 30: Restore round trip.
**Validates: Requirements 16.4, 16.6, 16.8**
Takes a snapshot of a generated temporary database, applies changes to the scope
rows (delete as `tccutil reset` does, change cells, insert rows), runs
tcc_restore, and checks with Python's sqlite3 that the scope rows equal the
snapshot rows in every column (including csreq) and that tcc_verify succeeds.
Only temporary databases selected through CAPTURE_TCC_DB_TEST are opened.
"""
from __future__ import annotations

import os
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
    access_tables,
    bundle_ids,
    run_bash,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")
_PK = ("service", "client", "client_type", "indirect_object_identifier")
_MUTABLE = ("auth_value", "auth_reason", "auth_version", "csreq", "policy_id", "flags", "last_modified")
_COLS = ",".join(ACCESS_COLUMNS)


def _env(repo: Repo, db: TccDb, state: Path, bundle: str) -> dict[str, str]:
    """Environment for the lib calls. tcc_restore and tcc_verify parse the
    snapshot with JXA, which the canned osascript stub would answer with an
    empty string, so a real osascript goes first on PATH. The sqlite3 stub (it
    refuses any real TCC database path) stays ahead of /usr/bin."""
    real = state.parent / "real-bin"
    real.mkdir(exist_ok=True)
    link = real / "osascript"
    if not link.exists():
        link.symlink_to("/usr/bin/osascript")
    return {
        "PATH": os.pathsep.join([str(real), str(repo.stubs_dir), os.environ.get("PATH", "")]),
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _scope(db: TccDb, bundle: str, services) -> list[tuple]:
    """Scope rows read independently of the code under test, sorted by primary key."""
    conn = sqlite3.connect(f"file:{db.path}?mode=ro", uri=True)
    try:
        marks = ",".join("?" for _ in services)
        cur = conn.execute(
            f"SELECT {_COLS} FROM access WHERE client = ? AND service IN ({marks}) "
            "ORDER BY service, client_type, indirect_object_identifier",
            [bundle, *services],
        )
        return [tuple(r) for r in cur.fetchall()]
    finally:
        conn.close()


def _strict(rows: list[tuple]) -> list[tuple]:
    """Tag each cell with its Python type so 1 vs True and bytes vs str differ."""
    return [tuple((type(c).__name__, c) for c in r) for r in rows]


def _mutate(db: TccDb, bundle: str, services, ops) -> None:
    conn = sqlite3.connect(str(db.path))
    try:
        for op in ops:
            kind = op[0]
            if kind == "delete_all":
                marks = ",".join("?" for _ in services)
                conn.execute(
                    f"DELETE FROM access WHERE client = ? AND service IN ({marks})",
                    [bundle, *services],
                )
            elif kind == "delete_one":
                cur = conn.execute(
                    "SELECT rowid FROM access WHERE client = ? ORDER BY rowid", [bundle]
                ).fetchall()
                if cur:
                    conn.execute("DELETE FROM access WHERE rowid = ?", [cur[op[1] % len(cur)][0]])
            elif kind == "update":
                _, idx, col, value = op
                cur = conn.execute(
                    "SELECT rowid FROM access WHERE client = ? ORDER BY rowid", [bundle]
                ).fetchall()
                if cur:
                    conn.execute(
                        f"UPDATE access SET {col} = ? WHERE rowid = ?",
                        [value, cur[idx % len(cur)][0]],
                    )
            elif kind == "insert":
                _, service, client_type, ident, auth = op
                conn.execute(
                    f"INSERT OR REPLACE INTO access ({_COLS}) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    [service, bundle, client_type, auth, 2, 1, b"\x00\xff", None, None, ident, None, 0, 7],
                )
        conn.commit()
    finally:
        conn.close()


_update_values = {
    "auth_value": st.integers(0, 3),
    "auth_reason": st.integers(0, 9),
    "auth_version": st.integers(0, 9),
    "csreq": st.one_of(st.none(), st.binary(max_size=40)),
    "policy_id": st.one_of(st.none(), st.integers(-(2**63), 2**63 - 1)),
    "flags": st.one_of(st.none(), st.integers(0, 5)),
    "last_modified": st.integers(0, 2**40),
}

ops_strategy = st.lists(
    st.one_of(
        st.just(("delete_all",)),
        st.tuples(st.just("delete_one"), st.integers(0, 20)),
        st.tuples(st.just("update"), st.integers(0, 20), st.sampled_from(_MUTABLE)).flatmap(
            lambda t: _update_values[t[2]].map(lambda v: (*t, v))
        ),
        st.tuples(
            st.just("insert"),
            st.sampled_from(DECLARED_SERVICES),
            st.integers(0, 1),
            st.sampled_from(["UNUSED", "com.other.app", "x'y"]),
            st.integers(0, 3),
        ),
    ),
    min_size=0,
    max_size=6,
)


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    services = draw(
        st.lists(st.sampled_from(DECLARED_SERVICES), min_size=1, max_size=2, unique=True)
    )
    return bundle, rows, services, draw(ops_strategy)


# Feature: permission-capture-framework, Property 30: Restore round trip
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_restore_round_trip(repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario) -> None:
    bundle, rows, services, ops = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)
    env = _env(repo, tcc_db, state, bundle)

    res = run_bash(repo, 'b="$1"; shift; tcc_snapshot "$b" "$@"', bundle, *services, libs=LIBS, env=env)
    assert res.returncode == 0, res.stderr
    before = _strict(_scope(tcc_db, bundle, services))

    _mutate(tcc_db, bundle, services, ops)

    res = run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env)
    assert res.returncode == 0, (ops, res.stdout, res.stderr)
    assert _strict(_scope(tcc_db, bundle, services)) == before

    res = run_bash(repo, 'tcc_verify "$1"', bundle, libs=LIBS, env=env)
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert res.stdout.strip() == ""


def test_restore_after_tccutil_style_reset(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    bundle = "dev.zcode.app"
    svc = DECLARED_SERVICES[0]
    row = dict.fromkeys(ACCESS_COLUMNS)
    row.update(
        service=svc, client=bundle, client_type=0, auth_value=2, auth_reason=3,
        auth_version=1, csreq=b"\x00\x01\xfe", indirect_object_identifier="UNUSED",
        last_modified=99,
    )
    tcc_db.reset([row])
    state = tmp_path / "state"
    env = _env(repo, tcc_db, state, bundle)
    assert run_bash(repo, 'tcc_snapshot "$1" "$2"', bundle, svc, libs=LIBS, env=env).returncode == 0
    before = _strict(_scope(tcc_db, bundle, [svc]))
    _mutate(tcc_db, bundle, [svc], [("delete_all",)])
    assert _scope(tcc_db, bundle, [svc]) == []
    assert run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env).returncode == 0
    assert _strict(_scope(tcc_db, bundle, [svc])) == before
