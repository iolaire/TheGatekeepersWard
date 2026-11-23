"""Property 42: --no-restore touches no database.

**Validates: Requirements 1.9, 12.7, 15.10, 16.16**

For any valid profile, scenario, mode and option combination that includes
`--no-restore`, a run makes no `sqlite3` call (the stub log has none), creates
no snapshot or backup file, does not probe Full Disk Access in preflight,
setup or doctor, and prints the no-restore notice. The `restore` subcommand
still restores any pending snapshot.

Every database used here is a temporary file selected through
CAPTURE_TCC_DB_TEST. Every subprocess has a timeout and an empty stdin.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

from hypothesis import given, strategies as st, settings
from conftest import E2E_EXAMPLES

from conftest import (
    Repo,
    TccDb,
    access_tables,
    make_repo,
    run_bash,
)

# (profile, scenario, service, bundle id) of the shipped profiles.
TARGETS = [
    ("zcode", "desktop", "SystemPolicyDesktopFolder", "dev.zcode.app"),
    ("zcode", "removable-volume", "SystemPolicyRemovableVolumes", "dev.zcode.app"),
    ("deepseek-harness", "desktop", "SystemPolicyDesktopFolder", "com.deepseek.dsh"),
    ("deepseek-harness", "removable-volume", "SystemPolicyRemovableVolumes", "com.deepseek.dsh"),
]
PERM_STATE_KEYS = ["accessibility", "screen-recording", "automation-system-events", "automation-finder"]

options = st.fixed_dictionaries(
    {
        "mode": st.sampled_from([None, "baseline", "ward"]),
        "resolve": st.sampled_from([None, "allow", "deny", "none"]),
        "backend": st.sampled_from([None, "screencapture", "ffmpeg"]),
        "flags": st.lists(
            st.sampled_from(["--no-reset", "--no-video", "--no-images", "--redact-notifications"]),
            unique=True,
            max_size=4,
        ),
    }
)


def _option_args(opts: dict) -> list[str]:
    args: list[str] = []
    for key, flag in (("mode", "--mode"), ("resolve", "--resolve"), ("backend", "--video-backend")):
        if opts[key] is not None:
            args += [flag, opts[key]]
    return args + list(opts["flags"])


class Env:
    """A fresh repo copy, state directory, permcheck stub and temp database."""

    def __init__(self, base: Path) -> None:
        self.repo: Repo = make_repo(base)
        self.state = base / "state"
        self.state.mkdir()
        tmp = base.resolve() / "tcc-test"
        tmp.mkdir()
        self.db = TccDb(tmp / "TCC-test.sqlite").reset([])
        self.permcheck = base / "permcheck"
        self.permcheck.write_text('#!/bin/sh\n[ "$1" = status ] && echo granted\nexit 0\n')
        self.permcheck.chmod(0o755)
        self.repo.extra_env.update(self.db.env)

    def real_osascript(self) -> None:
        """Put the real osascript first on PATH: restore parses the snapshot
        with JXA, which the canned osascript stub cannot do."""
        real = self.state.parent / "real-bin"
        real.mkdir(exist_ok=True)
        link = real / "osascript"
        if not link.exists():
            link.symlink_to("/usr/bin/osascript")
        self._real_bin = str(real)

    _real_bin: str | None = None

    @property
    def env(self) -> dict[str, str]:
        e = dict(os.environ)
        e.update(self.repo.extra_env)
        front = [self._real_bin] if self._real_bin else []
        e["PATH"] = os.pathsep.join(front + [str(self.repo.stubs_dir), e.get("PATH", "")])
        e["STUB_CALL_LOG"] = str(self.repo.call_log)
        e["CAPTURE_STATE_DIR"] = str(self.state)
        e["CAPTURE_PERMCHECK"] = str(self.permcheck)
        e["CAPTURE_PROFILES_DIR"] = str(self.repo.profiles_dir)
        e.pop("CAPTURE_NO_RESTORE", None)
        return e

    def capture(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(self.repo.capture_dir / "capture.sh"), *args],
            capture_output=True, text=True, input="", env=self.env,
            cwd=self.repo.root, timeout=120,
        )

    def db_files(self) -> list[str]:
        """Snapshot, backup and restored files anywhere under the state directory."""
        return sorted(
            str(p.relative_to(self.state))
            for p in self.state.rglob("*")
            if p.name.startswith(("tcc-snapshot", "TCC.db.backup"))
        )

    def all_new_db_files(self) -> list[str]:
        """Same search under the whole temporary repo, for strays."""
        return sorted(
            str(p)
            for p in self.repo.root.rglob("*")
            if p.name.startswith(("tcc-snapshot", "TCC.db.backup"))
        )


def _fresh(tmp_path_factory) -> Env:
    return Env(tmp_path_factory.mktemp("norestore"))


def _assert_untouched(e: Env, res: subprocess.CompletedProcess[str]) -> None:
    assert e.repo.calls("sqlite3") == [], e.repo.calls("sqlite3")
    assert e.db_files() == []
    assert e.all_new_db_files() == []


def _notice(res: subprocess.CompletedProcess[str]) -> bool:
    return "--no-restore" in res.stdout + res.stderr


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), opts=options, sub=st.sampled_from(["run", "prompt"]),
       all_scen=st.booleans())
def test_session_dry_run_no_restore(tmp_path_factory, target, opts, sub, all_scen):
    e = _fresh(tmp_path_factory)
    profile, scenario, _service, _bundle = target
    args = [sub, profile, scenario, "--dry-run", "--no-restore", *_option_args(opts)]
    if sub == "run" and all_scen:
        args.append("--all-scenarios")
    res = e.capture(*args)
    assert res.returncode == 0, res.stderr
    _assert_untouched(e, res)
    assert _notice(res), res.stdout
    # Preflight checks four permissions: no Full Disk Access probe is described.
    assert "Full Disk Access" not in res.stdout
    assert "tcc-snapshot" not in res.stdout


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), use_service=st.booleans(), dry=st.booleans())
def test_reset_no_restore(tmp_path_factory, target, use_service, dry):
    e = _fresh(tmp_path_factory)
    profile, _scenario, service, _bundle = target
    args = ["reset", profile, "--no-restore"]
    if use_service:
        args += ["--service", service]
    if dry:
        args.append("--dry-run")
    res = e.capture(*args)
    assert res.returncode == 0, res.stderr
    _assert_untouched(e, res)
    assert _notice(res), (res.stdout, res.stderr)
    if not dry:
        assert e.repo.calls("tccutil"), "the scoped reset itself still runs"


@given(opts=st.fixed_dictionaries({"backend": st.sampled_from([None, "screencapture", "ffmpeg"])}))
def test_setup_and_doctor_no_restore_do_not_probe(tmp_path_factory, opts):
    e = _fresh(tmp_path_factory)

    res = e.capture("setup", "--no-restore")
    assert res.returncode == 0, res.stderr
    assert "full-disk-access: skipped (--no-restore)" in res.stdout.splitlines()
    assert "full-disk-access: granted" not in res.stdout and "full-disk-access: missing" not in res.stdout
    assert _notice(res)
    state = (e.state / "setup.json").read_text()
    assert '"full-disk-access"' not in state
    assert all(f'"{k}"' in state for k in PERM_STATE_KEYS)
    _assert_untouched(e, res)

    res = e.capture("doctor", "--no-restore", "--video-backend", "ffmpeg")
    assert "full-disk-access: skipped (--no-restore)" in res.stdout.splitlines()
    assert _notice(res)
    assert "pending tcc snapshot: none" in res.stdout
    _assert_untouched(e, res)


@given(mode=st.sampled_from(["baseline", "ward"]), target=st.sampled_from(TARGETS))
def test_real_preflight_no_restore_skips_probe(tmp_path_factory, mode, target):
    """The real (not dry-run) preflight lists four permissions and never probes."""
    e = _fresh(tmp_path_factory)
    profile, scenario, _service, bundle = target
    snippet = r'''
OPT_NO_RESTORE=1; export OPT_NO_RESTORE
CAPTURE_DRY_RUN=0
S_PROFILE="$1"; S_BUNDLE="$2"; S_MODE="$3"
_preflight_perms
echo "--"
step_preflight
echo "rc=$?"
'''
    res = run_bash(
        e.repo, snippet, profile, bundle, mode,
        libs=("common", "defaults", "validate", "profile", "tccdb", "restore", "reset",
              "setup", "runner_steps"),
        env={"CAPTURE_STATE_DIR": str(e.state), "CAPTURE_PERMCHECK": str(e.permcheck)},
        stdin="",
    )
    listed, _, rest = res.stdout.partition("--\n")
    assert listed.split() == PERM_STATE_KEYS, (res.stdout, res.stderr)
    assert "full-disk-access" not in res.stderr
    assert "Full Disk Access" not in res.stderr
    assert e.repo.calls("sqlite3") == []
    assert e.db_files() == []


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), data=st.data())
def test_restore_still_works_after_no_restore_reset(tmp_path_factory, target, data):
    """--no-restore adds nothing, and `restore` still restores a pending snapshot."""
    e = _fresh(tmp_path_factory)
    e.real_osascript()
    profile, _scenario, _service, bundle = target
    rows = data.draw(access_tables(bundle))
    e.db.reset(rows)

    # A normal reset takes a snapshot and leaves it pending.
    first = e.capture("reset", profile)
    assert first.returncode == 0, (first.stdout, first.stderr)
    pending = e.db_files()
    assert f"tcc-snapshot-{bundle}.json" in pending
    e.repo.call_log.write_text("")

    # A --no-restore reset makes no sqlite3 call and adds no file.
    second = e.capture("reset", profile, "--no-restore")
    assert second.returncode == 0, (second.stdout, second.stderr)
    assert e.repo.calls("sqlite3") == []
    assert e.db_files() == pending

    # `restore` still restores the pending snapshot.
    third = e.capture("restore")
    assert third.returncode == 0, (third.stdout, third.stderr)
    assert f"restored TCC rows for bundle id {bundle}" in third.stdout
    assert e.repo.calls("sqlite3"), "restore reads and writes the database"
    after = e.db_files()
    assert f"tcc-snapshot-{bundle}.json" not in after
    assert f"tcc-snapshot-{bundle}.restored.json" in after
