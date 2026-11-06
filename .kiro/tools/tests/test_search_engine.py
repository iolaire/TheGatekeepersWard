"""Unit and property-based tests for HeaderSearchEngine (Tasks 8.2–8.3)."""
from __future__ import annotations

import pytest
from hypothesis import given, settings
import hypothesis.strategies as st

from hypothesis import HealthCheck

from header_search import HeaderSearchEngine, SearchMatch, SearchResult, SearchValidationError


class TestValidation:
    def test_keyword_too_short_raises(self, fake_sdk):
        # keyword < 3 chars raises SearchValidationError
        engine = HeaderSearchEngine(sdk=fake_sdk)
        for kw in ("", "a", "ab"):
            with pytest.raises(SearchValidationError) as exc:
                engine.search(kw)
            assert "at least 3 characters" in str(exc.value)

    def test_max_results_zero_raises(self, fake_sdk):
        # max_results=0 raises SearchValidationError
        with pytest.raises(SearchValidationError) as exc:
            HeaderSearchEngine(sdk=fake_sdk).search("proc", max_results=0)
        assert "between 1 and 100" in str(exc.value)

    def test_max_results_over_100_raises(self, fake_sdk):
        # max_results=101 raises SearchValidationError
        with pytest.raises(SearchValidationError) as exc:
            HeaderSearchEngine(sdk=fake_sdk).search("proc", max_results=101)
        assert "between 1 and 100" in str(exc.value)


class TestSearch:
    def test_known_keyword_returns_match(self, fake_sdk):
        engine = HeaderSearchEngine(sdk=fake_sdk)
        result = engine.search("KERN_PROCARGS2")
        assert result.total_matches >= 1
        assert result.timed_out is False
        match = result.results[0]
        assert isinstance(match, SearchMatch)
        assert match.file.endswith("sysctl.h")
        assert match.line_number >= 1
        assert "KERN_PROCARGS2" in match.line_content
        assert match.line_content in match.context

    def test_context_has_up_to_two_lines_around_match(self, fake_sdk):
        engine = HeaderSearchEngine(sdk=fake_sdk)
        result = engine.search("KERN_PROCARGS2")
        match = result.results[0]
        assert len(match.context) <= 5
        assert match.line_content in match.context

    def test_case_insensitive(self, fake_sdk):
        engine = HeaderSearchEngine(sdk=fake_sdk)
        result = engine.search("kern_procargs2")
        assert result.total_matches >= 1

    def test_no_match_returns_empty(self, fake_sdk):
        # No-match keyword returns total_matches=0 and empty results
        result = HeaderSearchEngine(sdk=fake_sdk).search("zzzunfindablezzz")
        assert result.total_matches == 0
        assert result.results == []

    def test_max_results_limits_but_counts_all(self, fake_sdk):
        engine = HeaderSearchEngine(sdk=fake_sdk)
        full = engine.search("proc")
        limited = engine.search("proc", max_results=2)
        assert len(limited.results) <= 2
        assert limited.total_matches == full.total_matches

    def test_timeout_with_monkeypatched_clock(self, fake_sdk, monkeypatch):
        # 15-second timeout logic using a monkeypatched clock
        import header_search as hs
        clock = {"now": 0.0}

        def fake_monotonic():
            clock["now"] += 10.0  # every clock call advances past the deadline
            return clock["now"]

        monkeypatch.setattr(hs.time, "monotonic", fake_monotonic)
        engine = HeaderSearchEngine(sdk=fake_sdk, timeout_s=15.0)
        result = engine.search("proc")
        assert result.timed_out is True
        assert len(result.results) <= 20


# Feature: darwin-tcc-mcp-server, Property 6: Search Result Count Invariant
@given(
    st.integers(min_value=1, max_value=100),
    st.from_regex(r'[A-Za-z_]{3,20}', fullmatch=True),
)
@settings(max_examples=50, suppress_health_check=[HealthCheck.function_scoped_fixture])
def test_search_results_within_bounds(fake_sdk, max_results, keyword):
    # Property 6: Search Result Count Invariant (validates Req 7.4)
    engine = HeaderSearchEngine(sdk=fake_sdk)
    result = engine.search(keyword, max_results=max_results)
    assert len(result.results) <= max_results
    assert result.total_matches >= len(result.results)
