"""Unit tests for the TCC restore wiring (task 19.6).

**Validates: Requirements 2.11, 15.3, 16.1, 16.3, 16.9, 16.11, 16.13, 16.14, 16.15, 17.10**

Covers, with temporary databases only:
  * restore runs after the session's scoped reset and after the app quit in the
    success, step-failure and signal paths (checked from the stub call log)
  * `teardown` and `restore` restore every pending snapshot
  * the `tccd` restart goes through the `pkill` stub (and is skipped for a test
    database, see test_restore_one_with_a_test_database_skips_the_tccd_restart)
  * the rename to `.restored.json`, `nothing to restore`
  * a read-only temp database keeps the snapshot pending, with cause and backup
  * `tcc-snapshot.json` in the session directory and the Manifest artifacts
  * the notice naming the bundle ID and the backup path
  * `reset` followed by `restore`

Tool wrappers (first on PATH) log to the stub call log. `sqlite3` logs READ or
WRITE then runs the real binary, `tccutil` deletes the matching rows of the
temporary database as the real one would, `osascript` answers the System Events
and quit calls and passes everything else (snapshot JSON parsing) to the real
binary, and `pkill` is the repo stub.
"""
from __future__ import annotations

import os
import shutil
import sqlite3
import subprocess
from pathlib import Path

import pytest

from conftest import ACCESS_COLUMNS, Repo, TccDb, read_access_rows, run_bash

BUNDLE = "dev.zcode.app"
OTHER = "com.example.other"
RUN_TS = "20261120T153040Z"
SVC_DESKTOP = "SystemPolicyDesktopFolder"
SVC_REMOVABLE = "SystemPolicyRemovableVolumes"
SVC_DOCS = "SystemPolicyDocumentsFolder"


def _db_service(name: str) -> str:
    """Database form of a profile service: rows hold kTCCService<Name>."""
    return name if name.startswith("kTCCService") else "kTCCService" + name

SESSION_LIBS = ("common", "defaults", "validate", "profile", "tccdb", "restore", "reset",
                "plan", "session", "manifest", "cleanup", "runner_steps", "runner")
ENSURE_LIBS = ("common", "defaults", "validate", "profile", "tccdb", "restore", "reset")

_STUB_HEAD = '#!/bin/bash\n. "$STUB_COMMON"\n'
_WRAPPERS = {
    "sqlite3": _STUB_HEAD + r'''in=""
if [ ! -t 0 ]; then in="$(cat)"; fi
kind=READ
case "$in $*" in *INSERT*|*DELETE*|*UPDATE*) kind=WRITE ;; esac
stub_log_call sqlite3 "$kind"
printf '%s' "$in" | /usr/bin/sqlite3 "$@"
''',
    "tccutil": _STUB_HEAD + r'''stub_log_call tccutil "$@"
if [ "$1" = reset ] && [ -n "${CAPTURE_TCC_DB_TEST-}" ]; then
  /usr/bin/sqlite3 "$CAPTURE_TCC_DB_TEST" \
    "DELETE FROM access WHERE service IN ('$2', 'kTCCService$2') AND client = '$3';" </dev/null
fi
exit 0
''',
    "pkill": _STUB_HEAD + 'stub_log_call pkill "$@"\nexit 0\n',
    "osascript": _STUB_HEAD + r'''case "$*" in
  *"to quit"*)
    stub_log_call osascript quit-app
    : >"$QUIT_FLAG"
    exit 0 ;;
  *"System Events"*)
    stub_log_call osascript system-events-query
    if [ -e "$QUIT_FLAG" ]; then echo false; else echo true; fi
    exit 0 ;;
esac
stub_log_call osascript passthrough
exec /usr/bin/osascript "$@"
''',
}


def _jxa_available() -> bool:
    try:
        out = subprocess.run(["osascript", "-l", "JavaScript", "-e", "1+1"], capture_output=True,
                             text=True, timeout=30, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return False
    return out.returncode == 0 and out.stdout.strip() == "2"


@pytest.fixture(autouse=True)
def _need_jxa() -> None:
    if not _jxa_available():
        pytest.skip("real osascript JXA is unavailable (sandbox or no GUI session)")


def _row(service: str, client: str = BUNDLE, auth: int = 2, csreq: bytes | None = b"\x01\x00\xff\x7f") -> dict:
    row = dict.fromkeys(ACCESS_COLUMNS)
    row.update(service=_db_service(service), client=client, client_type=0, auth_value=auth, auth_reason=3,
               auth_version=1, csreq=csreq, indirect_object_identifier="UNUSED", last_modified=77)
    return row


ROWS = [
    _row(SVC_DESKTOP), _row(SVC_REMOVABLE, auth=0), _row("kTCCServiceCamera"),
    _row(SVC_DESKTOP, client="com.other.app"),
    _row(SVC_DOCS, client=OTHER), _row(SVC_DESKTOP, client=OTHER),
]


class Harness:
    """Temp repo + tool wrappers + temp database + environment."""

    def __init__(self, repo: Repo, tcc_db: TccDb, tmp: Path) -> None:
        self.repo = repo
        self.db = tcc_db
        self.tools = tmp / "tools"
        self.tools.mkdir()
        for name, text in _WRAPPERS.items():
            path = self.tools / name
            path.write_text(text)
            path.chmod(0o755)
        self.state = tmp / "state"
        self.flag = tmp / "quit.flag"
        self.root = repo.root
        self.env = {
            k: v for k, v in os.environ.items()
            if k not in ("CAPTURE_NO_RESTORE", "OPT_NO_RESTORE", "CAPTURE_DRY_RUN")
        }
        self.env.update({
            "PATH": os.pathsep.join([str(self.tools), "/usr/bin", "/bin", "/usr/sbin", "/sbin"]),
            "STUB_CALL_LOG": str(repo.call_log),
            "STUB_COMMON": str(repo.stubs_dir / "_stub_common.sh"),
            "QUIT_FLAG": str(self.flag),
            "CAPTURE_STATE_DIR": str(self.state),
            "CAPTURE_PROFILES_DIR": str(repo.profiles_dir),
            "CAPTURE_MANIFEST_TMP": str(tmp / "manifest-scratch"),
            "CAPTURE_ROOT": str(repo.root / "out"),
            "CAPTURE_QUIT_TIMEOUT": "2",
            **tcc_db.env,
        })
        tcc_db.reset(ROWS)

    def bash(self, snippet: str, *args: str, libs=SESSION_LIBS, env: dict | None = None):
        return run_bash(self.repo, snippet, *args, libs=libs, env={**self.env, **(env or {})},
                        stubs=False, stdin="", timeout=120)

    def capture(self, *args: str, env: dict | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(self.repo.capture_dir / "capture.sh"), *args],
            capture_output=True, text=True, stdin=subprocess.DEVNULL, cwd=self.root,
            env={**self.env, **(env or {})}, timeout=120)

    def calls(self) -> list[tuple[str, str]]:
        """(name, first-arg-or-joined-args) per logged call."""
        return [(c[0], " ".join(c[1:])) for c in self.repo.calls()]

    def index(self, pred) -> list[int]:
        return [i for i, c in enumerate(self.calls()) if pred(c)]

    def scope(self, client: str) -> list[tuple]:
        return [r for r in read_access_rows(self.db.path) if r[1] == client]

    def pending(self) -> list[str]:
        return sorted(p.name for p in self.state.glob("tcc-snapshot-*.json")
                      if not p.name.endswith(".restored.json"))

    def restored(self) -> list[str]:
        return sorted(p.name for p in self.state.glob("tcc-snapshot-*.restored.json"))

    def add_other_profile(self) -> None:
        text = (self.repo.profiles_dir / "zcode.profile").read_text()
        text = (text.replace("profile_id     = zcode", "profile_id     = other")
                .replace("display_name   = ZCode", "display_name   = Other")
                .replace(f"bundle_id      = {BUNDLE}", f"bundle_id      = {OTHER}")
                .replace(f"open -b {BUNDLE}", f"open -b {OTHER}")
                .replace(SVC_DESKTOP, SVC_DOCS))
        self.repo.write_profile("other", text)

    def take_snapshots(self, *profiles: str) -> None:
        res = self.bash(
            'CAPTURE_DRY_RUN=0; profile_load_all "$(profile_dir)" || exit 9\n'
            'for p in "$@"; do tcc_ensure_snapshot "$p" "$RUN" || exit 8; done',
            *profiles, libs=ENSURE_LIBS, env={"RUN": RUN_TS})
        assert res.returncode == 0, res.stderr

    def delete_scope(self, client: str) -> None:
        conn = sqlite3.connect(str(self.db.path))
        try:
            services = [_db_service(x) for x in ([SVC_DOCS] if client == OTHER else [SVC_DESKTOP, SVC_REMOVABLE])]
            marks = ",".join("?" for _ in services)
            conn.execute(f"DELETE FROM access WHERE client = ? AND service IN ({marks})",
                         [client, *services])
            conn.commit()
        finally:
            conn.close()


@pytest.fixture
def h(repo: Repo, tcc_db: TccDb, tmp_path: Path) -> Harness:
    return Harness(repo, tcc_db, tmp_path)


# Runs one session with every step stubbed except the TCC ones (step_reset,
# step_reset_after), then the run epilogue. $1 is ok, fail or signal.
SESSION = r'''
CAPTURE_DRY_RUN=0
mkdir -p "$CAPTURE_ROOT"
profile_load_all "$(profile_dir)" || exit 9
for fn in step_preflight step_video_start step_prompt_send step_prompt_detection \
  step_screenshots step_dwell step_resolve step_video_stop; do
  eval "$fn() { return 0; }"
done
step_app_launch() {
  mkdir -p "$CAPTURE_STATE_DIR"
  printf '%s\n' "$S_BUNDLE" >>"$CAPTURE_STATE_DIR/launched.txt"
  case "$APP_MODE" in
    fail) echo "boom in step_app_launch" >&2; return 1 ;;
    signal) kill -TERM $$ ;;
  esac
  return 0
}
step_manifest_write() {
  cp "$(manifest_scratch)/artifacts" "$CAPTURE_REPO_ROOT/artifacts.txt" 2>/dev/null
  return 0
}
rc=0
run_session zcode desktop baseline "$RUN" </dev/null || rc=$?
_runner_restore_epilogue
echo "rc=$rc status=$RUN_RESTORE_STATUS"
'''


def _run_session(h: Harness, mode: str):
    return h.bash(SESSION, env={"RUN": RUN_TS, "APP_MODE": mode})


def _assert_order(h: Harness, with_quit: bool) -> None:
    """Restore (a sqlite3 WRITE) comes after every tccutil reset and the app quit."""
    resets = h.index(lambda c: c[0] == "tccutil")
    writes = h.index(lambda c: c == ("sqlite3", "WRITE"))
    quits = h.index(lambda c: c == ("osascript", "quit-app"))
    reads = h.index(lambda c: c == ("sqlite3", "READ"))
    assert len(resets) == 2, h.calls()
    assert writes, h.calls()
    assert reads and reads[0] < resets[0], "the snapshot is read before the first reset"
    assert max(resets) < min(writes), h.calls()
    if with_quit:
        assert len(quits) == 1 and quits[0] < min(writes), h.calls()
    else:
        assert quits == []


def _assert_restored(h: Harness) -> None:
    assert read_access_rows(h.db.path) == read_access_rows_expected()
    assert h.pending() == []
    assert h.restored() == [f"tcc-snapshot-{BUNDLE}.restored.json"]


def read_access_rows_expected() -> list[tuple]:
    return sorted((tuple(r[c] for c in ACCESS_COLUMNS) for r in ROWS),
                  key=lambda r: (r[0], r[1], r[2], r[9]))


# --------------------------------------------------------------------------
# Ordering from the stub call log
# --------------------------------------------------------------------------
def test_success_path_restores_after_the_session_reset(h: Harness) -> None:
    res = _run_session(h, "ok")
    assert res.returncode == 0, res.stderr
    assert "rc=0 status=verified" in res.stdout, res.stdout
    assert "tcc-restore: verified" in res.stdout
    _assert_order(h, with_quit=False)
    _assert_restored(h)


def test_step_failure_path_restores_after_reset_and_app_quit(h: Harness) -> None:
    res = _run_session(h, "fail")
    assert res.returncode == 0, res.stderr
    assert "rc=1" in res.stdout, res.stdout
    assert "teardown: quit " + BUNDLE in res.stdout + res.stderr
    _assert_order(h, with_quit=True)
    _assert_restored(h)


def test_signal_path_restores_after_reset_and_app_quit(h: Harness) -> None:
    res = _run_session(h, "signal")
    assert res.returncode == 143, (res.returncode, res.stdout, res.stderr)
    _assert_order(h, with_quit=True)
    _assert_restored(h)


# --------------------------------------------------------------------------
# Session directory, Manifest, notice
# --------------------------------------------------------------------------
def test_snapshot_copy_manifest_artifact_and_notice(h: Harness) -> None:
    res = _run_session(h, "ok")
    assert res.returncode == 0, res.stderr
    session_dir = h.root / "out" / "captures" / RUN_TS / "zcode" / "desktop" / "baseline"
    copy = session_dir / "tcc-snapshot.json"
    assert copy.is_file()
    # The pending snapshot was renamed by the restore; the copy equals it.
    assert copy.read_bytes() == (h.state / f"tcc-snapshot-{BUNDLE}.restored.json").read_bytes()
    assert (h.root / "artifacts.txt").read_text().split() == ["tcc-snapshot.json"]
    backup = h.state / f"TCC.db.backup-{RUN_TS}"
    assert backup.is_file()
    assert f"notice: this run reads and may write the TCC database for bundle id '{BUNDLE}' only" in res.stdout
    assert f"notice: backup of the whole database: {backup}" in res.stdout
    assert f"tcc-snapshot: {BUNDLE}" in res.stdout


# --------------------------------------------------------------------------
# teardown and restore subcommands
# --------------------------------------------------------------------------
def test_teardown_restores_every_pending_snapshot(h: Harness) -> None:
    h.add_other_profile()
    h.take_snapshots("zcode", "other")
    assert h.pending() == sorted([f"tcc-snapshot-{OTHER}.json", f"tcc-snapshot-{BUNDLE}.json"])
    h.delete_scope(BUNDLE)
    h.delete_scope(OTHER)
    res = h.capture("teardown")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert f"restored TCC rows for bundle id {BUNDLE}" in res.stdout
    assert f"restored TCC rows for bundle id {OTHER}" in res.stdout
    assert read_access_rows(h.db.path) == read_access_rows_expected()
    assert h.pending() == []
    assert h.restored() == sorted([f"tcc-snapshot-{OTHER}.restored.json",
                                   f"tcc-snapshot-{BUNDLE}.restored.json"])


def test_restore_restores_every_pending_snapshot_then_reports_nothing(h: Harness) -> None:
    h.add_other_profile()
    h.take_snapshots("zcode", "other")
    h.delete_scope(BUNDLE)
    h.delete_scope(OTHER)
    res = h.capture("restore")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert res.stdout.count("restored TCC rows for bundle id") == 2
    assert read_access_rows(h.db.path) == read_access_rows_expected()
    assert h.pending() == []
    again = h.capture("restore")
    assert again.returncode == 0
    assert "nothing to restore" in again.stdout
    named = h.capture("restore", "zcode")
    assert named.returncode == 0 and "nothing to restore" in named.stdout


def test_restore_with_a_profile_restores_only_that_bundle(h: Harness) -> None:
    h.add_other_profile()
    h.take_snapshots("zcode", "other")
    h.delete_scope(BUNDLE)
    h.delete_scope(OTHER)
    res = h.capture("restore", "zcode")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert h.pending() == [f"tcc-snapshot-{OTHER}.json"]
    assert h.scope(BUNDLE) == [r for r in read_access_rows_expected() if r[1] == BUNDLE]
    assert [r[0] for r in h.scope(OTHER)] == [_db_service(SVC_DESKTOP)]  # in-scope Documents row still deleted


def test_teardown_with_nothing_pending_reports_nothing_to_tear_down(h: Harness) -> None:
    res = h.capture("teardown")
    assert res.returncode == 0, res.stderr
    assert "nothing needed to be torn down" in res.stdout
    assert h.calls() == []


# --------------------------------------------------------------------------
# reset followed by restore
# --------------------------------------------------------------------------
def test_reset_then_restore(h: Harness) -> None:
    res = h.capture("reset", "zcode")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert f"tcc-snapshot: {BUNDLE} (left pending; run capture.sh restore to undo)" in res.stdout
    assert h.pending() == [f"tcc-snapshot-{BUNDLE}.json"]
    assert [r[0] for r in h.scope(BUNDLE)] == ["kTCCServiceCamera"]
    tccutil = [c for c in h.calls() if c[0] == "tccutil"]
    assert tccutil == [("tccutil", f"reset {SVC_DESKTOP} {BUNDLE}"), ("tccutil", f"reset {SVC_REMOVABLE} {BUNDLE}")]

    res = h.capture("restore")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert f"restored TCC rows for bundle id {BUNDLE}" in res.stdout
    expected = [r for r in read_access_rows_expected() if r[1] == BUNDLE]
    assert h.scope(BUNDLE) == expected
    assert h.pending() == []
    assert h.restored() == [f"tcc-snapshot-{BUNDLE}.restored.json"]


# --------------------------------------------------------------------------
# Read-only database keeps the snapshot pending
# --------------------------------------------------------------------------
@pytest.mark.skipif(os.geteuid() == 0, reason="root ignores file modes")
def test_read_only_database_keeps_snapshot_pending_with_cause_and_backup(h: Harness) -> None:
    h.take_snapshots("zcode")
    h.delete_scope(BUNDLE)
    before = read_access_rows(h.db.path)
    snap = h.state / f"tcc-snapshot-{BUNDLE}.json"
    snap_bytes = snap.read_bytes()
    h.db.path.chmod(0o444)
    try:
        res = h.capture("restore")
        assert res.returncode == 1, (res.stdout, res.stderr)
        backup = h.state / f"TCC.db.backup-{RUN_TS}"
        assert f"could not write the TCC database for bundle id {BUNDLE}" in res.stderr
        assert "readonly" in res.stderr.lower() or "read-only" in res.stderr.lower(), res.stderr
        assert f"backup of the whole database: {backup}" in res.stderr
        assert "manual fallback" in res.stderr
        assert snap.read_bytes() == snap_bytes
        assert h.restored() == []
        assert read_access_rows(h.db.path) == before
        # teardown reports the failure and exits 1, snapshot still pending
        td = h.capture("teardown")
        assert td.returncode == 1, (td.stdout, td.stderr)
        assert "TCC restore failed" in td.stderr
        assert h.pending() == [f"tcc-snapshot-{BUNDLE}.json"]
    finally:
        h.db.path.chmod(0o644)
    ok = h.capture("restore")
    assert ok.returncode == 0, (ok.stdout, ok.stderr)
    assert h.pending() == []


# --------------------------------------------------------------------------
# tccd restart through the pkill stub
# --------------------------------------------------------------------------
def test_tccd_restart_goes_through_the_pkill_stub(h: Harness) -> None:
    # With no test database selected, the restart calls pkill (the stub).
    res = h.bash("tcc_restart_daemon", libs=("common", "defaults", "validate", "profile", "tccdb"),
                 env={"CAPTURE_TCC_DB_TEST": ""})
    assert res.returncode == 0, res.stderr
    assert "tccd restart: done" in res.stdout
    assert [c for c in h.repo.calls("pkill")] == [["pkill", "-x", "-u", str(os.getuid()), "tccd"]]


def test_restore_one_with_a_test_database_skips_the_tccd_restart(h: Harness) -> None:
    """CONFLICT with design (tccd restart through the pkill stub): tcc_restart_daemon
    skips pkill whenever CAPTURE_TCC_DB_TEST is set, and restore_one can only run
    against a temporary database here, so the restore path never reaches the stub.
    This pins the current behavior; the stub path is covered by the test above."""
    h.take_snapshots("zcode")
    h.delete_scope(BUNDLE)
    res = h.capture("restore")
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert "tccd restart: skipped (test database)" in res.stdout
    assert h.repo.calls("pkill") == []
    shutil.rmtree(h.state, ignore_errors=True)
