"""Property 1: Profile round trip.

**Validates: Requirements 4.2, 4.3**

For any valid App_Profile, writing it in profile format and parsing it with
profile_parse yields the same fields and scenario order, and `capture.sh list`
prints its ID, bundle ID and exactly its scenario names.
"""

from __future__ import annotations

import itertools
import shutil
from pathlib import Path

from hypothesis import given, settings, strategies as st

from conftest import (
    E2E_EXAMPLES,
    Repo,
    bundle_ids,
    prompt_text,
    run_bash,
    run_capture,
    scenario_names,
    tcc_services,
)

# Free-text field values: kept verbatim, so they must not have edge whitespace.
field_text = prompt_text.map(lambda s: s[:100]).filter(
    lambda s: s != "" and s == s.strip()
)


@st.composite
def profiles(draw) -> dict:
    names = draw(st.lists(scenario_names, min_size=1, max_size=20, unique=True))
    scenarios = []
    for name in names:
        sc = {
            "name": name,
            "prompt": draw(prompt_text),
            "service": draw(tcc_services),
        }
        if draw(st.booleans()):
            sc["prompt_timeout"] = str(draw(st.integers(1, 300)))
        if draw(st.booleans()):
            sc["dwell"] = str(draw(st.integers(1, 60)))
        scenarios.append(sc)
    prof = {
        "display_name": draw(field_text),
        "bundle_id": draw(bundle_ids),
        "launch": draw(field_text),
        "input_locator": draw(field_text),
        "send_action": draw(field_text),
        "scenarios": scenarios,
    }
    if draw(st.booleans()):
        prof["launch_timeout"] = str(draw(st.integers(1, 300)))
    if draw(st.booleans()):
        prof["send_method"] = draw(st.sampled_from(["clipboard", "keystroke"]))
    return prof


def expected_pairs(profile_id: str, prof: dict) -> list[tuple[str, str]]:
    pairs = [("profile_id", profile_id)]
    for key in ("display_name", "bundle_id", "launch", "launch_timeout",
                "input_locator", "send_method", "send_action"):
        if key in prof:
            pairs.append((key, prof[key]))
    for sc in prof["scenarios"]:
        for key in ("prompt", "service", "prompt_timeout", "dwell"):
            if key in sc:
                pairs.append((f"scenario.{sc['name']}.{key}", sc[key]))
    return pairs


def render(profile_id: str, prof: dict) -> str:
    lines = ["# generated profile", ""]
    lines += [f"{k} = {v}" for k, v in expected_pairs(profile_id, prof)]
    return "\n".join(lines) + "\n"


_counter = itertools.count()


def test_profile_roundtrip(tmp_path: Path, repo: Repo) -> None:
    @settings(max_examples=E2E_EXAMPLES)
    @given(profile_id=st.sampled_from(["zcode", "deepseek-harness", "a1"]), prof=profiles())
    def check(profile_id: str, prof: dict) -> None:
        pdir = tmp_path / f"profiles{next(_counter)}"
        pdir.mkdir()
        try:
            path = pdir / f"{profile_id}.profile"
            path.write_text(render(profile_id, prof), encoding="utf-8")

            # profile_parse yields the same fields in the same order.
            res = run_bash(
                repo, 'profile_parse "$1"', str(path),
                libs=("common", "defaults", "validate", "profile"),
            )
            assert res.returncode == 0, res.stderr
            got = [tuple(line.split("\t", 1)) for line in res.stdout.split("\n") if line]
            assert got == expected_pairs(profile_id, prof)

            # profile_scenarios keeps declaration order.
            names = [sc["name"] for sc in prof["scenarios"]]
            res = run_bash(
                repo, 'profile_scenarios "$1"', str(path),
                libs=("common", "defaults", "validate", "profile"),
            )
            assert res.stdout.split("\n")[:-1] == names

            # capture.sh list prints ID, bundle ID, and exactly the scenarios.
            res = run_capture(repo, "list", env={"CAPTURE_PROFILES_DIR": str(pdir)})
            assert res.returncode == 0, res.stderr
            assert res.stdout.rstrip("\n").split("\n") == [
                f"{profile_id}\t{prof['bundle_id']}\t{','.join(names)}"
            ]
        finally:
            shutil.rmtree(pdir, ignore_errors=True)

    check()
