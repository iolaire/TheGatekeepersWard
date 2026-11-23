"""Property 7: Argument quoting is lossless.

**Validates: Requirements 13.10**

For any string without NUL, quote_cmd of a command that includes it, evaluated
by bash, yields an argv whose element equals the original and runs no extra
command. The same string passed through ext to a stub osascript is logged as
exactly one argv element equal to the original.
"""

from __future__ import annotations

from pathlib import Path

from hypothesis import given, settings, strategies as st

from conftest import Repo, argv_text, make_repo, run_bash

# Strings dense in shell metacharacters, to hit injection paths more often.
_NASTY = "'\"\\ $`;&|<>(){}[]*?!#~%\n\r\t\x0b\x0c\x1b\x01\x7f-=:/\u2019\u00e9\u4e2d\U0001f47b"
nasty_text = st.text(alphabet=st.sampled_from(list(_NASTY)), min_size=0, max_size=40)
injection_text = st.sampled_from(
    [
        "'; touch {m}; '",
        "$(touch {m})",
        "`touch {m}`",
        "\ntouch {m}\n",
        "; touch {m} ;",
        "&& touch {m}",
        "| touch {m}",
        "\"; touch {m}; \"",
    ]
)
any_text = st.one_of(argv_text, nasty_text)

# Evaluate quote_cmd output as a command: `dump` writes each argv element
# NUL-terminated to the file "$1". `$MARK` must not appear afterwards.
_EVAL_SNIPPET = r"""
out="$1"; MARK="$2"; shift 2
: >"$out"
dump() { local a; for a in "$@"; do printf '%s\0' "$a" >>"$out"; done; }
q="$(quote_cmd dump "$@"; printf x)"
q="${q%x}"
eval "$q"
"""


def _eval_argv(repo: Repo, tmp: Path, values: list[str]) -> tuple[list[str], bool]:
    out = tmp / "argv.out"
    mark = tmp / "injected"
    mark.unlink(missing_ok=True)
    values = [v.replace("{m}", str(mark)) for v in values]
    proc = run_bash(repo, _EVAL_SNIPPET, str(out), str(mark), *values, stubs=False)
    assert proc.returncode == 0, proc.stderr
    raw = out.read_bytes().decode("utf-8", errors="surrogateescape")
    got = raw.split("\0")[:-1] if raw else []
    return got, mark.exists()


@given(values=st.lists(any_text, min_size=1, max_size=5))
def test_quote_cmd_roundtrips_argv(tmp_path_factory, values):
    tmp = tmp_path_factory.mktemp("q")
    repo = make_repo(tmp)
    got, injected = _eval_argv(repo, tmp, values)
    assert got == values
    assert not injected


@given(payload=injection_text, extra=nasty_text)
def test_quote_cmd_runs_no_extra_command(tmp_path_factory, payload, extra):
    tmp = tmp_path_factory.mktemp("q")
    repo = make_repo(tmp)
    got, injected = _eval_argv(repo, tmp, [payload + extra])
    assert got == [(payload + extra).replace("{m}", str(tmp / "injected"))]
    assert not injected


@given(message=any_text.filter(lambda s: "\r" not in s))
def test_ext_passes_message_as_one_argv_element(tmp_path_factory, message):
    tmp = tmp_path_factory.mktemp("q")
    repo = make_repo(tmp)
    proc = run_bash(
        repo,
        'ext osascript -e \'on run argv\' -e \'end run\' "$1"',
        message,
    )
    assert proc.returncode == 0, proc.stderr
    calls = repo.calls("osascript")
    assert len(calls) == 1
    assert calls[0] == ["osascript", "-e", "on run argv", "-e", "end run", message]


@given(message=any_text)
def test_dry_run_output_evaluates_to_original(tmp_path_factory, message):
    """The dry-run line "+ <quoted command>" re-evaluates to the same argv."""
    tmp = tmp_path_factory.mktemp("q")
    repo = make_repo(tmp)
    out = tmp / "argv.out"
    snippet = r"""
out="$1"; shift
dump() { local a; for a in "$@"; do printf '%s\0' "$a" >>"$out"; done; }
CAPTURE_DRY_RUN=1
line="$(ext dump "$1"; printf x)"
line="${line%x}"
line="${line#+ }"
line="${line%$'\n'}"
: >"$out"
eval "$line"
"""
    proc = run_bash(repo, snippet, str(out), message, stubs=False)
    assert proc.returncode == 0, proc.stderr
    raw = out.read_bytes().decode("utf-8", errors="surrogateescape")
    assert raw.split("\0")[:-1] == [message]
