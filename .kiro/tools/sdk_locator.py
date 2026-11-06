"""Locate the active macOS SDK root via xcrun, with a CommandLineTools fallback."""
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path

FALLBACK_SDK_PATH = Path("/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")


class SDKUnavailableError(Exception):
    """Raised when neither xcrun nor the fallback SDK path is usable."""


@dataclass(frozen=True)
class SDKPath:
    root: Path
    used_fallback: bool


class SDKLocator:
    """Detects the macOS SDK root. Called once at startup and cached."""

    def __init__(self) -> None:
        self._last: SDKPath | None = None

    def locate(self, timeout_s: float = 5.0) -> SDKPath:
        """Run ``xcrun --sdk macosx --show-sdk-path``.

        On success return SDKPath(root=<path>, used_fallback=False). On xcrun
        timeout, CalledProcessError, or FileNotFoundError fall back to
        /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk. Raise
        SDKUnavailableError if the fallback path also does not exist.
        """
        try:
            proc = subprocess.run(
                ["xcrun", "--sdk", "macosx", "--show-sdk-path"],
                capture_output=True,
                text=True,
                timeout=timeout_s,
                check=True,
            )
            root = Path(proc.stdout.strip())
            if root.is_dir():
                self._last = SDKPath(root=root, used_fallback=False)
                return self._last
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError,
                FileNotFoundError, OSError):
            pass
        if FALLBACK_SDK_PATH.is_dir():
            self._last = SDKPath(root=FALLBACK_SDK_PATH, used_fallback=True)
            return self._last
        raise SDKUnavailableError(
            "macOS SDK unavailable: xcrun failed and fallback path does not "
            f"exist: {FALLBACK_SDK_PATH}"
        )

    def include_root(self, sdk: SDKPath | None = None) -> Path:
        """Return ``<sdk_root>/usr/include/`` for the given (or last located) SDK."""
        target = sdk or self._last
        if target is None:
            target = self.locate()
        return target.root / "usr" / "include"
