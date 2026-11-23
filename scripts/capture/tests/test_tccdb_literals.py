"""Property 38: SQL literal construction is lossless.
**Validates: Requirements 13.12, 15.2**

For any string without NUL, evaluating `SELECT <sql_quote s>` in SQLite returns
exactly s. For c built as b:<hex>, `SELECT <cell_literal c>` returns the same
bytes; for t:<hex> the same text; for i:<n> the same integer; for n: NULL. For
any string that is not a well-formed cell, cell_literal refuses it and prints
no literal.

SQLite runs only on an in-memory database (":memory:"). No TCC database is
opened.
"""
from __future__ import annotations

import re
import sqlite3
from pathlib import Path

from hypothesis import given, settings, strategies as st

from conftest import Repo, argv_text, run_bash

INT64_MIN, INT64_MAX = -(2**63), 2**63 - 1

# Writes the function's stdout, stderr and status to files so no byte is
# changed by text-mode newline handling or command substitution.
_SNIPPET = r"""
out="$1"; fn="$2"; arg="$3"
"$fn" "$arg" >"$out/lit" 2>"$out/err"
printf '%s' "$?" >"$out/rc"
"""


def _call(repo: Repo, tmp: Path, fn: str, arg: str) -> tuple[int, bytes, bytes]:
    out = tmp / "out"
    out.mkdir(exist_ok=True)
    proc = run_bash(repo, _SNIPPET, str(out), fn, arg, libs=("common", "tccdb"), stubs=False)
    assert proc.returncode == 0, proc.stderr
    return (
        int((out / "rc").read_text()),
        (out / "lit").read_bytes(),
        (out / "err").read_bytes(),
    )


def _select(expr_sql: str) -> list[str]:
    """Evaluate `SELECT <columns>` on an in-memory database, one value per line."""
    # The Python module evaluates the literal exactly. The sqlite3 command-line
    # shell reads stdin line by line and drops the CR of a CRLF inside a quoted
    # literal, which would mask the property under test (see the task report).
    conn = sqlite3.connect(":memory:")
    try:
        row = conn.execute(expr_sql.rstrip(";")).fetchone()
    finally:
        conn.close()
    return ["|".join("" if v is None else str(v) for v in row)]


def _eval_literal(lit: bytes) -> tuple[str, str]:
    """Return (typeof, hex of the value's bytes or the integer text)."""
    text = lit.decode("utf-8")
    rows = _select(
        f"SELECT typeof({text}), "
        f"CASE WHEN typeof({text})='integer' THEN {text} "
        f"WHEN typeof({text})='null' THEN '' "
        f"WHEN typeof({text})='text' THEN hex(CAST({text} AS BLOB)) "
        f"ELSE hex({text}) END;"
    )
    assert len(rows) == 1, rows
    kind, _, value = rows[0].partition("|")
    return kind, value


# --------------------------------------------------------------------------
# sql_quote
# --------------------------------------------------------------------------
_SQL_NASTY = "'\"`;\\%_ \t\n\r-/*()x"
quote_text = st.one_of(
    argv_text,
    st.text(alphabet=st.sampled_from(list(_SQL_NASTY)), min_size=0, max_size=40),
    st.sampled_from(["", "'", "''", "a'; DROP TABLE access; --", "\n", "trail\n\n", "'\n"]),
)


@given(s=quote_text)
def test_sql_quote_roundtrips_any_string(repo: Repo, tmp_path: Path, s: str) -> None:
    rc, lit, err = _call(repo, tmp_path, "sql_quote", s)
    assert rc == 0, err
    kind, value = _eval_literal(lit)
    assert kind == "text"
    assert value == s.encode("utf-8").hex().upper()


# --------------------------------------------------------------------------
# cell_literal: well-formed cells
# --------------------------------------------------------------------------
hex_bytes = st.one_of(st.just(b""), st.binary(min_size=1, max_size=64))
hex_case = st.sampled_from([str.lower, str.upper])


@given(data=hex_bytes, case=hex_case)
def test_cell_literal_blob(repo: Repo, tmp_path: Path, data: bytes, case) -> None:
    rc, lit, err = _call(repo, tmp_path, "cell_literal", "b:" + case(data.hex()))
    assert rc == 0, err
    assert _eval_literal(lit) == ("blob", data.hex().upper())


@given(
    data=st.one_of(
        st.binary(min_size=0, max_size=64),
        argv_text.map(lambda s: s.encode("utf-8")),
        st.just("it's \u4e2d\U0001f47b\n".encode("utf-8")),
    ),
    case=hex_case,
)
def test_cell_literal_text(repo: Repo, tmp_path: Path, data: bytes, case) -> None:
    rc, lit, err = _call(repo, tmp_path, "cell_literal", "t:" + case(data.hex()))
    assert rc == 0, err
    assert _eval_literal(lit) == ("text", data.hex().upper())


@given(n=st.integers(INT64_MIN, INT64_MAX))
def test_cell_literal_integer(repo: Repo, tmp_path: Path, n: int) -> None:
    rc, lit, err = _call(repo, tmp_path, "cell_literal", f"i:{n}")
    assert rc == 0, err
    assert _eval_literal(lit) == ("integer", str(n))


def test_cell_literal_integer_extremes(repo: Repo, tmp_path: Path) -> None:
    for n in (0, -1, INT64_MIN, INT64_MAX):
        rc, lit, err = _call(repo, tmp_path, "cell_literal", f"i:{n}")
        assert rc == 0, err
        assert _eval_literal(lit) == ("integer", str(n))


def test_cell_literal_null(repo: Repo, tmp_path: Path) -> None:
    rc, lit, err = _call(repo, tmp_path, "cell_literal", "n:")
    assert rc == 0, err
    assert lit == b"NULL"
    assert _eval_literal(lit) == ("null", "")


# --------------------------------------------------------------------------
# cell_literal: malformed cells are refused with no literal
# --------------------------------------------------------------------------
_INT = re.compile(r"-?[0-9]{1,19}")
_HEX = re.compile(r"(?:[0-9A-Fa-f]{2})*")


def _well_formed(cell: str) -> bool:
    tag, sep, body = cell.partition(":")
    if not sep:
        return False
    if tag == "n":
        return body == ""
    if tag == "i":
        return _INT.fullmatch(body) is not None and INT64_MIN <= int(body) <= INT64_MAX
    if tag in ("t", "b"):
        return _HEX.fullmatch(body) is not None
    return False


_CELL_CHARS = "itbnr:0123456789abcdefABCDEFgxG-+.' \";\n\t\\)("
malformed_cells = st.one_of(
    st.text(alphabet=st.sampled_from(list(_CELL_CHARS)), min_size=0, max_size=24),
    argv_text,
    st.builds(lambda h: "b:" + h, st.text(alphabet="0123456789abcdef", min_size=1, max_size=9).filter(lambda h: len(h) % 2 == 1)),
    st.builds(lambda h: "t:" + h, st.text(alphabet="0123456789abcdef", min_size=1, max_size=9).filter(lambda h: len(h) % 2 == 1)),
    st.sampled_from(
        [
            "", ":", "x", "n", "i", "i:", "i:-", "i:+1", "i:1.5", "i:1e3", "i:0x10",
            "i:1;DROP TABLE access", "i:1\n", "n:x", "n:NULL", "n:\n", "t:zz",
            "b:'", "t:41'; DROP TABLE access; --", "b:41\n", "r:41", "r:1.5", "r:",
            "I:1", "N:", "B:00", "T:00", "i:99999999999999999999",
            "i:9223372036854775808", "i:-9223372036854775809", "x:00", "b: 00",
        ]
    ),
)


@given(cell=malformed_cells)
def test_cell_literal_refuses_malformed(repo: Repo, tmp_path: Path, cell: str) -> None:
    rc, lit, _err = _call(repo, tmp_path, "cell_literal", cell)
    if _well_formed(cell):
        assert rc == 0
        assert lit != b""
    else:
        assert rc != 0, f"accepted {cell!r} as {lit!r}"
        assert lit == b""
