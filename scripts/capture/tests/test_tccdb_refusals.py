"""Property 34: Unsafe bundle IDs and services are refused.
**Validates: Requirements 13.2, 17.4, 17.5**
For any bundle ID that is empty, is `All` in any letter case, or is not known,
and for any service that is empty or not declared, tcc_snapshot and tcc_restore
print the rejected value, exit non-zero, leave the database byte-identical, make
no sqlite3 call, and create no snapshot file. Only temporary databases are used.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

from hypothesis import given, strategies as st

from conftest import (
    DECLARED_SERVICES,
    UNDECLARED_SERVICES,
    Repo,
    TccDb,
    access_tables,
    bundle_ids,
    run_bash,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb")
KNOWN = "dev.zcode.app"


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _listing(state: Path) -> list[str]:
    return sorted(p.name for p in state.iterdir()) if state.exists() else []


def _env(db: TccDb, state: Path) -> dict[str, str]:
    return {
        **db.env,
        "CAPTURE_STATE_DIR": str(state),
        "TCC_KNOWN_BUNDLES": KNOWN,
        "TCC_DECLARED_SERVICES": "\n".join(DECLARED_SERVICES),
        "TCC_RUN_TS": "20261120T153040Z",
    }


def _case_variants_of_all():
    return st.lists(st.booleans(), min_size=3, max_size=3).map(
        lambda flags: "".join(c.upper() if f else c for c, f in zip("all", flags))
    )


# Empty, "All" in any case, or well-formed but unknown.
bad_bundles = st.one_of(
    st.just(""),
    _case_variants_of_all(),
    bundle_ids.filter(lambda b: b != KNOWN),
)

bad_services = st.one_of(
    st.just(""),
    st.sampled_from(UNDECLARED_SERVICES),
    st.text(alphabet="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", min_size=1, max_size=20)
    .map(lambda s: "kTCCService" + s)
    .filter(lambda s: s not in DECLARED_SERVICES),
)


def _assert_refused(repo: Repo, db: TccDb, state: Path, before: str, listing: list[str], res, shown: str) -> None:
    assert res.returncode != 0, (res.stdout, res.stderr)
    if shown:
        assert shown in res.stderr + res.stdout, res.stderr
    else:
        assert "refusing" in res.stderr, res.stderr
    assert _sha(db.path) == before
    assert repo.calls("sqlite3") == []
    assert _listing(state) == listing


def _snapshot(repo: Repo, db: TccDb, state: Path, bundle: str, services: list[str]):
    return run_bash(
        repo,
        'b="$1"; shift; tcc_snapshot "$b" "$@"',
        bundle,
        *services,
        libs=LIBS,
        env=_env(db, state),
    )


def _restore(repo: Repo, db: TccDb, state: Path, bundle: str, parsed: str | None = None):
    """tcc_restore with the snapshot parse canned through the osascript stub."""
    env = _env(db, state)
    if parsed is not None:
        env["STUB_OSASCRIPT_OUT"] = parsed
    return run_bash(repo, 'tcc_restore "$1"', bundle, libs=LIBS, env=env)


# Feature: permission-capture-framework, Property 34: Unsafe bundle IDs and services are refused
@given(bundle=bad_bundles, rows_seed=st.data())
def test_snapshot_refuses_unsafe_bundle(repo: Repo, tcc_db: TccDb, tmp_path: Path, bundle, rows_seed) -> None:
    tcc_db.reset(rows_seed.draw(access_tables(KNOWN)))
    state = tmp_path / "state-snap-bundle"
    before = _sha(tcc_db.path)
    repo.call_log.write_text("")
    res = _snapshot(repo, tcc_db, state, bundle, [DECLARED_SERVICES[0]])
    _assert_refused(repo, tcc_db, state, before, [], res, bundle)


@given(bundle=bad_bundles, rows_seed=st.data())
def test_restore_refuses_unsafe_bundle(repo: Repo, tcc_db: TccDb, tmp_path: Path, bundle, rows_seed) -> None:
    tcc_db.reset(rows_seed.draw(access_tables(KNOWN)))
    state = tmp_path / "state-restore-bundle"
    state.mkdir(exist_ok=True)
    before = _sha(tcc_db.path)
    repo.call_log.write_text("")
    res = _restore(repo, tcc_db, state, bundle)
    _assert_refused(repo, tcc_db, state, before, [], res, bundle)


@given(bad=bad_services, good=st.lists(st.sampled_from(DECLARED_SERVICES), max_size=2, unique=True), pos=st.integers(0, 2))
def test_snapshot_refuses_unsafe_service(repo: Repo, tcc_db: TccDb, tmp_path: Path, bad, good, pos) -> None:
    services = list(good)
    services.insert(min(pos, len(services)), bad)
    state = tmp_path / "state-snap-service"
    before = _sha(tcc_db.path)
    repo.call_log.write_text("")
    res = _snapshot(repo, tcc_db, state, KNOWN, services)
    _assert_refused(repo, tcc_db, state, before, [], res, bad)


@given(bad=bad_services)
def test_restore_refuses_unsafe_service_in_snapshot(repo: Repo, tcc_db: TccDb, tmp_path: Path, bad) -> None:
    state = tmp_path / "state-restore-service"
    state.mkdir(exist_ok=True)
    snap = state / f"tcc-snapshot-{KNOWN}.json"
    snap.write_text("{}\n")  # content is replaced by the canned parse below
    parsed = f"bundle\t{KNOWN}\nservice\t{DECLARED_SERVICES[0]}\nservice\t{bad}\ncolumn\tservice\ncolumn\tclient"
    before = _sha(tcc_db.path)
    snap_before = snap.read_bytes()
    repo.call_log.write_text("")
    res = _restore(repo, tcc_db, state, KNOWN, parsed)
    assert res.returncode != 0, (res.stdout, res.stderr)
    if bad:
        assert bad in res.stderr
    else:
        assert "refusing service" in res.stderr
    assert _sha(tcc_db.path) == before
    assert repo.calls("sqlite3") == []
    assert _listing(state) == [snap.name]
    assert snap.read_bytes() == snap_before
