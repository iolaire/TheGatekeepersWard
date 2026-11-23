"""Property 4: Profile ID must match file name.
**Validates: Requirements 4.7**
Drives lib/profile.sh profile_validate through bash with the path as argv.
"""
from __future__ import annotations

from hypothesis import given

from conftest import Repo, profile_ids, run_bash

LIBS = ("common", "defaults", "validate", "profile")


def _profile_text(declared_id: str) -> str:
    return (
        f"profile_id = {declared_id}\n"
        "display_name = Demo App\n"
        "bundle_id = dev.demo.app\n"
        "launch = open -b dev.demo.app\n"
        "input_locator = ax:text area 1 of window 1\n"
        "send_action = key:return\n"
        "scenario.desktop.prompt = List the files on my Desktop.\n"
        "scenario.desktop.service = SystemPolicyDesktopFolder\n"
    )


def _validate(repo: Repo, stem: str, declared_id: str):
    path = repo.write_profile(stem, _profile_text(declared_id))
    return path, run_bash(repo, 'profile_validate "$1"', str(path), libs=LIBS)


@given(declared=profile_ids, stem=profile_ids)
def test_mismatch_fails_and_names_both(repo: Repo, declared: str, stem: str) -> None:
    if declared == stem:
        stem = stem + "x"
    path, res = _validate(repo, stem, declared)
    assert res.returncode != 0
    assert str(path) in res.stderr
    assert f"'{declared}'" in res.stderr
    assert f"'{stem}'" in res.stderr
    assert "does not match" in res.stderr


@given(pid=profile_ids)
def test_match_is_not_rejected_for_id(repo: Repo, pid: str) -> None:
    path, res = _validate(repo, pid, pid)
    assert "does not match" not in res.stderr
    assert res.returncode == 0, res.stderr


@given(pid=profile_ids)
def test_mismatch_by_case_is_rejected(repo: Repo, pid: str) -> None:
    # Comparison is exact: an upper-case declared ID never matches the stem.
    declared = pid.upper() if pid.upper() != pid else pid + "A"
    path, res = _validate(repo, pid, declared)
    assert res.returncode != 0
    assert f"'{declared}'" in res.stderr and f"'{pid}'" in res.stderr
