"""Property 40: One snapshot per run, taken before the first reset.
**Validates: Requirements 15.1, 15.4, 16.11**
Simulates a run of N sessions on one bundle ID with the same calls the runner
makes per session (tcc_ensure_snapshot, then reset_run --service), in one bash
process per run. The tcc_snapshot function is wrapped to append a `snapshot`
line to the stub call log, so snapshots and `tccutil` calls share one ordered
log. Only temporary databases selected through CAPTURE_TCC_DB_TEST are opened.
tccutil, sqlite3 and pkill are the repo stubs reached through wrapper scripts;
osascript is the real one (it parses snapshots), so stubs=False is used.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sqlite3
import stat
from pathlib import Path

from hypothesis import given, strategies as st, settings
from conftest import E2E_EXAMPLES

from conftest import (
    ACCESS_COLUMNS,
    Repo,
    TccDb,
    access_tables,
    bundle_ids,
    run_bash,
    scope_rows,
)

LIBS = ("common", "defaults", "validate", "profile", "reset", "tccdb", "restore")
PROFILE_SERVICES = ("SystemPolicyDesktopFolder", "SystemPolicyRemovableVolumes")
# The same services as the access table stores them.
DB_SERVICES = tuple("kTCCService" + s for s in PROFILE_SERVICES)

_RUN = r'''
eval "_orig_$(declare -f tcc_snapshot)"
tcc_snapshot() { printf 'snapshot\t%s\n' "$1" >>"$STUB_CALL_LOG"; _orig_tcc_snapshot "$@"; }
ts="$1"; shift
for svc in "$@"; do
  tcc_ensure_snapshot zcode "$ts" || exit 7
  reset_run zcode --service "$svc" || exit 8
done
'''
_RESTORE = r'''restore_all'''


class World:
    """A temp state dir, profile dir, tool wrappers and env for one example."""

    def __init__(self, repo: Repo, db: TccDb, base: Path, bundle: str) -> None:
        self.repo, self.db, self.bundle = repo, db, bundle
        self.state = base / "state"
        shutil.rmtree(self.state, ignore_errors=True)
        pdir = base / "profiles"
        pdir.mkdir(exist_ok=True)
        text = (repo.profiles_dir / "zcode.profile").read_text()
        text = re.sub(r"(?m)^bundle_id\s*=.*$", f"bundle_id      = {bundle}", text)
        (pdir / "zcode.profile").write_text(text)
        tools = base / "tools"
        tools.mkdir(exist_ok=True)
        for name in ("tccutil", "sqlite3", "pkill"):
            w = tools / name
            w.write_text(f'#!/bin/bash\nexec "{repo.stubs_dir}/{name}" "$@"\n')
            w.chmod(w.stat().st_mode | stat.S_IXUSR)
        self.env = {
            "PATH": os.pathsep.join([str(tools), "/usr/bin", "/bin", "/usr/sbin", "/sbin"]),
            "STUB_CALL_LOG": str(repo.call_log),
            "CAPTURE_PROFILES_DIR": str(pdir),
            "CAPTURE_STATE_DIR": str(self.state),
            "CAPTURE_DRY_RUN": "0",
            "CAPTURE_NO_RESTORE": "0",
            **db.env,
        }
        self.n = 0

    @property
    def snap(self) -> Path:
        return self.state / f"tcc-snapshot-{self.bundle}.json"

    @property
    def restored(self) -> Path:
        return self.state / f"tcc-snapshot-{self.bundle}.restored.json"

    def clear_log(self) -> None:
        self.repo.call_log.write_text("")

    def run(self, snippet: str, *args: str):
        return run_bash(
            self.repo, snippet, *args, libs=LIBS, env=self.env, stubs=False, stdin="", timeout=60
        )

    def session_run(self, services: list[str]):
        self.n += 1
        return self.run(_RUN, f"20261120T15304{self.n}Z", *services)

    def scope(self) -> list[tuple]:
        return scope_rows(self.db.read(), self.bundle, DB_SERVICES)

    def delete_scope(self) -> None:
        conn = sqlite3.connect(str(self.db.path))
        try:
            marks = ",".join("?" for _ in DB_SERVICES)
            conn.execute(
                f"DELETE FROM access WHERE client = ? AND service IN ({marks})",
                [self.bundle, *DB_SERVICES],
            )
            conn.commit()
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


def _snap_rows(path: Path) -> list[tuple]:
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["columns"] == list(ACCESS_COLUMNS)
    return sorted((tuple(_decode_cell(c) for c in r) for r in data["rows"]), key=repr)


def _order(world: World) -> tuple[list[int], list[int], list[int]]:
    """Indexes in the call log of snapshots, tccutil resets and all rows."""
    rows = world.repo.calls()
    snaps = [i for i, r in enumerate(rows) if r[0] == "snapshot"]
    resets = [i for i, r in enumerate(rows) if r[0] == "tccutil" and r[1:2] == ["reset"]]
    return snaps, resets, list(range(len(rows)))


@st.composite
def scenarios(draw):
    bundle = draw(bundle_ids)
    return {
        "bundle": bundle,
        "rows": draw(access_tables(bundle)),
        "rows_old": draw(access_tables(bundle)),
        "services": draw(st.lists(st.sampled_from(PROFILE_SERVICES), min_size=1, max_size=4)),
        "prior": draw(st.sampled_from(["none", "pending", "restored"])),
    }


# Feature: permission-capture-framework, Property 40: One snapshot per run, taken before the first reset
@settings(max_examples=E2E_EXAMPLES)
@given(sc=scenarios())
def test_one_snapshot_per_run_before_first_reset(repo: Repo, tcc_db: TccDb, tmp_path: Path, sc) -> None:
    bundle = sc["bundle"]
    w = World(repo, tcc_db, tmp_path, bundle)

    # Earlier run: leaves a pending snapshot, or a restored one, or nothing.
    pending_bytes = None
    if sc["prior"] != "none":
        tcc_db.reset(sc["rows_old"])
        res = w.session_run([sc["services"][0]])
        assert res.returncode == 0, res.stderr
        assert w.snap.is_file()
        if sc["prior"] == "restored":
            res = w.run(_RESTORE)
            assert res.returncode == 0, res.stdout + res.stderr
            assert w.restored.is_file() and not w.snap.exists()
        else:
            pending_bytes = w.snap.read_bytes()

    tcc_db.reset(sc["rows"])
    expected = sorted(w.scope(), key=repr)
    w.clear_log()
    res = w.session_run(sc["services"])
    assert res.returncode == 0, res.stdout + res.stderr

    snaps, resets, _ = _order(w)
    assert len(resets) == len(sc["services"])
    if pending_bytes is not None:
        # A pending snapshot is reused: no new snapshot, file untouched.
        assert snaps == []
        assert w.snap.read_bytes() == pending_bytes
    else:
        assert len(snaps) == 1, repo.calls()
        assert snaps[0] < resets[0]
        assert [r[1] for r in repo.calls("snapshot")] == [bundle]
        assert _snap_rows(w.snap) == expected
    assert w.snap.is_file()

    # Verified restore renames the file; the next run takes a fresh snapshot.
    snap_rows = _snap_rows(w.snap)
    w.delete_scope()
    res = w.run(_RESTORE)
    assert res.returncode == 0, res.stdout + res.stderr
    assert w.restored.is_file() and not w.snap.exists()
    assert sorted(w.scope(), key=repr) == snap_rows

    before = sorted(w.scope(), key=repr)
    w.clear_log()
    res = w.session_run(sc["services"][:1])
    assert res.returncode == 0, res.stdout + res.stderr
    snaps, resets, _ = _order(w)
    assert len(snaps) == 1 and len(resets) == 1 and snaps[0] < resets[0]
    assert w.snap.is_file()
    assert _snap_rows(w.snap) == before


def test_two_sessions_one_snapshot_example(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> None:
    w = World(repo, tcc_db, tmp_path, "dev.zcode.app")
    tcc_db.reset([])
    res = w.session_run(list(PROFILE_SERVICES))
    assert res.returncode == 0, res.stdout + res.stderr
    snaps, resets, _ = _order(w)
    assert len(snaps) == 1 and len(resets) == 2 and snaps[0] < resets[0]
