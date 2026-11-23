"""Property 27: Summary links match manifests.
**Validates: Requirements 11.6, 11.7**
write_summary must emit exactly one link per manifest artifact, pointing at
baseline/<name> or ward/<name>, and write nothing when a manifest is missing.
"""
from __future__ import annotations
import json
import re
import tempfile
from pathlib import Path
from hypothesis import given
from hypothesis import strategies as st
from conftest import file_names, make_repo, profile_ids, run_bash, scenario_names
_artifacts = st.lists(file_names, min_size=0, max_size=50, unique=True)
_SNIPPET = 'write_summary "$CAPTURE_REPO_ROOT" "$1" "$2" "$3"'
_LINK = re.compile(r"\[([^\]]*)\]\(((?:baseline|ward)/[^)]*)\)")
def _write_manifest(session: Path, mode: str, artifacts: list[str]) -> None:
    session.mkdir(parents=True, exist_ok=True)
    (session / "manifest.json").write_text(
        json.dumps({"mode": mode, "artifacts": artifacts}, indent=2) + "\n"
    )
@given(
    baseline=_artifacts,
    ward=_artifacts,
    profile=profile_ids,
    scenario=scenario_names,
)
def test_summary_has_one_link_per_artifact(baseline, ward, profile, scenario):
    ts = "20270101T000000Z"
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        base = repo.captures_dir / ts / profile / scenario
        _write_manifest(base / "baseline", "baseline", baseline)
        _write_manifest(base / "ward", "ward", ward)
        result = run_bash(repo, _SNIPPET, ts, profile, scenario, libs=("common", "session"))
        assert result.returncode == 0, result.stderr
        text = (base / "summary.md").read_text()
        links = _LINK.findall(text)
        expected = [(n, f"baseline/{n}") for n in baseline] + [
            (n, f"ward/{n}") for n in ward
        ]
        assert sorted(links) == sorted(expected)
        assert len(links) == len(baseline) + len(ward)
@given(
    present=st.sampled_from(["baseline", "ward", "none"]),
    artifacts=_artifacts,
    profile=profile_ids,
    scenario=scenario_names,
)
def test_no_summary_when_a_manifest_is_missing(present, artifacts, profile, scenario):
    ts = "20270101T000000Z"
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        base = repo.captures_dir / ts / profile / scenario
        base.mkdir(parents=True)
        if present != "none":
            _write_manifest(base / present, present, artifacts)
        result = run_bash(repo, _SNIPPET, ts, profile, scenario, libs=("common", "session"))
        assert result.returncode != 0
        assert not (base / "summary.md").exists()
