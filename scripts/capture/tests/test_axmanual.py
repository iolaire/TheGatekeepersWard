"""Tests for ax_manual_accessibility: the Electron Accessibility step in app_launch.

The helper is replaced through CAPTURE_AXMANUAL with a script that logs its
argument, so no test touches a real app or needs a macOS permission.
"""

from __future__ import annotations

import stat
from pathlib import Path

from conftest import Repo, run_bash

_BASE = """profile_id = fake
display_name = Fake
bundle_id = com.example.fake
launch = open -b com.example.fake
input_locator = ax:text area 1
send_action = key:return
scenario.one.prompt = hello
scenario.one.service = SystemPolicyDesktopFolder
"""


def _helper(tmp_path: Path, rc: int = 0) -> tuple[Path, Path]:
    log = tmp_path / "axmanual.log"
    path = tmp_path / "axmanual-stub"
    path.write_text(f'#!/bin/bash\nprintf "%s\\n" "$*" >>"{log}"\necho ok\nexit {rc}\n')
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path, log


def _launch(repo: Repo, tmp_path: Path, profile: str, rc: int = 0, dry: bool = False):
    helper, log = _helper(tmp_path, rc)
    repo.write_profile("fake", profile)
    env = {
        "CAPTURE_STATE_DIR": str(tmp_path / "state"),
        "CAPTURE_AXMANUAL": str(helper),
        "STUB_OSASCRIPT_OUT": "true",  # app running and frontmost
        "CAPTURE_DRY_RUN": "1" if dry else "0",
    }
    res = run_bash(repo, "app_launch fake", libs=("common", "defaults", "app"),
                   env=env, stdin="", timeout=60)
    calls = log.read_text().splitlines() if log.exists() else []
    return res, calls


def test_flag_true_sets_attribute_after_window(repo: Repo, tmp_path: Path) -> None:
    res, calls = _launch(repo, tmp_path, _BASE + "ax_manual_accessibility = true\n")
    assert res.returncode == 0, res.stderr
    assert calls == ["com.example.fake"]
    ui = [c for c in repo.calls("osascript") if "frontmost" in c]
    assert ui, "frontmost was never checked before the attribute step"


def test_flag_absent_or_false_skips_helper(repo: Repo, tmp_path: Path) -> None:
    for extra in ("", "ax_manual_accessibility = false\n"):
        res, calls = _launch(repo, tmp_path, _BASE + extra)
        assert res.returncode == 0, res.stderr
        assert calls == []


def test_helper_failure_fails_launch(repo: Repo, tmp_path: Path) -> None:
    res, calls = _launch(repo, tmp_path, _BASE + "ax_manual_accessibility = true\n", rc=1)
    assert res.returncode == 1
    assert "could not expose com.example.fake to Accessibility" in res.stderr
    assert calls == ["com.example.fake"]


def test_dry_run_prints_step_without_running_it(repo: Repo, tmp_path: Path) -> None:
    res, calls = _launch(repo, tmp_path, _BASE + "ax_manual_accessibility = true\n", dry=True)
    assert res.returncode == 0, res.stderr
    assert calls == []
    assert "com.example.fake" in (res.stdout + res.stderr)
    assert "axmanual" in (res.stdout + res.stderr)


def test_validate_accepts_only_true_or_false(repo: Repo, tmp_path: Path) -> None:
    for value, ok in (("true", True), ("false", True), ("yes", False), ("1", False)):
        path = repo.write_profile("fake", _BASE + f"ax_manual_accessibility = {value}\n")
        res = run_bash(repo, 'profile_validate "$1"', str(path), libs=("common", "defaults", "validate", "profile"),
                       stdin="", timeout=60)
        assert (res.returncode == 0) == ok, (value, res.stderr)
        if not ok:
            assert "ax_manual_accessibility" in res.stderr


_APPROVE_STUB = """#!/usr/bin/env bash
# osascript stub for app_approve: the approve verb succeeds only when
# STUB_APPROVE_OK=1; windows.js list prints one prompt row when STUB_PROMPT=1.
. "$(dirname "$0")/_stub_common.sh"
stub_log_call osascript "$@"
for a in "$@"; do
  case "$a" in
    approve) [ "${STUB_APPROVE_OK:-0}" = 1 ] && { echo ok; exit 0; }; exit 1 ;;
    list) [ "${STUB_PROMPT:-0}" = 1 ] && printf '42\\tPromptOwner\\t8\\t1\\t10\\t10\\t300\\t200\\n'; exit 0 ;;
  esac
done
exit 0
"""


def _approve(repo: Repo, tmp_path: Path, extra: str, **env_extra: str):
    stub = repo.stubs_dir / "osascript"
    stub.write_text(_APPROVE_STUB)
    stub.chmod(stub.stat().st_mode | stat.S_IXUSR)
    repo.write_profile("fake", _BASE + 'approve_tool_call = find:button "Allow once"\n' + extra)
    env = {"CAPTURE_STATE_DIR": str(tmp_path / "state"),
           "CAPTURE_PROMPT_OWNER": "PromptOwner", "CAPTURE_PROMPT_LAYER": "8"}
    env.update(env_extra)
    res = run_bash(repo, "app_approve fake", libs=("common", "defaults", "windows", "app"),
                   env=env, stdin="", timeout=60)
    calls = [c for c in repo.calls("osascript") if "approve" in c]
    return res, calls


def test_approve_clicks_the_element(repo: Repo, tmp_path: Path) -> None:
    res, calls = _approve(repo, tmp_path, "approve_timeout = 120\n", STUB_APPROVE_OK="1")
    assert res.returncode == 0, res.stderr
    assert "approved:" in res.stdout
    assert calls[0][-3:] == ["com.example.fake", 'find:button "Allow once"', "2"]


def test_approve_skipped_when_prompt_already_shown(repo: Repo, tmp_path: Path) -> None:
    res, calls = _approve(repo, tmp_path, "approve_timeout = 120\n", STUB_PROMPT="1")
    assert res.returncode == 0, res.stderr
    assert "no tool approval needed" in res.stdout
    assert len(calls) == 1


def test_approve_fails_after_timeout(repo: Repo, tmp_path: Path) -> None:
    res, calls = _approve(repo, tmp_path, "approve_timeout = 1\n")
    assert res.returncode == 1
    assert 'approve_tool_call step failed: find:button "Allow once"' in res.stderr
    assert len(calls) >= 1


def test_approve_dry_run_prints_full_timeout(repo: Repo, tmp_path: Path) -> None:
    res, calls = _approve(repo, tmp_path, "", CAPTURE_DRY_RUN="1")
    assert res.returncode == 0, res.stderr
    assert "30" in res.stdout and "approve" in res.stdout
    assert calls == []


def test_validate_approve_timeout_range(repo: Repo, tmp_path: Path) -> None:
    for value, ok in (("1", True), ("300", True), ("0", False), ("301", False), ("abc", False)):
        path = repo.write_profile("fake", _BASE + f"approve_timeout = {value}\n")
        res = run_bash(repo, 'profile_validate "$1"', str(path), libs=("common", "defaults", "validate", "profile"),
                       stdin="", timeout=60)
        assert (res.returncode == 0) == ok, (value, res.stderr)
