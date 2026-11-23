"""Property 15: Prompt text classification.

**Validates: Requirements 6.7**

Drives classify_prompt in lib/windows.sh through bash with values passed as
argv. The oracle reads lib/services.tbl directly.
"""
from __future__ import annotations

from pathlib import Path

from hypothesis import given, strategies as st

from conftest import CAPTURE_SRC, Repo, prompt_text, run_bash

TBL = CAPTURE_SRC / "lib" / "services.tbl"


def _load_table() -> dict[str, list[str]]:
    table: dict[str, list[str]] = {}
    for line in TBL.read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        service, _, kws = line.partition("\t")
        table[service] = [k for k in kws.split(",") if k]
    return table


TABLE = _load_table()
SERVICES = sorted(TABLE)


def _ascii_lower(s: str) -> str:
    return "".join(chr(ord(c) + 32) if "A" <= c <= "Z" else c for c in s)


def expected(text: str, service: str) -> str:
    if text == "" or service not in TABLE:
        return "unknown"
    lower = _ascii_lower(text)
    return "true" if any(_ascii_lower(k) in lower for k in TABLE[service]) else "false"


def classify(repo: Repo, text: str, service: str) -> str:
    result = run_bash(
        repo,
        'classify_prompt "$1" "$2"',
        text,
        service,
        libs=("common", "defaults", "windows"),
        env={"LC_ALL": "C"},
    )
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def _mixed_case(draw, s: str) -> str:
    flags = draw(st.lists(st.booleans(), min_size=len(s), max_size=len(s)))
    return "".join(c.upper() if f else c.lower() for c, f in zip(s, flags))


@st.composite
def text_with_keyword(draw):
    service = draw(st.sampled_from(SERVICES))
    kw = draw(st.sampled_from(TABLE[service]))
    pre = draw(st.text(alphabet="abc xyz.,'\"", max_size=20))
    post = draw(st.text(alphabet="abc xyz.,'\"", max_size=20))
    return service, pre + _mixed_case(draw, kw) + post


unknown_services = st.one_of(
    st.just("NotAService"),
    st.text(alphabet="abcXYZ_09", min_size=1, max_size=20),
).filter(lambda s: s not in TABLE)


@given(text=prompt_text, service=st.sampled_from(SERVICES))
def test_matches_oracle_for_known_services(repo, text, service):
    assert classify(repo, text, service) == expected(text, service)


@given(data=text_with_keyword())
def test_keyword_in_any_case_is_true(repo, data):
    service, text = data
    assert classify(repo, text, service) == "true"


@given(text=prompt_text, service=st.sampled_from(SERVICES), flags=st.data())
def test_result_independent_of_case(repo, text, service, flags):
    varied = _mixed_case(flags.draw, text)
    assert classify(repo, varied, service) == classify(repo, text, service)


@given(text=prompt_text, service=unknown_services)
def test_unknown_service_is_unknown(repo, text, service):
    assert classify(repo, text, service) == "unknown"


@given(service=st.sampled_from(SERVICES) | unknown_services)
def test_empty_text_is_unknown(repo, service):
    assert classify(repo, "", service) == "unknown"
