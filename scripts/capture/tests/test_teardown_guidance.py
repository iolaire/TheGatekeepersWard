"""Property 26: Teardown revoke guidance.

Feature: permission-capture-framework, Property 26: Teardown revoke guidance
**Validates: Requirements 2.4**
"""
from __future__ import annotations

from hypothesis import given, settings
from hypothesis import strategies as st

from conftest import run_bash

PERMS = [
    "accessibility",
    "screen-recording",
    "automation-system-events",
    "automation-finder",
    "full-disk-access",
]
PANES = {
    "accessibility": "Privacy_Accessibility",
    "screen-recording": "Privacy_ScreenCapture",
    "automation-system-events": "Privacy_Automation",
    "automation-finder": "Privacy_Automation",
    "full-disk-access": "Privacy_AllFiles",
}

# Any Setup_State_File: any subset of the five permissions, each true or false.
states = st.dictionaries(st.sampled_from(PERMS), st.booleans(), max_size=5)


def render(state: dict) -> str:
    lines = [f'  "{k}": {"true" if v else "false"}' for k, v in state.items()]
    return "{\n" + ",\n".join(lines) + "\n}\n"


@settings(deadline=None)
@given(state=states)
def test_teardown_revoke_guidance(repo, tmp_path_factory, state):
    state_dir = tmp_path_factory.mktemp("state")
    (state_dir / "setup.json").write_text(render(state))
    res = run_bash(
        repo,
        "cleanup_all",
        libs=("common", "defaults", "setup", "cleanup"),
        env={"CAPTURE_STATE_DIR": str(state_dir)},
        stdin="",
        timeout=60,
    )
    assert res.returncode == 0, res.stderr
    lines = [ln for ln in res.stdout.splitlines() if ln.startswith("revoke ")]
    missing = [n for n in PERMS if state.get(n) is False]
    assert len(lines) == len(missing)
    for name, line in zip(missing, lines):
        assert name in line
        assert PANES[name] in line
    # No line mentions a permission recorded as already granted or not recorded.
    for name in PERMS:
        if state.get(name) is not False:
            assert not any(f"revoke {name} " in ln for ln in lines)
