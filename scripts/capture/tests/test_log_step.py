"""Property 23: Step log line.

For any step name, log_step prints a line that contains the step name and a UTC
timestamp with at least one-second resolution, and the line appended to
capture.log is identical to the printed line.

**Validates: Requirements 12.9**
"""
from __future__ import annotations

import re
import shutil

from hypothesis import given, strategies as st

from conftest import prompt_text, run_bash

SNIPPET = 'SESSION_DIR="$1"; CAPTURE_DRY_RUN="${2:-}"; log_step "$3"'
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z ")

step_names = st.one_of(
    st.sampled_from(
        [
            "preflight",
            "app-launch",
            "prompt-detection",
            "screenshots",
            "recording-start",
            "reset",
        ]
    ),
    st.text(
        alphabet=st.characters(blacklist_categories=("Cc", "Cs", "Zl", "Zp")),
        min_size=1,
        max_size=60,
    ),
    prompt_text,
)


@given(name=step_names)
def test_log_step_line_has_timestamp_name_and_matches_log(repo, name):
    session = repo.root / "captures" / "session"
    if session.exists():
        shutil.rmtree(session)
    session.mkdir(parents=True)

    result = run_bash(repo, SNIPPET, str(session), "", name)

    assert result.returncode == 0, result.stderr
    assert result.stdout.endswith("\n")
    printed = result.stdout[:-1]
    assert "\n" not in printed
    assert TIMESTAMP.match(printed), printed
    assert name in printed
    logged = (session / "capture.log").read_text()
    assert logged == result.stdout


@given(name=step_names)
def test_log_step_dry_run_prints_but_does_not_write(repo, name):
    session = repo.root / "captures" / "session"
    if session.exists():
        shutil.rmtree(session)
    session.mkdir(parents=True)

    result = run_bash(repo, SNIPPET, str(session), "1", name)

    assert result.returncode == 0, result.stderr
    assert TIMESTAMP.match(result.stdout)
    assert name in result.stdout
    assert not (session / "capture.log").exists()
