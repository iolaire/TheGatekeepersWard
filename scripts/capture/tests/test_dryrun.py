"""Property 24: Dry-run has no effects.

**Validates: Requirements 3.7, 12.1, 14.5, 14.6**

For any valid profile, scenario, mode and option combination, `run --dry-run`
(and `prompt --dry-run`, `reset --dry-run`) exits 0, prints the twelve step
names in the fixed order together with the quoted text of each external
command, calls no stub binary (the stub call log is empty), and leaves the
file tree and file contents of the working directory exactly as they were,
including captures/.

The TCC snapshot and restore steps are covered too: a dry-run prints `would
snapshot`, `would back up` and `would restore` lines (and `tcc-restore: would
verify (dry-run)`) without calling sqlite3 or writing a snapshot or backup, with
or without a pending snapshot. With `--no-restore` it prints the one-time notice
and `tcc-restore: skipped (--no-restore)` and none of those lines.
`restore --dry-run` prints `would restore` for each pending snapshot and
`nothing to restore` when there is none.

**Validates: Requirements 12.7, 12.8, 14.5, 14.6, 15.11, 16.17**
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

from hypothesis import given, strategies as st, settings

from conftest import Repo, make_repo, prompt_text, run_capture, E2E_EXAMPLES

STEPS = [
    "preflight",
    "reset",
    "video-start",
    "app-launch",
    "prompt-send",
    "prompt-detection",
    "screenshots",
    "dwell",
    "resolve",
    "video-stop",
    "reset-after",
    "manifest-write",
]
STEP_RE = re.compile(r"^\S+ step: (\S+)$")

# (profile, scenario, service, bundle id) of the shipped profiles.
TARGETS = [
    ("zcode", "desktop", "SystemPolicyDesktopFolder", "dev.zcode.app"),
    ("zcode", "removable-volume", "SystemPolicyRemovableVolumes", "dev.zcode.app"),
    ("deepseek-harness", "desktop", "SystemPolicyDesktopFolder", "com.deepseek.dsh"),
    ("deepseek-harness", "removable-volume", "SystemPolicyRemovableVolumes", "com.deepseek.dsh"),
]

options = st.fixed_dictionaries(
    {
        "mode": st.sampled_from([None, "baseline", "ward"]),
        "resolve": st.sampled_from([None, "allow", "deny", "none"]),
        "backend": st.sampled_from([None, "screencapture", "ffmpeg"]),
        "display": st.sampled_from([None, "1"]),
        "flags": st.lists(
            st.sampled_from(
                ["--no-reset", "--no-video", "--no-images", "--redact-notifications", "--no-restore"]
            ),
            unique=True,
            max_size=5,
        ),
    }
)


def _option_args(opts: dict) -> list[str]:
    args: list[str] = []
    for key, flag in (("mode", "--mode"), ("resolve", "--resolve"),
                      ("backend", "--video-backend"), ("display", "--display")):
        if opts[key] is not None:
            args += [flag, opts[key]]
    return args + list(opts["flags"])


def _snapshot(root: Path) -> dict[str, tuple[str, bytes | str]]:
    """Every path under root with its kind and content (or link target)."""
    snap: dict[str, tuple[str, bytes | str]] = {}
    for p in sorted(root.rglob("*")):
        rel = str(p.relative_to(root))
        if p.is_symlink():
            snap[rel] = ("link", str(p.readlink()))
        elif p.is_dir():
            snap[rel] = ("dir", b"")
        else:
            snap[rel] = ("file", p.read_bytes())
    return snap


def _quoted(text: str) -> bytes:
    """bash printf %q of one string, as ext prints it (raw bytes: in the C
    locale %q escapes each byte of a multibyte character separately)."""
    out = subprocess.run(
        ["/bin/bash", "-c", 'printf "%q" "$1"', "bash", text],
        capture_output=True, check=True,
    )
    return out.stdout


def _run_bytes(repo: Repo, *args: str) -> subprocess.CompletedProcess[bytes]:
    env = dict(os.environ)
    env["PATH"] = f"{repo.stubs_dir}{os.pathsep}{env.get('PATH', '')}"
    env["STUB_CALL_LOG"] = str(repo.call_log)
    return subprocess.run(
        ["/bin/bash", str(repo.capture_dir / "capture.sh"), *args],
        capture_output=True, env=env, cwd=repo.root, timeout=60,
    )


def _steps(stdout: str) -> list[str]:
    return [m.group(1) for line in stdout.split("\n") if (m := STEP_RE.match(line))]


def _commands(stdout: str) -> list[str]:
    return [line for line in stdout.split("\n") if line.startswith("+ ")]


def _fresh(tmp_path_factory) -> Repo:
    return make_repo(tmp_path_factory.mktemp("dry"))


def _pend(repo: Repo, bundle: str) -> Path:
    """Leave a pending TCC snapshot for bundle in the state directory."""
    state = repo.captures_dir / ".state"
    state.mkdir(parents=True, exist_ok=True)
    path = state / f"tcc-snapshot-{bundle}.json"
    path.write_text('{\n  "bundle_id": "%s",\n  "rows": []\n}\n' % bundle)
    return path


def _count(stdout: str, prefix: str) -> int:
    return sum(1 for line in stdout.split("\n") if line.startswith(prefix))


NOTICE = "notice: --no-restore given"


def _check_tcc_lines(stdout: str, bundle: str, no_restore: bool, restores: bool) -> None:
    """The snapshot/back-up/restore lines of a dry-run of one bundle.

    restores: the command ends with a restore epilogue (run/prompt), so the
    snapshot taken in the run is also "restored" and verified.
    """
    snap = f"would snapshot TCC rows for bundle id {bundle}, services: "
    if no_restore:
        assert _count(stdout, NOTICE) == 1, stdout
        assert "would snapshot" not in stdout and "would back up" not in stdout, stdout
        assert "would restore" not in stdout and "tcc-snapshot:" not in stdout, stdout
        if restores:
            assert "tcc-restore: skipped (--no-restore)" in stdout.split("\n"), stdout
        return
    assert NOTICE not in stdout, stdout
    # Once per bundle per run, however many sessions the run has.
    assert _count(stdout, snap) == 1, stdout
    assert _count(stdout, "would back up the TCC database to ") == 1, stdout
    if restores:
        assert _count(stdout, f"would restore TCC rows for bundle id {bundle} from ") == 1, stdout
        assert "tcc-restore: would verify (dry-run)" in stdout.split("\n"), stdout
    else:
        assert "would restore" not in stdout, stdout


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), opts=options, sub=st.sampled_from(["run", "prompt"]),
       all_scen=st.booleans(), keep_going=st.booleans(), pending=st.booleans())
def test_session_dry_run_has_no_effects(
    tmp_path_factory, target, opts, sub, all_scen, keep_going, pending
):
    repo = _fresh(tmp_path_factory)
    profile, scenario, service, bundle = target
    if pending:
        _pend(repo, bundle)
    args = [sub, profile, scenario, "--dry-run", *_option_args(opts)]
    if sub == "run":
        if all_scen:
            args.append("--all-scenarios")
        if keep_going:
            args.append("--keep-going")
    before = _snapshot(repo.root)

    res = run_capture(repo, *args)

    assert res.returncode == 0, res.stderr
    assert _snapshot(repo.root) == before
    assert repo.calls() == []

    steps = _steps(res.stdout)
    assert steps and len(steps) % len(STEPS) == 0
    for i in range(0, len(steps), len(STEPS)):
        assert steps[i : i + len(STEPS)] == STEPS
    cmds = _commands(res.stdout)
    assert cmds
    # The scoped reset and the app launch are printed as quoted commands.
    assert any(c.startswith("+ tccutil reset ") and c.endswith(f" {bundle}") for c in cmds)
    assert f"+ open -b {bundle}" in cmds
    _check_tcc_lines(res.stdout, bundle, "--no-restore" in opts["flags"], restores=True)
    assert not any(c[0] == "sqlite3" for c in repo.calls())


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), use_service=st.booleans(), no_restore=st.booleans(),
       pending=st.booleans())
def test_reset_dry_run_has_no_effects(tmp_path_factory, target, use_service, no_restore, pending):
    repo = _fresh(tmp_path_factory)
    profile, _scenario, service, bundle = target
    if pending:
        _pend(repo, bundle)
    args = ["reset", profile, "--dry-run"] + (["--service", service] if use_service else [])
    if no_restore:
        args.append("--no-restore")
    before = _snapshot(repo.root)

    res = run_capture(repo, *args)

    assert res.returncode == 0, res.stderr
    assert _snapshot(repo.root) == before
    assert repo.calls() == []
    cmds = _commands(res.stdout)
    if use_service:
        assert cmds == [f"+ tccutil reset {service} {bundle}"]
    else:
        assert cmds and all(c.startswith("+ tccutil reset ") and c.endswith(f" {bundle}") for c in cmds)
    # reset snapshots (and leaves it pending) but never restores.
    _check_tcc_lines(res.stdout, bundle, no_restore, restores=False)
    if not no_restore:
        assert f"tcc-snapshot: {bundle} (left pending; run capture.sh restore to undo)" in res.stdout


@settings(max_examples=E2E_EXAMPLES)
@given(prompt=prompt_text)
def test_dry_run_prints_prompt_quoted(tmp_path_factory, prompt):
    repo = _fresh(tmp_path_factory)
    base = (repo.profiles_dir / "zcode.profile").read_text().splitlines()
    lines = [
        f"scenario.desktop.prompt         = {prompt}" if l.startswith("scenario.desktop.prompt ") else l
        for l in base
    ]
    repo.write_profile("zcode", "\n".join(lines) + "\n")
    before = _snapshot(repo.root)

    res = _run_bytes(repo, "prompt", "zcode", "desktop", "--dry-run")

    assert res.returncode == 0, res.stderr
    assert _snapshot(repo.root) == before
    assert repo.calls() == []
    assert _steps(res.stdout.decode("utf-8", "replace")) == STEPS
    assert _quoted(prompt) in res.stdout


@settings(max_examples=E2E_EXAMPLES)
@given(target=st.sampled_from(TARGETS), pending=st.booleans(), by_profile=st.booleans(),
       other_pending=st.booleans())
def test_restore_dry_run_has_no_effects(tmp_path_factory, target, pending, by_profile, other_pending):
    repo = _fresh(tmp_path_factory)
    profile, _scenario, _service, bundle = target
    other = "com.deepseek.dsh" if bundle == "dev.zcode.app" else "dev.zcode.app"
    if pending:
        _pend(repo, bundle)
    if other_pending:
        _pend(repo, other)
    args = ["restore", *([profile] if by_profile else []), "--dry-run"]
    before = _snapshot(repo.root)

    res = run_capture(repo, *args)

    assert res.returncode == 0, res.stderr
    # Nothing renamed to .restored.json, no stub binary called (no sqlite3, no pkill).
    assert _snapshot(repo.root) == before
    assert repo.calls() == []
    would = {line.split(" ")[7] for line in res.stdout.split("\n") if line.startswith("would restore TCC rows for bundle id ")}
    expected = {b for b, p in ((bundle, pending), (other, other_pending and not by_profile)) if p}
    assert would == expected, res.stdout
    for b in expected:
        assert f"would restore TCC rows for bundle id {b} from " in res.stdout
    assert ("nothing to restore" in res.stdout) == (not expected), res.stdout
    assert "restored TCC rows" not in res.stdout
