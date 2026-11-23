"""Property 21: Unknown profile or scenario creates nothing.

For any profile name or scenario name that is not declared in the loaded
profiles, `capture.sh run` (and `prompt`) exits non-zero before any step,
prints a message naming the unknown value, calls no external binary, and the
captures/ tree is unchanged.

**Validates: Requirements 12.2**
"""

from __future__ import annotations

from pathlib import Path

from hypothesis import given, strategies as st

from conftest import Repo, profile_ids, run_capture, scenario_names

SUBCOMMANDS = st.sampled_from(["run", "prompt"])
EXTRA_FLAGS = st.sampled_from([[], ["--dry-run"], ["--no-video"], ["--keep-going"]])


def _usable(sub: str, flags: list[str]) -> list[str]:
    """--keep-going is only valid for run."""
    return [] if sub == "prompt" and "--keep-going" in flags else flags


def _tree(root: Path) -> list[tuple[str, bytes | None]]:
    """Every path under root with file contents, for exact comparison."""
    out: list[tuple[str, bytes | None]] = []
    for p in sorted(root.rglob("*")):
        rel = str(p.relative_to(root))
        out.append((rel, p.read_bytes() if p.is_file() and not p.is_symlink() else None))
    return out


def _declared(repo: Repo) -> dict[str, list[str]]:
    """Profile id -> scenario names, read from the copied profile files."""
    result: dict[str, list[str]] = {}
    for path in sorted(repo.profiles_dir.glob("*.profile")):
        scenarios: list[str] = []
        for line in path.read_text().splitlines():
            line = line.strip()
            if line.startswith("scenario.") and "=" in line:
                name = line.split("=", 1)[0].strip().split(".")[1]
                if name not in scenarios:
                    scenarios.append(name)
        result[path.stem] = scenarios
    return result


def _assert_rejected(repo: Repo, before, proc, value: str) -> None:
    assert proc.returncode == 2, (proc.returncode, proc.stderr)
    assert value in proc.stderr + proc.stdout
    assert _tree(repo.root) == before
    assert not any(repo.captures_dir.iterdir())
    assert repo.calls() == []


@given(
    data=st.data(),
    sub=SUBCOMMANDS,
    flags=EXTRA_FLAGS,
)
def test_unknown_profile_creates_nothing(repo: Repo, data, sub, flags) -> None:
    declared = _declared(repo)
    assert declared, "harness copy has no profiles"
    unknown = data.draw(profile_ids.filter(lambda v: v not in declared))
    scenario = data.draw(
        st.one_of(
            scenario_names,
            st.sampled_from([s for ss in declared.values() for s in ss]),
        )
    )
    repo.call_log.unlink(missing_ok=True)
    before = _tree(repo.root)
    proc = run_capture(repo, sub, unknown, scenario, *_usable(sub, flags))
    _assert_rejected(repo, before, proc, unknown)


@given(
    data=st.data(),
    sub=SUBCOMMANDS,
    flags=EXTRA_FLAGS,
)
def test_unknown_scenario_creates_nothing(repo: Repo, data, sub, flags) -> None:
    declared = _declared(repo)
    profile = data.draw(st.sampled_from(sorted(declared)))
    unknown = data.draw(scenario_names.filter(lambda v: v not in declared[profile]))
    repo.call_log.unlink(missing_ok=True)
    before = _tree(repo.root)
    proc = run_capture(repo, sub, profile, unknown, *_usable(sub, flags))
    _assert_rejected(repo, before, proc, unknown)
