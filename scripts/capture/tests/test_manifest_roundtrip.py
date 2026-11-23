"""Property 11: Manifest JSON round trip.

**Validates: Requirements 11.8**

For any manifest written by manifest_write (including quotes, backslashes,
control characters and Unicode in `error`), parsing manifest.json and
re-serializing it with json.js reserialize yields a document with equal keys
and values.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from hypothesis import given, strategies as st

from conftest import CAPTURE_SRC, Repo, manifests, run_bash

# Real lib/manifest.sh and real osascript (no stubs, no permissions).
_REAL = Repo(root=CAPTURE_SRC.parent.parent, call_log=Path("/dev/null"))

# Args: dir, then key/value pairs. Key "@artifact" adds an artifact name.
_WRITE = r"""
dir="$1"; shift
export CAPTURE_MANIFEST_TMP="$dir/scratch"
manifest_reset
while [ "$#" -ge 2 ]; do
  if [ "$1" = "@artifact" ]; then manifest_add_artifact "$2" || exit 11
  else manifest_set "$1" "$2" || exit 12; fi
  shift 2
done
manifest_write "$dir" || exit 13
manifest_roundtrip "$dir/manifest.json"
"""

# Error text with quotes, backslashes, control characters (not NUL) and Unicode.
_error_text = st.text(
    alphabet=st.one_of(
        st.characters(blacklist_categories=("Cs",), blacklist_characters="\x00"),
        st.sampled_from(list('"\\\n\r\t\x01\x1f\x7f/\'') + ["\u2028", "\U0001f47b", "\u00e9"]),
    ),
    min_size=1,
    max_size=1000,
)


def _scalar(v: object) -> str:
    if v is True:
        return "true"
    if v is False:
        return "false"
    return v if isinstance(v, str) else repr(v)


def _flatten(prefix: str, obj: dict, out: list[str]) -> None:
    for k, v in obj.items():
        key = f"{prefix}{k}"
        if isinstance(v, dict):
            _flatten(key + ".", v, out)
        elif key == "artifacts" or v is None:
            continue
        else:
            out += [key, _scalar(v)]


def _args(m: dict) -> list[str]:
    args: list[str] = []
    _flatten("", m, args)
    for name in m["artifacts"]:
        args += ["@artifact", name]
    return args


@st.composite
def written_manifests(draw) -> dict:
    m = draw(manifests())
    if m["outcome"] != "ok":
        m["error"] = draw(_error_text)
    return m


@given(m=written_manifests())
def test_manifest_json_round_trip(m: dict) -> None:
    with tempfile.TemporaryDirectory() as d:
        r = run_bash(_REAL, _WRITE, d, *_args(m), libs=("manifest",), stubs=False)
        assert r.returncode == 0, (r.returncode, r.stdout, r.stderr)

        path = Path(d) / "manifest.json"
        original = json.loads(path.read_text(encoding="utf-8"))
        again = subprocess.run(
            [
                "osascript",
                "-l",
                "JavaScript",
                str(CAPTURE_SRC / "lib" / "json.js"),
                "reserialize",
                str(path),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        reserialized = json.loads(again.stdout)

        assert reserialized == original
        assert list(reserialized) == list(original) or set(reserialized) == set(original)
        # The written document also keeps what the caller supplied.
        for key in ("profile_id", "bundle_id", "scenario", "mode", "outcome", "error"):
            assert original[key] == m[key]
        assert original["artifacts"] == m["artifacts"]
