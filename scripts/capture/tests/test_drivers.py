"""Unit tests for the side-effecting drivers, run against stub binaries.

Covers: ffmpeg missing (8.5), recorder exiting within 1 second (8.6), Ward
reuse and baseline refusal (9.2, 9.6), clipboard restore on a failed paste
(5.9) and --resolve none (10.2).

No test here needs a macOS permission and none kills a real process: every
external binary is a stub and the Ward PID comes from the pgrep stub.
"""

from __future__ import annotations

import shutil
import stat
from pathlib import Path

import pytest

from conftest import Repo, run_bash


def _env(repo: Repo, tmp_path: Path, **extra: str) -> dict[str, str]:
    state = tmp_path / "state"
    env = {
        "CAPTURE_STATE_DIR": str(state),
        "CAPTURE_MANIFEST_TMP": str(tmp_path / "manifest-tmp"),
    }
    env.update(extra)
    return env


# --------------------------------------------------------------------------
# video.sh
# --------------------------------------------------------------------------

def test_ffmpeg_missing_fails_with_install_hint(repo: Repo, tmp_path: Path) -> None:
    """Requirement 8.5: ffmpeg backend without ffmpeg reports it and starts nothing."""
    if any(shutil.which("ffmpeg", path=p) for p in ("/usr/bin", "/bin")):
        pytest.skip("ffmpeg is installed in a system directory")
    session = tmp_path / "session"
    session.mkdir()
    # PATH holds only the stubs and the system directories, so ffmpeg is absent.
    path = f"{repo.stubs_dir}:/usr/bin:/bin"
    res = run_bash(
        repo,
        'video_start "$1" ffmpeg',
        str(session),
        libs=("common", "defaults", "video"),
        env=_env(repo, tmp_path, PATH=path),
    )
    assert res.returncode == 1
    assert "ffmpeg was not found" in res.stderr
    assert "--video-backend screencapture" in res.stderr
    assert not (tmp_path / "state" / "recorder.pid").exists()
    assert list(session.iterdir()) == []


def test_recorder_exiting_within_one_second_is_a_failure(repo: Repo, tmp_path: Path) -> None:
    """Requirement 8.6: a recorder that dies right after launch fails video_start."""
    session = tmp_path / "session"
    session.mkdir()
    res = run_bash(
        repo,
        'video_start "$1" screencapture',
        str(session),
        libs=("common", "defaults", "video"),
        env=_env(repo, tmp_path, STUB_SCREENCAPTURE_EXIT="1"),
    )
    assert res.returncode == 1
    assert "video backend failure" in res.stderr
    assert "exited within 1 s" in res.stderr
    assert not (tmp_path / "state" / "recorder.pid").exists()
    assert repo.calls("screencapture"), "the recorder was launched"
    assert repo.calls("screencapture")[0][1:3] == ["-v", "-x"]


def test_video_stop_without_recorder_is_a_noop(repo: Repo, tmp_path: Path) -> None:
    res = run_bash(
        repo,
        "video_stop",
        libs=("common", "defaults", "video"),
        env=_env(repo, tmp_path),
    )
    assert res.returncode == 0
    assert res.stdout == ""


# --------------------------------------------------------------------------
# ward.sh
# --------------------------------------------------------------------------

def test_ward_reuse_writes_no_marker_and_starts_nothing(repo: Repo, tmp_path: Path) -> None:
    """Requirement 9.2: a running Ward is reused, no Marker_File is written."""
    res = run_bash(
        repo,
        """
        ward_ensure ward; rc=$?
        [ -e "$(ward_marker_file)" ] && echo MARKER_PRESENT || echo NO_MARKER
        exit "$rc"
        """,
        libs=("common", "defaults", "ward"),
        env=_env(repo, tmp_path, STUB_PGREP_OUT="4242"),
    )
    assert res.returncode == 0, res.stderr
    assert "reusing running Ward (PID 4242)" in res.stdout
    assert "NO_MARKER" in res.stdout
    assert not (tmp_path / "state" / "ward.pid").exists()
    assert len(repo.calls("pgrep")) == 1, "no second lookup after run_ward.sh"


def test_ward_stop_if_marked_leaves_unmarked_ward_alone(repo: Repo, tmp_path: Path) -> None:
    """Requirement 9.2: without a Marker_File nothing is stopped."""
    res = run_bash(
        repo,
        "ward_stop_if_marked",
        libs=("common", "defaults", "ward"),
        env=_env(repo, tmp_path, STUB_PGREP_OUT="4242"),
    )
    assert res.returncode == 0
    assert res.stderr == ""


def test_baseline_refuses_when_ward_is_running(repo: Repo, tmp_path: Path) -> None:
    """Requirement 9.6: baseline mode names the PIDs and returns 1."""
    res = run_bash(
        repo,
        "ward_ensure baseline",
        libs=("common", "defaults", "ward"),
        env=_env(repo, tmp_path, STUB_PGREP_OUT="4242\n4343"),
    )
    assert res.returncode == 1
    assert "Ward is running (PID 4242 4343)" in res.stderr
    assert "baseline" in res.stderr


def test_baseline_passes_when_no_ward_is_running(repo: Repo, tmp_path: Path) -> None:
    res = run_bash(
        repo,
        "ward_ensure baseline",
        libs=("common", "defaults", "ward"),
        env=_env(repo, tmp_path),
    )
    assert res.returncode == 0
    assert res.stderr == ""


# --------------------------------------------------------------------------
# app.sh: clipboard restore
# --------------------------------------------------------------------------

_CLIPBOARD_STUB = """#!/usr/bin/env bash
# osascript stub: snapshot writes the snapshot file, "paste" fails when
# STUB_PASTE_FAILS=1, everything else succeeds.
. "$(dirname "$0")/_stub_common.sh"
stub_log_call osascript "$@"
verb=""
for a in "$@"; do
  case "$a" in snapshot|restore|set|paste|send) verb="$a" ;; esac
done
if [ "$verb" = snapshot ]; then
  eval "snap=\\${$#}"
  printf 'saved\\n' >"$snap"
fi
if [ "$verb" = paste ] && [ "${STUB_PASTE_FAILS:-0}" = "1" ]; then
  exit 1
fi
exit 0
"""

_PROFILE = """profile_id = fake
display_name = Fake
bundle_id = com.example.fake
launch = open -b com.example.fake
input_locator = ax:text area 1
send_action = key:return
send_method = clipboard
scenario.one.prompt = hello
scenario.one.service = SystemPolicyDesktopFolder
"""


def _install_clipboard_stub(repo: Repo) -> None:
    path = repo.stubs_dir / "osascript"
    path.write_text(_CLIPBOARD_STUB)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def _verbs(repo: Repo) -> list[str]:
    out = []
    for call in repo.calls("osascript"):
        for verb in ("snapshot", "restore", "set", "paste", "send"):
            if verb in call[1:]:
                out.append(verb)
                break
    return out


def test_clipboard_restored_when_paste_fails(repo: Repo, tmp_path: Path) -> None:
    """Requirement 5.9: the clipboard is restored and nothing is sent after a failed paste."""
    _install_clipboard_stub(repo)
    repo.write_profile("fake", _PROFILE)
    res = run_bash(
        repo,
        'app_send fake "$1" clipboard',
        "some prompt text",
        libs=("common", "defaults", "app"),
        env=_env(repo, tmp_path, STUB_PASTE_FAILS="1"),
    )
    assert res.returncode == 1
    assert "clipboard paste failed" in res.stderr
    verbs = _verbs(repo)
    assert verbs == ["snapshot", "set", "paste", "restore"], verbs
    assert "send" not in verbs
    assert not (tmp_path / "state" / "clipboard.snap").exists()


def test_clipboard_restored_after_successful_paste(repo: Repo, tmp_path: Path) -> None:
    """Requirement 5.9: restore also happens on success, before the send action."""
    _install_clipboard_stub(repo)
    repo.write_profile("fake", _PROFILE)
    res = run_bash(
        repo,
        'app_send fake "$1" clipboard',
        "some prompt text",
        libs=("common", "defaults", "app"),
        env=_env(repo, tmp_path),
    )
    assert res.returncode == 0, res.stderr
    assert _verbs(repo) == ["snapshot", "set", "paste", "restore", "send"]
    assert not (tmp_path / "state" / "clipboard.snap").exists()


# --------------------------------------------------------------------------
# resolve.sh: --resolve none
# --------------------------------------------------------------------------

def test_resolve_none_clicks_nothing_and_records_skipped(repo: Repo, tmp_path: Path) -> None:
    """Requirement 10.2: none prints a notice, records skipped, touches no UI."""
    env = _env(repo, tmp_path)
    res = run_bash(
        repo,
        """
        resolve_prompt none; rc=$?
        cat "$(manifest_scratch)/f.prompt.resolution"; echo
        exit "$rc"
        """,
        libs=("common", "defaults", "resolve"),
        env=env,
    )
    assert res.returncode == 0, res.stderr
    assert "--resolve none" in res.stdout
    assert "Resolve it manually" in res.stdout
    assert res.stdout.strip().splitlines()[-1] == "skipped"
    assert repo.calls() == [], "no osascript, screencapture or other binary was called"


def test_resolve_rejects_unknown_choice_before_touching_anything(
    repo: Repo, tmp_path: Path
) -> None:
    res = run_bash(
        repo,
        'resolve_prompt "$1"',
        "maybe",
        libs=("common", "defaults", "resolve"),
        env=_env(repo, tmp_path),
    )
    assert res.returncode == 2
    assert repo.calls() == []
