"""Property 3: Incomplete profiles are rejected by field name.

**Validates: Requirements 4.6**

For any valid App_Profile and any required field, removing the field or
setting it to the empty string makes profile_validate fail. The message holds
the profile file path and the field name, and profile_load_all loads nothing.
"""
from __future__ import annotations

from hypothesis import given, strategies as st

from conftest import (
    Repo,
    bundle_ids,
    profile_ids,
    prompt_text,
    run_bash,
    scenario_names,
    tcc_services,
)

LIBS = ("common", "defaults", "validate", "profile")
TOP_FIELDS = ["profile_id", "display_name", "bundle_id", "launch", "input_locator", "send_action"]

words = st.text(alphabet="abcdefghijklmnopqrstuvwxyz0123456789 ", min_size=1, max_size=20).filter(
    lambda s: s.strip() != ""
).map(str.strip)


@st.composite
def valid_profiles(draw) -> tuple[str, dict[str, str]]:
    """A profile id and an ordered key/value dict that profile_validate accepts."""
    pid = draw(profile_ids)
    fields = {
        "profile_id": pid,
        "display_name": draw(words),
        "bundle_id": draw(bundle_ids),
        "launch": "open -b " + draw(bundle_ids),
        "input_locator": draw(words),
        "send_action": draw(st.sampled_from(["key:return", "click:send"])),
    }
    names = draw(st.lists(scenario_names, min_size=1, max_size=4, unique=True))
    for name in names:
        fields[f"scenario.{name}.prompt"] = draw(prompt_text)
        fields[f"scenario.{name}.service"] = draw(tcc_services)
    return pid, fields


def render(fields: dict[str, str]) -> str:
    return "".join(f"{k} = {v}\n" for k, v in fields.items())


def validate(repo: Repo, path) -> "subprocess.CompletedProcess[str]":
    return run_bash(repo, 'profile_validate "$1"', str(path), libs=LIBS, stubs=False)


def has_missing_line(stderr: str, path: str, field: str) -> bool:
    """True when a line reads exactly '<path>: missing field <field>'."""
    return f"{path}: missing field {field}" in stderr.split("\n")


@given(data=st.data(), profile=valid_profiles(), mode=st.sampled_from(["remove", "empty"]))
def test_incomplete_profile_rejected_by_field_name(
    repo: Repo, data: st.DataObject, profile: tuple[str, dict[str, str]], mode: str
) -> None:
    pid, fields = profile
    # Each profile iteration reuses the repo fixture: clear earlier files.
    for old in repo.profiles_dir.glob("*.profile"):
        old.unlink()
    path = repo.write_profile(pid, render(fields))
    assert validate(repo, path).returncode == 0, "generated profile must be valid"

    required = [k for k in fields if k in TOP_FIELDS or k.startswith("scenario.")]
    target = data.draw(st.sampled_from(required), label="field")
    broken = dict(fields)
    if mode == "remove":
        del broken[target]
    else:
        broken[target] = ""
    path.write_text(render(broken))

    r = validate(repo, path)
    assert r.returncode == 1
    assert has_missing_line(r.stderr, str(path), target), r.stderr

    # No Scenario of that profile is runnable: loading reports failure, loads nothing.
    r = run_bash(
        repo,
        'profile_load_all "$1"; rc=$?; echo "rc=$rc n=${#CAPTURE_PROFILE_IDS[@]}"',
        str(repo.profiles_dir),
        libs=LIBS,
        stubs=False,
    )
    assert "rc=2 n=0" in r.stdout, (r.stdout, r.stderr)


@given(profile=valid_profiles())
def test_profile_without_any_scenario_rejected(
    repo: Repo, profile: tuple[str, dict[str, str]]
) -> None:
    pid, fields = profile
    for old in repo.profiles_dir.glob("*.profile"):
        old.unlink()
    top = {k: v for k, v in fields.items() if k in TOP_FIELDS}
    path = repo.write_profile(pid, render(top))
    r = validate(repo, path)
    assert r.returncode == 1
    assert has_missing_line(r.stderr, str(path), "scenario"), r.stderr
