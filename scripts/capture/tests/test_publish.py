"""Tests for lib/publish.sh and prepare_action.

publish_session copies a session's images, videos and manifest to
<assets>/<profile>/<mode>_<profile>_<scenario>_<file>, replaces the earlier
version, and never publishes capture.log or tcc-snapshot.json.
"""

from __future__ import annotations

from pathlib import Path

from hypothesis import given, settings
from hypothesis import strategies as st

from conftest import Repo, make_repo, profile_ids, run_bash, scenario_names

LIBS = ("common", "defaults", "publish")


def _session(root: Path, files: dict[str, str]) -> Path:
    d = root / "captures" / "20260101T000000Z" / "deepseek-harness" / "desktop" / "baseline"
    d.mkdir(parents=True)
    for name, body in files.items():
        (d / name).write_text(body)
    return d


def _publish(repo: Repo, session: Path, mode: str = "baseline", dry: bool = False):
    env = {"CAPTURE_PUBLISH_DIR": str(repo.root / "assets"), "CAPTURE_DRY_RUN": "1" if dry else "0"}
    return run_bash(repo, 'publish_session "$1" deepseek-harness desktop "$2"', str(session), mode,
                    libs=LIBS, env=env, stdin="", timeout=60)


def test_names_and_selection(repo: Repo) -> None:
    s = _session(repo.root, {"prompt.png": "p", "screen.png": "s", "flow.mov": "v", "manifest.json": "{}",
                             "capture.log": "log", "tcc-snapshot.json": "rows", "hud.tmp.png": "t"})
    res = _publish(repo, s)
    assert res.returncode == 0, res.stderr
    out = repo.root / "assets" / "deepseek-harness"
    assert sorted(p.name for p in out.iterdir()) == [
        "baseline_deepseek_harness_desktop_flow.mov",
        "baseline_deepseek_harness_desktop_manifest.json",
        "baseline_deepseek_harness_desktop_prompt.png",
        "baseline_deepseek_harness_desktop_screen.png",
    ]
    assert (out / "baseline_deepseek_harness_desktop_prompt.png").read_text() == "p"
    assert "(4 files)" in res.stdout


def test_new_version_replaces_old_and_keeps_other_modes(repo: Repo) -> None:
    out = repo.root / "assets" / "deepseek-harness"
    out.mkdir(parents=True)
    (out / "baseline_deepseek_harness_desktop_hud.png").write_text("stale")
    (out / "ward_deepseek_harness_desktop_hud.png").write_text("ward")
    (out / "baseline_deepseek_harness_removable_volume_prompt.png").write_text("other scenario")
    s = _session(repo.root, {"prompt.png": "new"})
    assert _publish(repo, s).returncode == 0
    names = sorted(p.name for p in out.iterdir())
    assert "baseline_deepseek_harness_desktop_hud.png" not in names
    assert "ward_deepseek_harness_desktop_hud.png" in names
    assert "baseline_deepseek_harness_removable_volume_prompt.png" in names
    assert (out / "baseline_deepseek_harness_desktop_prompt.png").read_text() == "new"


def test_dry_run_writes_nothing(repo: Repo) -> None:
    s = _session(repo.root, {"prompt.png": "p"})
    res = _publish(repo, s, dry=True)
    assert res.returncode == 0
    assert "would publish to" in res.stdout
    assert not (repo.root / "assets").exists()


def test_summary_links_point_at_published_names(repo: Repo) -> None:
    sdir = repo.root / "captures" / "ts" / "deepseek-harness" / "desktop"
    sdir.mkdir(parents=True)
    (sdir / "summary.md").write_text(
        "| Baseline | Ward |\n| --- | --- |\n"
        "| [capture.log](baseline/capture.log) | [capture.log](ward/capture.log) |\n"
        "| [prompt.png](baseline/prompt.png) | [hud.png](ward/hud.png) |\n")
    env = {"CAPTURE_PUBLISH_DIR": str(repo.root / "assets")}
    res = run_bash(repo, 'publish_summary "$1" deepseek-harness desktop', str(sdir), libs=LIBS,
                   env=env, stdin="", timeout=60)
    assert res.returncode == 0, res.stderr
    text = (repo.root / "assets" / "deepseek-harness" / "deepseek_harness_desktop_summary.md").read_text()
    assert "(baseline_deepseek_harness_desktop_prompt.png)" in text
    assert "(ward_deepseek_harness_desktop_hud.png)" in text
    assert "capture.log" not in text
    assert len([l for l in text.splitlines() if l.startswith("|")]) == 3  # header, separator, one row


def test_cleanup_removes_session_and_empty_parents_only(repo: Repo) -> None:
    s = _session(repo.root, {"prompt.png": "p"})
    keep = s.parent.parent / "removable-volume" / "baseline"
    keep.mkdir(parents=True)
    res = run_bash(repo, 'publish_cleanup "$1"', str(s), libs=LIBS, stdin="", timeout=60)
    assert res.returncode == 0, res.stderr
    assert not s.exists() and not s.parent.exists()
    assert keep.exists()


def test_cleanup_refuses_paths_outside_captures(repo: Repo, tmp_path: Path) -> None:
    outside = tmp_path / "elsewhere" / "a" / "b" / "c"
    outside.mkdir(parents=True)
    res = run_bash(repo, 'publish_cleanup "$1"', str(outside), libs=LIBS, stdin="", timeout=60)
    assert res.returncode == 1
    assert outside.exists()


@settings(deadline=None)
@given(mode=st.sampled_from(["baseline", "ward"]), profile=profile_ids, scenario=scenario_names)
def test_prefix_has_no_dashes_and_keeps_parts(mode: str, profile: str, scenario: str) -> None:
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        repo = make_repo(Path(tmp))
        res = run_bash(repo, 'publish_prefix "$1" "$2" "$3"', mode, profile, scenario,
                       libs=LIBS, stdin="", timeout=60)
        assert res.returncode == 0
        prefix = res.stdout.strip()
        assert prefix == f"{mode}_{profile.replace('-', '_')}_{scenario.replace('-', '_')}_"


_PROFILE = """profile_id = fake
display_name = Fake
bundle_id = com.example.fake
launch = open -b com.example.fake
input_locator = find:text area
send_action = key:return
scenario.one.prompt = hello
scenario.one.service = SystemPolicyDesktopFolder
"""


def test_prepare_action_clicks_before_focus(repo: Repo, tmp_path: Path) -> None:
    repo.write_profile("fake", _PROFILE + 'prepare_action = find:button "New Session"\n')
    env = {"CAPTURE_STATE_DIR": str(tmp_path / "state"), "STUB_OSASCRIPT_OUT": "ok"}
    res = run_bash(repo, "app_prepare fake && app_focus_input fake", libs=("common", "defaults", "app"),
                   env=env, stdin="", timeout=60)
    assert res.returncode == 0, res.stderr
    verbs = [c[2] for c in repo.calls("osascript") if len(c) > 2]
    assert verbs[:2] == ["send", "focus"], verbs
    send = next(c for c in repo.calls("osascript") if "send" in c)
    assert send[-2:] == ['find:button "New Session"', "10"]


def test_prepare_action_validation(repo: Repo) -> None:
    for value, ok in (('find:button "New Session"', True), ("ax:button 1 of window 1", True),
                      ("key:cmd+n", False), ("New Session", False)):
        path = repo.write_profile("fake", _PROFILE + f"prepare_action = {value}\n")
        res = run_bash(repo, 'profile_validate "$1"', str(path), libs=("common", "defaults", "validate", "profile"),
                       stdin="", timeout=60)
        assert (res.returncode == 0) == ok, (value, res.stderr)
