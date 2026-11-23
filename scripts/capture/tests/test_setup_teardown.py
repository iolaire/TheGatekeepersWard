"""Unit tests for setup, doctor and teardown.

**Validates: Requirements 1.1, 1.4, 1.5, 1.6, 1.7, 1.9, 2.1, 2.2, 2.3, 2.9, 2.11, 17.11**

Setup has five permissions. Four come from a CAPTURE_PERMCHECK stub script.
Full Disk Access is probed through tcc_probe (sqlite3 -readonly on a temporary
access database selected with CAPTURE_TCC_DB_TEST; a missing file, an unreadable
file or an absent sqlite3 means "missing"). State goes to a temporary
CAPTURE_STATE_DIR and every external binary is a harness stub. No real
permission is requested and the user's TCC database is never opened. Teardown
only ever signals a dummy process the test starts itself. Teardown cases that
restore a pending snapshot pass JXA snapshot parsing through to the real
osascript (the stub returns nothing) and use temporary databases only.
"""

from __future__ import annotations

import os
import signal
import sqlite3
import subprocess
import time
from pathlib import Path

import pytest

from conftest import ACCESS_COLUMNS, Repo, create_access_db, read_access_rows, run_bash

FDA = "full-disk-access"
PERMCHECK_PERMS = [
    "accessibility",
    "screen-recording",
    "automation-system-events",
    "automation-finder",
]
PERMS = PERMCHECK_PERMS + [FDA]
SKIPPED_LINE = "full-disk-access: skipped (--no-restore)"
BUNDLE = "dev.zcode.app"
SVC_DESKTOP = "SystemPolicyDesktopFolder"
SVC_REMOVABLE = "SystemPolicyRemovableVolumes"


def _db_service(name: str) -> str:
    """Database form of a profile service: rows hold kTCCService<Name>."""
    return name if name.startswith("kTCCService") else "kTCCService" + name
RUN_TS = "20261120T153040Z"

# status <name>  -> prints contents of $PERM_DIR/<name> ("granted" by default
#                   when missing file means "missing").
# request <name> -> logs the call; grants it when $PERM_DIR/<name>.on_request
#                   exists.
PERMCHECK = """#!/bin/sh
printf '%s %s\\n' "$1" "$2" >>"$PERM_DIR/calls"
case "$1" in
  status)
    if [ -f "$PERM_DIR/$2" ]; then cat "$PERM_DIR/$2"; else echo missing; fi ;;
  request)
    if [ -f "$PERM_DIR/$2.on_request" ]; then echo granted >"$PERM_DIR/$2"; fi
    if [ -f "$PERM_DIR/$2" ]; then cat "$PERM_DIR/$2"; else echo missing; fi ;;
esac
"""


@pytest.fixture
def perm(tmp_path: Path):
    """(permcheck path, perm dir, state dir) for one test."""
    pdir = tmp_path / "perm"
    pdir.mkdir()
    script = tmp_path / "permcheck.sh"
    script.write_text(PERMCHECK)
    script.chmod(0o755)
    state = tmp_path / "state"
    # The probe's folder exists; only the file is absent until granted.
    (script.resolve().parent / "tcc-test").mkdir()
    return script, pdir, state


def _fda_db(perm) -> Path:
    """Temporary access database that the Full Disk Access probe opens.

    Absent until a test grants Full Disk Access, so the default is "missing".
    The path is resolved and sits under the system temporary directory, as
    tcc_db_path requires for CAPTURE_TCC_DB_TEST.
    """
    return perm[0].resolve().parent / "tcc-test" / "TCC-test.sqlite"


def _env(perm, **extra: str) -> dict[str, str]:
    script, pdir, state = perm
    env = {
        "CAPTURE_PERMCHECK": str(script),
        "PERM_DIR": str(pdir),
        "CAPTURE_STATE_DIR": str(state),
        "CAPTURE_TCC_DB_TEST": str(_fda_db(perm)),
        "OPT_NO_RESTORE": "0",
        "CAPTURE_NO_RESTORE": "0",
        "CAPTURE_DRY_RUN": "0",
    }
    env.update(extra)
    return env


def _grant(perm, *names: str, on_request: tuple[str, ...] = ()) -> None:
    _, pdir, _ = perm
    for n in names:
        if n == FDA:
            db = _fda_db(perm)
            db.parent.mkdir(exist_ok=True)
            create_access_db(db, [])
            continue
        (pdir / n).write_text("granted\n")
    for n in on_request:
        (pdir / f"{n}.on_request").write_text("")


def _perm_calls(perm) -> list[str]:
    f = perm[1] / "calls"
    return f.read_text().splitlines() if f.exists() else []


def _setup(repo: Repo, perm, **extra: str):
    return run_bash(
        repo,
        'cmd_setup; exit $?',
        libs=("common", "defaults", "setup"),
        env=_env(perm, **extra),
        stdin="",
        timeout=60,
    )


def _status_lines(out: str) -> dict[str, str]:
    result = {}
    for line in out.splitlines():
        name, _, st = line.partition(": ")
        if name in PERMS:
            result[name] = st
    return result


# --------------------------------------------------------------------------
# setup
# --------------------------------------------------------------------------

def test_setup_prints_five_status_lines(repo: Repo, perm) -> None:
    _grant(perm, "accessibility", "automation-finder")
    r = _setup(repo, perm)
    assert _status_lines(r.stdout) == {
        "accessibility": "granted",
        "screen-recording": "missing",
        "automation-system-events": "missing",
        "automation-finder": "granted",
        FDA: "missing",
    }
    assert len([ln for ln in r.stdout.splitlines() if ln.split(":")[0] in PERMS]) == 5


def test_setup_full_disk_access_granted_through_a_readonly_sqlite3_probe(
    repo: Repo, perm
) -> None:
    _grant(perm, FDA)
    r = _setup(repo, perm)
    assert _status_lines(r.stdout)[FDA] == "granted"
    # Probed with sqlite3, not through the permcheck helper, and read-only.
    assert not any(FDA in c for c in _perm_calls(perm))
    probes = [c for c in repo.calls("sqlite3") if "-readonly" in c]
    assert probes, repo.calls("sqlite3")
    assert str(_fda_db(perm)) in probes[0]
    assert all(
        "com.apple.TCC" not in a for c in repo.calls("sqlite3") for a in c
    ), "the user's TCC database must never be opened"


def test_setup_full_disk_access_missing_when_database_is_absent_or_unreadable(
    repo: Repo, perm
) -> None:
    absent = _setup(repo, perm)
    assert _status_lines(absent.stdout)[FDA] == "missing"
    db = _fda_db(perm)
    db.parent.mkdir(exist_ok=True)
    db.write_bytes(b"this is not a database, and has no access table\n" * 4)
    unreadable = _setup(repo, perm)
    assert _status_lines(unreadable.stdout)[FDA] == "missing"


def test_setup_full_disk_access_missing_without_sqlite3(
    repo: Repo, perm, tmp_path: Path
) -> None:
    _grant(perm, FDA)
    path = _fake_bin(tmp_path, ["open"])  # no sqlite3 on PATH
    r = run_bash(
        repo,
        'cmd_setup; exit $?',
        libs=("common", "defaults", "setup"),
        env=_env(perm, PATH=path),
        stubs=False,
        stdin="",
        timeout=60,
    )
    assert _status_lines(r.stdout)[FDA] == "missing"


def test_setup_full_disk_access_unavailable_without_a_user_database_folder(
    repo: Repo, perm
) -> None:
    """Exit 3 from the probe: not a missing permission, no pane, setup succeeds."""
    _grant(perm, *PERMCHECK_PERMS)
    nodir = _fda_db(perm).parent.parent / "no-such-dir" / "TCC-test.sqlite"
    r = _setup(repo, perm, CAPTURE_TCC_DB_TEST=str(nodir))
    assert r.returncode == 0, r.stderr
    assert (
        "full-disk-access: unavailable (no user TCC database on this macOS; use --no-restore)"
        in r.stdout.splitlines()
    )
    assert repo.calls("open") == []
    assert "full-disk-access" not in r.stderr
    d = _doctor(repo, perm, CAPTURE_TCC_DB_TEST=str(nodir))
    assert (
        "full-disk-access: unavailable (no user TCC database on this macOS; use --no-restore)"
        in d.stdout.splitlines()
    )


def test_setup_all_granted_exits_zero_without_requests(repo: Repo, perm) -> None:
    _grant(perm, *PERMS)
    r = _setup(repo, perm)
    assert r.returncode == 0, r.stderr
    assert not any(c.startswith("request") for c in _perm_calls(perm))
    assert repo.calls("open") == []
    text = (perm[2] / "setup.json").read_text()
    for n in PERMS:
        assert f'"{n}": true' in text


def test_setup_missing_requests_opens_pane_and_exits_nonzero(repo: Repo, perm) -> None:
    _grant(perm, "accessibility")
    r = _setup(repo, perm)
    assert r.returncode == 1
    requested = [c for c in _perm_calls(perm) if c.startswith("request")]
    # Full Disk Access has no request API: only its pane is opened.
    assert sorted(requested) == sorted(
        f"request {n}" for n in PERMCHECK_PERMS if n != "accessibility"
    )
    urls = [c[1] for c in repo.calls("open")]
    assert any("Privacy_ScreenCapture" in u for u in urls)
    assert any("Privacy_Automation" in u for u in urls)
    assert any("Privacy_AllFiles" in u for u in urls)
    assert not any("Privacy_Accessibility" in u for u in urls)
    assert "still missing: screen-recording" in r.stderr
    assert "still missing: full-disk-access" in r.stderr
    assert "still missing: accessibility" not in r.stderr


def test_setup_full_disk_access_missing_names_the_pane(repo: Repo, perm) -> None:
    _grant(perm, *PERMCHECK_PERMS)
    r = _setup(repo, perm)
    assert r.returncode == 1
    assert (
        "full-disk-access is missing: grant it in System Settings (Privacy_AllFiles)"
        in r.stderr
    )
    assert (
        "still missing: full-disk-access (grant it in System Settings: Privacy_AllFiles)"
        in r.stderr
    )
    urls = [c[1] for c in repo.calls("open")]
    assert len(urls) == 1 and urls[0].endswith("?Privacy_AllFiles"), urls
    assert not any(c.startswith("request") for c in _perm_calls(perm))
    text = (perm[2] / "setup.json").read_text()
    assert '"full-disk-access": false' in text
    assert '"accessibility": true' in text


def test_setup_no_restore_skips_full_disk_access(repo: Repo, perm) -> None:
    _grant(perm, *PERMCHECK_PERMS)  # Full Disk Access stays absent
    r = _setup(repo, perm, OPT_NO_RESTORE="1")
    assert r.returncode == 0, r.stderr
    assert SKIPPED_LINE in r.stdout.splitlines()
    assert _status_lines(r.stdout)[FDA] == "skipped (--no-restore)"
    # The database is not probed, requested, or opened in Settings.
    assert repo.calls("sqlite3") == []
    assert repo.calls("open") == []
    assert "full-disk-access" not in r.stderr
    text = (perm[2] / "setup.json").read_text()
    assert FDA not in text
    for n in PERMCHECK_PERMS:
        assert f'"{n}": true' in text


def test_setup_no_restore_keeps_a_recorded_full_disk_access_value(
    repo: Repo, perm
) -> None:
    state = perm[2]
    state.mkdir()
    (state / "setup.json").write_text('{\n  "full-disk-access": false\n}\n')
    _grant(perm, *PERMCHECK_PERMS)
    r = _setup(repo, perm, OPT_NO_RESTORE="1")
    assert r.returncode == 0, r.stderr
    assert '"full-disk-access": false' in (state / "setup.json").read_text()


def test_setup_regrant_after_prompt_exits_zero(repo: Repo, perm) -> None:
    _grant(perm, "accessibility", on_request=("screen-recording",))
    _grant(perm, "automation-system-events", "automation-finder", FDA)
    r = _setup(repo, perm)
    assert r.returncode == 0, r.stderr
    # State records what was already granted before the request.
    text = (perm[2] / "setup.json").read_text()
    assert '"screen-recording": false' in text
    assert '"accessibility": true' in text


def test_setup_keeps_recorded_state_on_rerun(repo: Repo, perm) -> None:
    state = perm[2]
    state.mkdir()
    (state / "setup.json").write_text(
        "{\n" + ",\n".join(f'  "{n}": false' for n in PERMS) + "\n}\n"
    )
    _grant(perm, *PERMS)
    r = _setup(repo, perm)
    assert r.returncode == 0
    text = (state / "setup.json").read_text()
    assert '"accessibility": false' in text
    assert '"full-disk-access": false' in text


# --------------------------------------------------------------------------
# doctor
# --------------------------------------------------------------------------

def _doctor(repo: Repo, perm, path: str | None = None, **extra: str):
    env = _env(perm, **extra)
    if path is not None:
        env["PATH"] = path
    return run_bash(
        repo,
        'cmd_doctor; exit $?',
        libs=("common", "defaults", "setup"),
        env=env,
        stubs=path is None,
        stdin="",
        timeout=60,
    )


def _fake_bin(tmp_path: Path, tools: list[str]) -> str:
    """A PATH holding no-op executables for the listed tools plus sed/head."""
    b = tmp_path / "fakebin"
    b.mkdir()
    for t in tools:
        p = b / t
        p.write_text("#!/bin/sh\nexit 0\n")
        p.chmod(0o755)
    for real in ("sed", "head", "cat", "tr", "dirname", "sw_vers", "uname", "paste", "getconf"):
        for d in ("/usr/bin", "/bin"):
            if (Path(d) / real).exists():
                (b / real).symlink_to(Path(d) / real)
                break
    return str(b)


def test_doctor_reports_permissions_and_tools(repo: Repo, perm) -> None:
    _grant(perm, "accessibility")
    r = _doctor(repo, perm)
    out = r.stdout
    assert _status_lines(out)["accessibility"] == "granted"
    assert _status_lines(out)["screen-recording"] == "missing"
    assert _status_lines(out)[FDA] == "missing"
    assert len([ln for ln in out.splitlines() if ln.split(":")[0] in PERMS]) == 5
    for tool in ("osascript", "screencapture", "tccutil"):
        assert f"{tool}: found" in out
    assert "macos: " in out
    assert r.returncode == 0


def test_doctor_reports_full_disk_access_granted(repo: Repo, perm) -> None:
    _grant(perm, FDA)
    r = _doctor(repo, perm)
    assert _status_lines(r.stdout)[FDA] == "granted"
    assert r.returncode == 0


def test_doctor_no_restore_skips_full_disk_access(repo: Repo, perm) -> None:
    _grant(perm, FDA)
    r = _doctor(repo, perm, OPT_NO_RESTORE="1")
    assert SKIPPED_LINE in r.stdout.splitlines()
    assert repo.calls("sqlite3") == []
    assert r.returncode == 0


def _write_snapshot_file(perm, bundle: str, restored: bool = False) -> Path:
    state = perm[2]
    state.mkdir(exist_ok=True)
    suffix = ".restored.json" if restored else ".json"
    f = state / f"tcc-snapshot-{bundle}{suffix}"
    f.write_text("{}\n")
    return f


def test_doctor_pending_tcc_snapshot_none(repo: Repo, perm) -> None:
    r = _doctor(repo, perm)
    assert "pending tcc snapshot: none" in r.stdout.splitlines()
    perm[2].mkdir()
    _write_snapshot_file(perm, BUNDLE, restored=True)  # restored ones are not pending
    r = _doctor(repo, perm)
    assert "pending tcc snapshot: none" in r.stdout.splitlines()


def test_doctor_lists_pending_tcc_snapshot_bundles(repo: Repo, perm) -> None:
    _write_snapshot_file(perm, BUNDLE)
    one = _doctor(repo, perm)
    assert f"pending tcc snapshot: {BUNDLE}" in one.stdout.splitlines()
    _write_snapshot_file(perm, "com.example.other")
    two = _doctor(repo, perm)
    assert (
        f"pending tcc snapshot: com.example.other,{BUNDLE}" in two.stdout.splitlines()
    )
    assert two.returncode == 0


def test_doctor_is_read_only(repo: Repo, perm) -> None:
    _grant(perm, "accessibility")
    r = _doctor(repo, perm)
    assert r.returncode == 0
    assert not any(c.startswith("request") for c in _perm_calls(perm))
    assert repo.calls("open") == []
    assert not (perm[2] / "setup.json").exists()
    assert not perm[2].exists()


def test_doctor_does_not_write_the_database_or_snapshots(repo: Repo, perm) -> None:
    _grant(perm, FDA)
    before = _fda_db(perm).read_bytes()
    state = perm[2]
    f = _write_snapshot_file(perm, BUNDLE)
    r = _doctor(repo, perm)
    assert r.returncode == 0
    assert _fda_db(perm).read_bytes() == before
    assert f.read_text() == "{}\n"
    assert sorted(p.name for p in state.iterdir()) == [f.name]
    assert all(c[1] == "-readonly" for c in repo.calls("sqlite3"))


def test_doctor_missing_tool_exits_nonzero(repo: Repo, perm, tmp_path: Path) -> None:
    path = _fake_bin(tmp_path, ["osascript", "screencapture"])  # no tccutil
    r = _doctor(repo, perm, path=path)
    assert "tccutil: not found" in r.stdout
    assert "osascript: found" in r.stdout
    assert r.returncode == 1


def test_doctor_ffmpeg_checked_only_for_ffmpeg_backend(
    repo: Repo, perm, tmp_path: Path
) -> None:
    path = _fake_bin(tmp_path, ["osascript", "screencapture", "tccutil"])
    plain = _doctor(repo, perm, path=path)
    assert "ffmpeg" not in plain.stdout
    assert plain.returncode == 0
    ff = _doctor(repo, perm, path=path, CAPTURE_VIDEO_BACKEND="ffmpeg")
    assert "ffmpeg: not found" in ff.stdout
    assert ff.returncode == 1


# --------------------------------------------------------------------------
# teardown
# --------------------------------------------------------------------------

def _teardown(repo: Repo, perm, **extra: str):
    return run_bash(
        repo,
        'cmd_teardown; exit $?',
        libs=("common", "defaults", "cleanup"),
        env=_env(perm, **extra),
        stdin="",
        timeout=60,
    )


def _start_dummy() -> int:
    """Start a detached `sleep` (reparented, so no zombie) and return its PID."""
    out = subprocess.run(
        ["/bin/sh", "-c", "sleep 300 >/dev/null 2>&1 & echo $!"],
        capture_output=True,
        text=True,
        check=True,
        stdin=subprocess.DEVNULL,
        timeout=30,
    )
    return int(out.stdout.strip())


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    return True


def test_teardown_stops_marked_dummy_process(repo: Repo, perm) -> None:
    pid = _start_dummy()
    try:
        state = perm[2]
        state.mkdir()
        marker = state / "ward.pid"
        marker.write_text(f"{pid}\n")
        r = _teardown(repo, perm)
        assert r.returncode == 0, r.stderr
        deadline = time.time() + 5
        while _alive(pid) and time.time() < deadline:
            time.sleep(0.1)
        assert not _alive(pid)
        assert not marker.exists()
        assert "teardown: Ward stopped" in r.stdout
    finally:
        if _alive(pid):
            os.kill(pid, signal.SIGKILL)


def test_teardown_stale_marker_is_removed_without_error(repo: Repo, perm) -> None:
    done = subprocess.Popen(["/usr/bin/true"], stdin=subprocess.DEVNULL)
    done.wait(timeout=30)
    state = perm[2]
    state.mkdir()
    marker = state / "ward.pid"
    marker.write_text(f"{done.pid}\n")
    r = _teardown(repo, perm)
    assert r.returncode == 0, r.stderr
    assert not marker.exists()
    assert "teardown: Ward stopped" in r.stdout


def test_teardown_ignores_non_numeric_marker(repo: Repo, perm) -> None:
    state = perm[2]
    state.mkdir()
    marker = state / "ward.pid"
    marker.write_text("not-a-pid\n")
    r = _teardown(repo, perm)
    assert r.returncode == 0
    assert not marker.exists()


def test_teardown_nothing_to_tear_down(repo: Repo, perm) -> None:
    perm[2].mkdir()
    r = _teardown(repo, perm)
    assert r.returncode == 0
    assert "nothing needed to be torn down" in r.stdout


def test_teardown_with_missing_state_dir(repo: Repo, perm) -> None:
    assert not perm[2].exists()
    r = _teardown(repo, perm)
    assert r.returncode == 0
    assert "nothing needed to be torn down" in r.stdout


def test_teardown_is_idempotent(repo: Repo, perm) -> None:
    pid = _start_dummy()
    try:
        state = perm[2]
        state.mkdir()
        (state / "ward.pid").write_text(f"{pid}\n")
        first = _teardown(repo, perm)
        second = _teardown(repo, perm)
        assert first.returncode == 0
        assert second.returncode == 0
        assert "nothing needed to be torn down" in second.stdout
    finally:
        if _alive(pid):
            os.kill(pid, signal.SIGKILL)


# --------------------------------------------------------------------------
# teardown with a pending TCC snapshot
# --------------------------------------------------------------------------

SNAPSHOT_LIBS = ("common", "defaults", "validate", "profile", "tccdb", "restore", "reset")


def _row(service: str, client: str = BUNDLE, auth: int = 2) -> dict:
    row = dict.fromkeys(ACCESS_COLUMNS)
    row.update(
        service=_db_service(service), client=client, client_type=0, auth_value=auth, auth_reason=3,
        auth_version=1, csreq=b"\x01\x00\xff\x7f", indirect_object_identifier="UNUSED",
        last_modified=77,
    )
    return row


DB_ROWS = [
    _row(SVC_DESKTOP),
    _row(SVC_REMOVABLE, auth=0),
    _row("kTCCServiceCamera"),
    _row(SVC_DESKTOP, client="com.other.app"),
]


def _jxa_available() -> bool:
    try:
        out = subprocess.run(
            ["osascript", "-l", "JavaScript", "-e", "1+1"],
            capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return out.returncode == 0 and out.stdout.strip() == "2"


@pytest.fixture
def real_osascript(tmp_path: Path) -> Path:
    """A directory whose osascript passes everything to the real binary.

    The harness stub answers nothing, which makes snapshot parsing fail. Put
    this directory in front of the stubs for tests that restore a snapshot.
    """
    if not _jxa_available():
        pytest.skip("real osascript JXA is unavailable (sandbox or no GUI session)")
    d = tmp_path / "real-osascript"
    d.mkdir()
    wrapper = d / "osascript"
    wrapper.write_text('#!/bin/sh\nexec /usr/bin/osascript "$@"\n')
    wrapper.chmod(0o755)
    return d


def _restore_env(repo: Repo, perm, real: Path, **extra: str) -> dict[str, str]:
    path = os.pathsep.join([str(real), str(repo.stubs_dir), os.environ.get("PATH", "")])
    return _env(
        perm,
        PATH=path,
        STUB_CALL_LOG=str(repo.call_log),
        CAPTURE_PROFILES_DIR=str(repo.profiles_dir),
        CAPTURE_QUIT_TIMEOUT="2",
        **extra,
    )


def _take_snapshot(repo: Repo, perm, real: Path) -> None:
    """Snapshot the zcode scope of the temporary database, then change it."""
    _fda_db(perm).parent.mkdir(exist_ok=True)
    create_access_db(_fda_db(perm), DB_ROWS)
    res = run_bash(
        repo,
        'profile_load_all "$(profile_dir)" || exit 9\n'
        'tcc_ensure_snapshot zcode "$1" || exit 8',
        RUN_TS,
        libs=SNAPSHOT_LIBS,
        env=_restore_env(repo, perm, real),
        stubs=False,
        stdin="",
        timeout=120,
    )
    assert res.returncode == 0, (res.stdout, res.stderr)
    assert (perm[2] / f"tcc-snapshot-{BUNDLE}.json").is_file()
    # Simulate the run: the scoped rows are gone.
    conn = sqlite3.connect(str(_fda_db(perm)))
    try:
        conn.execute(
            "DELETE FROM access WHERE client = ? AND service IN (?, ?)",
            (BUNDLE, _db_service(SVC_DESKTOP), _db_service(SVC_REMOVABLE)),
        )
        conn.commit()
    finally:
        conn.close()
    assert len(read_access_rows(_fda_db(perm))) == 2


def _expected_rows() -> list[tuple]:
    return sorted(
        (tuple(r[c] for c in ACCESS_COLUMNS) for r in DB_ROWS),
        key=lambda r: (r[0], r[1], r[2], r[9]),
    )


def _teardown_real(repo: Repo, perm, real: Path, **extra: str):
    return run_bash(
        repo,
        'cmd_teardown; exit $?',
        libs=("common", "defaults", "cleanup"),
        env=_restore_env(repo, perm, real, **extra),
        stubs=False,
        stdin="",
        timeout=120,
    )


def test_teardown_restores_a_pending_snapshot(repo: Repo, perm, real_osascript: Path) -> None:
    _take_snapshot(repo, perm, real_osascript)
    r = _teardown_real(repo, perm, real_osascript)
    assert r.returncode == 0, (r.stdout, r.stderr)
    assert f"restored TCC rows for bundle id {BUNDLE}" in r.stdout
    assert "nothing needed to be torn down" not in r.stdout
    assert read_access_rows(_fda_db(perm)) == _expected_rows()
    state = perm[2]
    assert not (state / f"tcc-snapshot-{BUNDLE}.json").exists()
    assert (state / f"tcc-snapshot-{BUNDLE}.restored.json").is_file()
    # Idempotent: a second run has nothing pending and nothing else to do.
    again = _teardown_real(repo, perm, real_osascript)
    assert again.returncode == 0
    assert "nothing needed to be torn down" in again.stdout
    assert read_access_rows(_fda_db(perm)) == _expected_rows()


def test_teardown_stops_ward_then_restores_pending_snapshot(
    repo: Repo, perm, real_osascript: Path
) -> None:
    _take_snapshot(repo, perm, real_osascript)
    pid = _start_dummy()
    try:
        marker = perm[2] / "ward.pid"
        marker.write_text(f"{pid}\n")
        r = _teardown_real(repo, perm, real_osascript)
        assert r.returncode == 0, (r.stdout, r.stderr)
        assert not marker.exists()
        assert r.stdout.index("teardown: Ward stopped") < r.stdout.index(
            f"restored TCC rows for bundle id {BUNDLE}"
        )
        assert read_access_rows(_fda_db(perm)) == _expected_rows()
    finally:
        if _alive(pid):
            os.kill(pid, signal.SIGKILL)


def test_teardown_no_restore_leaves_the_snapshot_pending(
    repo: Repo, perm, real_osascript: Path
) -> None:
    _take_snapshot(repo, perm, real_osascript)
    before = read_access_rows(_fda_db(perm))
    r = _teardown_real(repo, perm, real_osascript, OPT_NO_RESTORE="1")
    assert r.returncode == 0, (r.stdout, r.stderr)
    assert "nothing needed to be torn down" in r.stdout
    assert "restored TCC rows" not in r.stdout
    assert read_access_rows(_fda_db(perm)) == before
    assert (perm[2] / f"tcc-snapshot-{BUNDLE}.json").is_file()


def test_teardown_failed_restore_exits_nonzero_and_stays_pending(
    repo: Repo, perm, real_osascript: Path
) -> None:
    _take_snapshot(repo, perm, real_osascript)
    snap = perm[2] / f"tcc-snapshot-{BUNDLE}.json"
    snap.write_text("this is not json\n")
    r = _teardown_real(repo, perm, real_osascript)
    assert r.returncode == 1, (r.stdout, r.stderr)
    assert "teardown: TCC restore failed" in r.stderr
    assert snap.is_file()
    assert len(read_access_rows(_fda_db(perm))) == 2  # nothing was written
