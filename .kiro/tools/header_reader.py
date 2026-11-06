"""Read header file text from the located macOS SDK, with an LRU cache."""
from __future__ import annotations

import functools
from dataclasses import dataclass
from pathlib import Path

from sdk_locator import SDKPath


class HeaderNotFoundError(Exception):
    """Raised when a header file is absent at the resolved SDK path."""

    def __init__(self, path: Path | str) -> None:
        self.path = str(path)
        super().__init__(f"Header file not found: {self.path}")


@dataclass(frozen=True)
class HeaderContent:
    text: str
    source_path: str
    used_fallback: bool


class HeaderReader:
    def __init__(self, sdk: SDKPath) -> None:
        self._sdk = sdk
        self._include_root = sdk.root / "usr" / "include"
        self._cached_read = functools.lru_cache(maxsize=128)(self._read_uncached)

    @property
    def sdk(self) -> SDKPath:
        return self._sdk

    def read(self, relative_path: str) -> HeaderContent:
        """Resolve ``<sdk_root>/usr/include/<relative_path>`` and read it."""
        return self.read_absolute(self._include_root / relative_path)

    def read_absolute(self, abs_path: Path) -> HeaderContent:
        """Read an arbitrary absolute path inside the SDK."""
        return self._cached_read(Path(abs_path))

    def _read_uncached(self, abs_path: Path) -> HeaderContent:
        if not abs_path.is_file():
            raise HeaderNotFoundError(abs_path)
        return HeaderContent(
            text=abs_path.read_text(encoding="utf-8", errors="replace"),
            source_path=str(abs_path),
            used_fallback=self._sdk.used_fallback,
        )
