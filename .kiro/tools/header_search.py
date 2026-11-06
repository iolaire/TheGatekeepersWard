"""Substring search across all .h files under the SDK's usr/include/."""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field
from pathlib import Path

from sdk_locator import SDKPath

SEARCH_TIMEOUT_S = 15.0


class SearchValidationError(Exception):
    """Raised for invalid search input; propagated as an MCP tool error."""

    def __init__(self, message: str) -> None:
        self.message = message
        super().__init__(message)


@dataclass
class SearchMatch:
    file: str           # absolute path
    line_number: int    # 1-indexed
    line_content: str
    context: list[str]  # up to 2 lines before + match + up to 2 after


@dataclass
class SearchResult:
    results: list[SearchMatch] = field(default_factory=list)
    total_matches: int = 0
    timed_out: bool = False


class HeaderSearchEngine:
    def __init__(self, sdk: SDKPath, timeout_s: float = SEARCH_TIMEOUT_S):
        self._sdk = sdk
        self._timeout_s = timeout_s
        self._stop = threading.Event()

    def search(self, keyword: str, max_results: int = 20) -> SearchResult:
        """Case-insensitive substring search across all .h files.

        keyword < 3 chars -> SearchValidationError. max_results outside
        [1, 100] -> SearchValidationError. Aborts after 15 s with
        timed_out=True and partial results.
        """
        if not isinstance(keyword, str) or len(keyword) < 3:
            raise SearchValidationError("keyword must be at least 3 characters")
        if not isinstance(max_results, int) or isinstance(max_results, bool) \
                or max_results < 1 or max_results > 100:
            raise SearchValidationError("max_results must be between 1 and 100")

        include_root = self._sdk.root / "usr" / "include"
        if not include_root.is_dir():
            raise SearchValidationError(f"SDK include directory does not exist: {include_root}")

        self._stop.clear()
        result = SearchResult()
        needle = keyword.lower()
        deadline = time.monotonic() + self._timeout_s

        try:
            paths = sorted(include_root.rglob("*.h"))
        except OSError as exc:
            raise SearchValidationError(f"cannot enumerate SDK headers: {exc}") from exc

        timed_out = False
        for path in paths:
            # Threading.Event stop flag checked at the top of each file
            # iteration, alongside the 15 s deadline clock.
            if self._stop.is_set():
                break
            if time.monotonic() >= deadline:
                timed_out = True
                break
            try:
                lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            except OSError:
                continue
            for idx, line in enumerate(lines):
                if time.monotonic() >= deadline:
                    timed_out = True
                    break
                if needle in line.lower():
                    result.total_matches += 1
                    if len(result.results) < max_results:
                        result.results.append(SearchMatch(
                            file=str(path),
                            line_number=idx + 1,
                            line_content=line,
                            context=lines[max(0, idx - 2): idx + 3],
                        ))
            if timed_out:
                break
        result.timed_out = timed_out
        return result

    def request_stop(self) -> None:
        """Cooperatively abort an in-flight search (e.g. on shutdown)."""
        self._stop.set()
