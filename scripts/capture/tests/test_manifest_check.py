"""Property 10: Manifest validity.

**Validates: Requirements 11.1, 11.2, 11.5**

manifest_check accepts a manifest if and only if: outcome is one of ok,
no_prompt, no_hud, error; artifacts hold 0 to 50 plain relative names;
timestamps are UTC ISO-8601; ward_commit is present only in ward mode and is
40 lowercase hex characters or "unknown"; failed_step and error are set exactly
when outcome is not ok, with error 1 to 1000 characters. Truncating a longer
error text to 1000 characters produces a text that passes.
"""

from __future__ import annotations

import copy
import json
import tempfile
from pathlib import Path

from hypothesis import given, strategies as st

from conftest import CAPTURE_SRC, Repo, manifests, run_bash

# Runs the real lib/manifest.sh and the real osascript (no stubs, no permissions).
_REAL = Repo(root=CAPTURE_SRC.parent.parent, call_log=Path("/dev/null"))
_SNIPPET = 'manifest_check "$1"'


def check(manifest: object) -> bool:
    """True when manifest_check accepts the manifest (exit 0, no output)."""
    with tempfile.TemporaryDirectory() as d:
        path = Path(d) / "manifest.json"
        path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        r = run_bash(_REAL, _SNIPPET, str(path), libs=("manifest",), stubs=False)
    if r.returncode == 0:
        assert r.stdout == "" and r.stderr == ""
        return True
    assert r.stderr.startswith("manifest_check: ")
    return False


def _set(key, value):
    def apply(m):
        m[key] = value
    return apply


def _bad_artifact(m):
    m["artifacts"] = m["artifacts"][:49] + ["dir/file.png"]


def _too_many(m):
    m["artifacts"] = [f"f{i}.png" for i in range(51)]


def _drop(key):
    def apply(m):
        m.pop(key, None)
    return apply


def _ok_with_failure(m):
    m["outcome"] = "ok"
    m["failed_step"] = "preflight"
    m["error"] = "boom"


def _fail_without_error(m):
    if m["outcome"] == "ok":
        m["outcome"] = "error"
        m["failed_step"] = "preflight"
    m["error"] = None


def _fail_without_step(m):
    if m["outcome"] == "ok":
        m["outcome"] = "error"
        m["error"] = "boom"
    m["failed_step"] = None


def _fail_empty_error(m):
    if m["outcome"] == "ok":
        m["outcome"] = "error"
        m["failed_step"] = "preflight"
    m["error"] = ""


def _fail_long_error(m):
    if m["outcome"] == "ok":
        m["outcome"] = "error"
        m["failed_step"] = "preflight"
    m["error"] = "x" * 1001


def _baseline_with_commit(m):
    m["mode"] = "baseline"
    m["ward_commit"] = "a" * 40


def _ward_without_commit(m):
    m["mode"] = "ward"
    m.pop("ward_commit", None)


def _ward_bad_commit(bad):
    def apply(m):
        m["mode"] = "ward"
        m["ward_commit"] = bad
    return apply


INVALID_MUTATIONS = [
    _set("outcome", "success"),
    _set("outcome", "OK"),
    _set("outcome", None),
    _set("started_at", "2026-11-09 10:00:00"),
    _set("ended_at", "2026-11-09T10:00:00+00:00"),
    _set("ended_at", "2026-13-09T10:00:00Z"),
    _set("started_at", "2026-11-09T10:00:00"),
    _set("mode", "other"),
    _drop("started_at"),
    _drop("artifacts"),
    _drop("outcome"),
    _set("artifacts", "a.png"),
    _bad_artifact,
    _too_many,
    _set("artifacts", [".."]),
    _ok_with_failure,
    _fail_without_error,
    _fail_without_step,
    _fail_empty_error,
    _fail_long_error,
    _baseline_with_commit,
    _ward_without_commit,
    _ward_bad_commit("A" * 40),
    _ward_bad_commit("a" * 39),
    _ward_bad_commit("a" * 41),
    _ward_bad_commit("g" * 40),
    _ward_bad_commit("Unknown"),
    _ward_bad_commit(None),
]


@given(manifests())
def test_generated_manifests_are_accepted(m):
    assert check(m)


@given(manifests(), st.integers(0, len(INVALID_MUTATIONS) - 1))
def test_each_clause_violation_is_rejected(m, idx):
    mutated = copy.deepcopy(m)
    INVALID_MUTATIONS[idx](mutated)
    assert not check(mutated)


@given(
    manifests(),
    st.integers(0, 50),
    st.integers(1, 1000),
    st.integers(1, 500),
)
def test_boundaries_and_error_truncation(m, n_artifacts, error_len, extra):
    # 0 to 50 artifacts are accepted.
    m["artifacts"] = [f"a{i}.png" for i in range(n_artifacts)]
    assert check(m)

    # Error text of 1 to 1000 characters passes when outcome is not ok.
    m["outcome"] = "error"
    m["failed_step"] = "screenshots"
    m["error"] = "\U0001f47b" * error_len
    assert check(m)

    # A longer text fails; truncated to 1000 characters it passes.
    long_text = "\U0001f47b" * (1000 + extra)
    m["error"] = long_text
    assert not check(m)
    m["error"] = long_text[:1000]
    assert check(m)
