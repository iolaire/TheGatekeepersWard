"""Unit tests for orchestration and security boundaries.

Covers step order with stub steps, a failing step producing an `error`
manifest plus cleanup, a failed screenshot being skipped, a static scan of the
framework scripts for forbidden references, and the guarantee that the default
suite needs no macOS permission.

**Validates: Requirements 7.8, 12.1, 12.5, 13.1, 13.4, 14.3, 14.4**
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import pytest

from conftest import CAPTURE_SRC, STUB_NAMES, Repo, run_bash, run_capture, skip_without_permission

LIBS = ("common", "defaults", "validate", "profile", "reset", "session", "manifest",
        "shots", "runner_steps", "runner")

STEP_NAMES = ["preflight", "reset", "video-start", "app-launch", "prompt-send",
              "prompt-detection", "screenshots", "dwell", "resolve", "video-stop"]
STEP_FNS = ["step_preflight", "step_reset", "step_video_start", "step_app_launch",
            "step_prompt_send", "step_prompt_detection", "step_screenshots",
            "step_dwell", "step_resolve", "step_video_stop"]

# Replaces every step with a logging stub. $FAIL names one step function that
# fails with a message. cleanup_all and ward_stop_if_marked are stubbed too,
# and the manifest-write step dumps the accumulated fields instead of building
# JSON, so this part needs no osascript.
STUBBED = r'''
LOG="$CAPTURE_REPO_ROOT/events.log"
: >"$LOG"
for fn in %(fns)s step_reset_after; do
  eval "$fn() {
    echo \"$fn\" >>\"\$LOG\"
    if [ \"\$FAIL\" = \"$fn\" ]; then echo \"boom in $fn\" >&2; return 1; fi
    return 0
  }"
done
step_reset() { echo step_reset >>"$LOG"; S_PAST_RESET=1; }
cleanup_all() { echo cleanup_all >>"$LOG"; }
ward_stop_if_marked() { echo ward_stop >>"$LOG"; }
''' % {"fns": " ".join(STEP_FNS)}

DUMP_MANIFEST = r'''
step_manifest_write() {
  echo step_manifest_write >>"$LOG"
  local d f
  d="$(manifest_scratch)"
  for f in outcome failed_step error; do
    [ -f "$d/f.$f" ] && printf '%s=%s\n' "$f" "$(cat "$d/f.$f")" >>"$LOG"
  done
  return 0
}
'''

SESSION = r'''
CAPTURE_DRY_RUN=0
CAPTURE_ROOT="$CAPTURE_REPO_ROOT/out"
CAPTURE_MANIFEST_TMP="$CAPTURE_REPO_ROOT/scratch"
export CAPTURE_ROOT CAPTURE_MANIFEST_TMP
mkdir -p "$CAPTURE_ROOT"
run_session zcode desktop "$1" 20260101T000000Z >"$CAPTURE_REPO_ROOT/stdout.log" 2>"$CAPTURE_REPO_ROOT/stderr.log"
echo "rc=$?"
'''


def _clean_env(repo: Repo) -> dict[str, str]:
    """Pin variables a developer shell may export, so the repo copy is used."""
    return {
        "CAPTURE_PROFILES_DIR": str(repo.profiles_dir),
        "CAPTURE_STATE_DIR": str(repo.root / "state"),
        "CAPTURE_PERMCHECK": "",
    }


def _events(repo: Repo) -> list[str]:
    return (repo.root / "events.log").read_text().splitlines()


def _run_session(repo: Repo, mode: str, fail: str = "", real_manifest: bool = False,
                 stubs: bool = True):
    snippet = STUBBED + ("" if real_manifest else DUMP_MANIFEST) + SESSION
    return run_bash(repo, snippet, mode, libs=LIBS, env={"FAIL": fail, **_clean_env(repo)}, stubs=stubs)


def _jxa_available() -> bool:
    try:
        out = subprocess.run(["osascript", "-l", "JavaScript", "-e", "1+1"],
                             capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return False
    return out.returncode == 0 and out.stdout.strip() == "2"


# --------------------------------------------------------------------------
# Step order (12.1)
# --------------------------------------------------------------------------
@pytest.mark.parametrize("mode", ["baseline", "ward"])
def test_steps_run_in_the_fixed_order(repo: Repo, mode: str) -> None:
    res = _run_session(repo, mode)
    assert res.returncode == 0, res.stderr
    assert "rc=0" in res.stdout
    expected = STEP_FNS + ["step_reset_after"]
    if mode == "ward":
        expected.append("ward_stop")
    expected += ["step_manifest_write"]
    assert _events(repo) == expected
    logged = re.findall(r"step: (\S+)$", (repo.root / "stdout.log").read_text(), re.M)
    assert logged == STEP_NAMES + ["reset-after", "manifest-write"]


# --------------------------------------------------------------------------
# Failing step: error manifest and cleanup (12.5)
# --------------------------------------------------------------------------
def test_failing_step_records_error_cleans_up_and_stops(repo: Repo) -> None:
    res = _run_session(repo, "baseline", fail="step_app_launch")
    assert res.returncode == 0, res.stderr
    assert "rc=1" in res.stdout
    events = _events(repo)
    # Steps before the failure ran, later ones did not.
    assert events[:4] == ["step_preflight", "step_reset", "step_video_start", "step_app_launch"]
    for later in ("step_prompt_send", "step_screenshots", "step_resolve", "step_video_stop"):
        assert later not in events
    # The end reset still ran (the start reset began) and comes before
    # cleanup_all, whose last TCC action is the restore (13.11).
    assert events.index("step_reset_after") > events.index("step_app_launch")
    assert events.index("cleanup_all") > events.index("step_reset_after")
    assert events.index("step_manifest_write") > events.index("cleanup_all")
    assert events[events.index("step_manifest_write"):][:4] == [
        "step_manifest_write", "outcome=error", "failed_step=app-launch",
        "error=boom in step_app_launch"]


def test_failing_step_writes_error_manifest_json(repo: Repo) -> None:
    if not _jxa_available():
        pytest.skip("real osascript JXA is unavailable (sandbox or no GUI session)")
    res = _run_session(repo, "baseline", fail="step_prompt_send", real_manifest=True, stubs=False)
    assert res.returncode == 0, res.stderr
    assert "rc=1" in res.stdout
    manifests = list((repo.root / "out").rglob("manifest.json"))
    assert len(manifests) == 1
    data = json.loads(manifests[0].read_text())
    assert data["outcome"] == "error"
    assert data["failed_step"] == "prompt-send"
    assert "boom in step_prompt_send" in data["error"]
    assert data["mode"] == "baseline"


# --------------------------------------------------------------------------
# Failed screenshot is skipped (7.8)
# --------------------------------------------------------------------------
FLAKY_SCREENCAPTURE = r'''#!/usr/bin/env bash
. "$(dirname "$0")/_stub_common.sh"
stub_log_call screencapture "$@"
eval "out=\${$#}"
case "$out" in
  *screen.tmp.png) exit 1 ;;
esac
printf 'stub-capture\n' >"$out"
'''

SHOTS = r'''
SESSION_DIR="$CAPTURE_REPO_ROOT/sess"; mkdir -p "$SESSION_DIR"
CAPTURE_DRY_RUN=0; S_MODE=baseline; S_PROMPT_ID=4242; S_PROMPT_RECT="0 0 10 10"
OPT_NO_IMAGES=0; OPT_DISPLAY=""
step_screenshots; echo "rc=$?"
ls "$SESSION_DIR"
'''


def test_failed_screenshot_is_skipped_and_the_rest_continue(repo: Repo) -> None:
    shot = repo.stubs_dir / "screencapture"
    shot.write_text(FLAKY_SCREENCAPTURE)
    shot.chmod(0o755)
    res = run_bash(repo, SHOTS, libs=LIBS, env=_clean_env(repo))
    assert res.returncode == 0, res.stderr
    lines = res.stdout.split()
    assert "rc=0" in lines
    assert "prompt.png" in lines
    assert "screen.png" not in lines
    assert not any(n.endswith(".tmp.png") for n in lines)
    assert "skipped screen.png" in res.stderr


# --------------------------------------------------------------------------
# Static scan (13.1, 13.4)
# --------------------------------------------------------------------------
FORBIDDEN = re.compile(r"TCC\.db|com\.apple\.TCC|(?<![\w./-])(?:curl|nc|ncat)(?![\w./-])")


# The only framework script allowed to name the TCC database (13.11).
TCC_DB_ALLOWED = ("lib/tccdb.sh",)


def _framework_files() -> list[Path]:
    files = []
    for p in sorted(CAPTURE_SRC.rglob("*")):
        rel = p.relative_to(CAPTURE_SRC).parts
        if not p.is_file() or rel[0] == "tests" or "__pycache__" in rel or p.suffix == ".md":
            continue
        files.append(p)
    return files


def test_scan_pattern_catches_commands_and_ignores_lookalikes() -> None:
    for bad in ("curl -s http://x", "echo hi | nc host 80", "x=$(curl y)", "sqlite3 TCC.db", "log com.apple.TCC"):
        assert FORBIDDEN.search(bad), bad
    for ok in ("async function", "sync", "func nc_like_name", "ncurses", "--hunch"):
        assert not FORBIDDEN.search(ok), ok


def test_no_framework_script_touches_tcc_db_or_the_network() -> None:
    files = _framework_files()
    assert any(f.name == "capture.sh" for f in files)
    assert any(f.suffix == ".sh" for f in files if f.parent.name == "lib")
    offenders = []
    for f in files:
        try:
            text = f.read_text()
        except UnicodeDecodeError:
            continue
        exempt_tcc = f.relative_to(CAPTURE_SRC).as_posix() in TCC_DB_ALLOWED
        for n, line in enumerate(text.splitlines(), 1):
            m = FORBIDDEN.search(line)
            if m and exempt_tcc and re.fullmatch(r"TCC\.db|com\.apple\.TCC", m.group(0)):
                m = None
            if m:
                offenders.append(f"{f.relative_to(CAPTURE_SRC)}:{n}: {line.strip()}")
    assert offenders == []


def test_tcc_db_exemption_is_limited_to_tccdb_sh() -> None:
    assert (CAPTURE_SRC / "lib" / "tccdb.sh").is_file()
    hits = sorted(f.relative_to(CAPTURE_SRC).as_posix() for f in _framework_files()
                  if re.search(r"TCC\.db|com\.apple\.TCC", f.read_text(errors="ignore")))
    assert set(hits) <= set(TCC_DB_ALLOWED), hits


# --------------------------------------------------------------------------
# No permission required (14.3, 14.4)
# --------------------------------------------------------------------------
def test_stub_binaries_exist_for_every_external_tool() -> None:
    for name in STUB_NAMES:
        stub = CAPTURE_SRC / "tests" / "stubs" / name
        assert stub.is_file(), name


def test_dry_run_calls_no_real_binary_and_logs_no_stub(repo: Repo) -> None:
    res = run_capture(repo, "run", "zcode", "desktop", "--dry-run", env=_clean_env(repo))
    assert res.returncode == 0, res.stderr
    assert repo.calls() == []
    assert list(repo.captures_dir.iterdir()) == []


def test_permission_helper_skips_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CAPTURE_TESTS_ALLOW_PERMISSIONS", raising=False)
    with pytest.raises(pytest.skip.Exception) as info:
        skip_without_permission("accessibility")
    assert "accessibility" in str(info.value)


def test_default_suite_does_not_opt_in_to_permissions() -> None:
    # No test module other than the harness may read the opt-in variable.
    readers = [p.name for p in (CAPTURE_SRC / "tests").glob("test_*.py")
               if "CAPTURE_TESTS_ALLOW_PERMISSIONS" in p.read_text() and p.name != Path(__file__).name]
    assert readers == []
