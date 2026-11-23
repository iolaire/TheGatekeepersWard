"""Property 37: Verification detects every difference.
**Validates: Requirements 16.8, 16.12**
Takes a snapshot of a generated temporary database, then either leaves the scope
rows alone or changes them (a changed cell in any column, a missing row, an extra
row). tcc_verify must succeed with no output when the scope rows equal the
snapshot, and otherwise return non-zero and name the `service` of each
differing row. Only temporary databases selected through CAPTURE_TCC_DB_TEST are
opened. Runs with stubs=False so the real osascript parses the snapshot.
"""
from __future__ import annotations

import os
import shutil
import sqlite3
from pathlib import Path

from hypothesis import assume, given, strategies as st, settings
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
_COLS = ",".join(ACCESS_COLUMNS)
_PK = ("service", "client", "client_type", "indirect_object_identifier")
_COLUMNS_TO_CHANGE = tuple(c for c in ACCESS_COLUMNS if c not in _PK)
_IDX = {c: i for i, c in enumerate(ACCESS_COLUMNS)}


def _env(db: TccDb, state: Path, bundle: str) -> dict[str, str]:
    return {
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": bundle,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _scope(db: TccDb, bundle: str, services) -> list[tuple]:
    """Scope rows read independently of the code under test, each cell tagged
    with its Python type so 1 vs True and bytes vs str differ."""
    conn = sqlite3.connect(f"file:{db.path}?mode=ro", uri=True)
    try:
        marks = ",".join("?" for _ in services)
        cur = conn.execute(
            f"SELECT {_COLS} FROM access WHERE client = ? AND service IN ({marks}) "
            "ORDER BY service, client_type, indirect_object_identifier",
            [bundle, *services],
        )
        return [tuple((type(c).__name__, c) for c in r) for r in cur.fetchall()]
    finally:
        conn.close()


def _differing_services(before: list[tuple], after: list[tuple]) -> set[str]:
    """Services of rows in the symmetric difference of the two row sets."""
    b, a = set(before), set(after)
    return {r[_IDX["service"]][1] for r in b ^ a}


def _apply(db: TccDb, bundle: str, services, op) -> None:
    conn = sqlite3.connect(str(db.path))
    try:
        rowids = [
            r[0]
            for r in conn.execute(
                f"SELECT rowid FROM access WHERE client = ? AND service IN ({','.join('?' for _ in services)}) "
                "ORDER BY rowid",
                [bundle, *services],
            )
        ]
        kind = op[0]
        if kind == "change":
            _, idx, col, value = op
            conn.execute(
                f"UPDATE access SET {col} = ? WHERE rowid = ?", [value, rowids[idx % len(rowids)]]
            )
        elif kind == "delete":
            conn.execute("DELETE FROM access WHERE rowid = ?", [rowids[op[1] % len(rowids)]])
        elif kind == "extra":
            _, service, ident = op
            conn.execute(
                f"INSERT OR REPLACE INTO access ({_COLS}) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                [service, bundle, 1, 2, 3, 1, b"\x01", None, None, ident, None, 0, 5],
            )
        conn.commit()
    finally:
        conn.close()


_change_values = {
    "auth_value": st.integers(-5, 9),
    "auth_reason": st.integers(-5, 9),
    "auth_version": st.integers(-5, 9),
    "csreq": st.one_of(st.none(), st.just(b""), st.binary(min_size=1, max_size=40)),
    "policy_id": st.one_of(st.none(), st.integers(-(2**63), 2**63 - 1)),
    "indirect_object_identifier_type": st.one_of(st.none(), st.integers(0, 9)),
    "indirect_object_code_identity": st.one_of(st.none(), st.binary(max_size=40)),
    "flags": st.one_of(st.none(), st.integers(0, 9)),
    "last_modified": st.integers(0, 2**40),
}

ops_strategy = st.one_of(
    st.none(),
    st.tuples(st.just("delete"), st.integers(0, 20)),
    st.tuples(st.just("change"), st.integers(0, 20), st.sampled_from(_COLUMNS_TO_CHANGE)).flatmap(
        lambda t: _change_values[t[2]].map(lambda v: (*t, v))
    ),
    st.tuples(
        st.just("extra"),
        st.sampled_from(DECLARED_SERVICES),
        st.sampled_from(["UNUSED", "com.other.app", "x'y", "new-ident"]),
    ),
)


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    rows = draw(access_tables(bundle))
    services = draw(st.lists(st.sampled_from(DECLARED_SERVICES), min_size=1, max_size=2, unique=True))
    return bundle, rows, services, draw(ops_strategy)


# Feature: permission-capture-framework, Property 37: Verification detects every difference
@settings(max_examples=E2E_EXAMPLES)
@given(scenario=scenarios())
def test_verify_detects_every_difference(repo: Repo, tcc_db: TccDb, tmp_path: Path, scenario) -> None:
    bundle, rows, services, op = scenario
    tcc_db.reset(rows)
    state = tmp_path / "state"
    shutil.rmtree(state, ignore_errors=True)
    env = _env(tcc_db, state, bundle)

    res = run_bash(repo, 'b="$1"; shift; tcc_snapshot "$b" "$@"', bundle, *services,
                   libs=LIBS, env=env, stubs=False)
    assert res.returncode == 0, res.stderr
    before = _scope(tcc_db, bundle, services)

    if op is not None and op[0] != "extra" and not before:
        op = None  # nothing to delete or change
    if op is not None:
        _apply(tcc_db, bundle, services, op)
    after = _scope(tcc_db, bundle, services)
    expected = _differing_services(before, after)
    if op is not None:
        assume(expected)  # skip no-op changes (same value written back)

    res = run_bash(repo, 'tcc_verify "$1"', bundle, libs=LIBS, env=env, stubs=False)
    if not expected:
        assert res.returncode == 0, (res.stdout, res.stderr)
        assert res.stdout.strip() == ""
    else:
        assert res.returncode != 0, (op, res.stdout, res.stderr)
        named = {ln for ln in res.stdout.splitlines() if ln}
        assert named == expected, (op, res.stdout, res.stderr)
