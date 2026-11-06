"""Unit tests for SDKLocator (Task 2.2)."""
from __future__ import annotations

import subprocess
from pathlib import Path
from unittest.mock import patch

import pytest

import sdk_locator
from sdk_locator import FALLBACK_SDK_PATH, SDKLocator, SDKPath, SDKUnavailableError


def _run_result(stdout: str) -> subprocess.CompletedProcess:
    return subprocess.CompletedProcess(args=[], returncode=0, stdout=stdout, stderr="")


class TestSDKLocator:
    def test_xcrun_success(self, tmp_path):
        # Normal xcrun success path (mock subprocess.run)
        locator = SDKLocator()
        with patch("sdk_locator.subprocess.run", return_value=_run_result(f"{tmp_path}\n")) as m:
            sdk = locator.locate()
        assert sdk.root == tmp_path
        assert sdk.used_fallback is False
        m.assert_called_once()
        assert m.call_args.kwargs["timeout"] == 5.0

    def test_xcrun_timeout_falls_back(self):
        # xcrun timeout -> fallback path used, used_fallback=True
        locator = SDKLocator()
        with patch(
            "sdk_locator.subprocess.run",
            side_effect=subprocess.TimeoutExpired(cmd=[], timeout=5),
        ):
            sdk = locator.locate()
        assert sdk.root == FALLBACK_SDK_PATH
        assert sdk.used_fallback is True

    def test_xcrun_error_falls_back(self):
        # xcrun non-zero exit -> fallback path used
        locator = SDKLocator()
        with patch(
            "sdk_locator.subprocess.run",
            side_effect=subprocess.CalledProcessError(1, []),
        ):
            sdk = locator.locate()
        assert sdk.root == FALLBACK_SDK_PATH
        assert sdk.used_fallback is True

    def test_xcrun_missing_binary_falls_back(self):
        locator = SDKLocator()
        with patch("sdk_locator.subprocess.run", side_effect=FileNotFoundError("xcrun")):
            sdk = locator.locate()
        assert sdk.used_fallback is True

    def test_both_paths_absent_raises(self):
        # Both xcrun paths absent -> SDKUnavailableError raised
        locator = SDKLocator()
        missing = Path("/nonexistent/SDKs/MacOSX.sdk")
        with patch(
            "sdk_locator.subprocess.run",
            side_effect=subprocess.TimeoutExpired(cmd=[], timeout=5),
        ), patch.object(sdk_locator, "FALLBACK_SDK_PATH", missing):
            with pytest.raises(SDKUnavailableError):
                locator.locate()

    def test_include_root(self):
        locator = SDKLocator()
        sdk = SDKPath(root=Path("/Fake/SDK"), used_fallback=False)
        assert locator.include_root(sdk) == Path("/Fake/SDK/usr/include")
