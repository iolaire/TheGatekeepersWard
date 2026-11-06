"""Unit tests for HeaderReader (Task 3.2)."""
from __future__ import annotations

from pathlib import Path

import pytest

from header_reader import HeaderContent, HeaderNotFoundError, HeaderReader
from sdk_locator import SDKPath


@pytest.fixture()
def fake_sdk(tmp_path: Path) -> SDKPath:
    include = tmp_path / "usr" / "include"
    (include / "sys").mkdir(parents=True)
    (include / "sys" / "sysctl.h").write_text("#define KERN_PROCARGS2 49\n", encoding="utf-8")
    (include / "sys" / "proc_info.h").write_text("struct proc_vnodepathinfo {};\n", encoding="utf-8")
    return SDKPath(root=tmp_path, used_fallback=False)


class TestHeaderReader:
    def test_read_returns_content(self, fake_sdk: SDKPath):
        reader = HeaderReader(fake_sdk)
        content = reader.read("sys/sysctl.h")
        assert isinstance(content, HeaderContent)
        assert "KERN_PROCARGS2" in content.text
        assert content.source_path == str(fake_sdk.root / "usr/include/sys/sysctl.h")
        assert content.used_fallback is False

    def test_used_fallback_mirrors_sdk(self, tmp_path: Path):
        sdk = SDKPath(root=tmp_path, used_fallback=True)
        (tmp_path / "usr" / "include").mkdir(parents=True)
        (tmp_path / "usr" / "include" / "a.h").write_text("int x;\n", encoding="utf-8")
        reader = HeaderReader(sdk)
        assert reader.read("a.h").used_fallback is True

    def test_missing_file_raises_with_path(self, fake_sdk: SDKPath):
        reader = HeaderReader(fake_sdk)
        with pytest.raises(HeaderNotFoundError) as exc:
            reader.read("sys/does_not_exist.h")
        assert str(fake_sdk.root / "usr/include/sys/does_not_exist.h") in str(exc.value)
        assert exc.value.path.endswith("does_not_exist.h")

    def test_lru_cache_returns_same_object(self, fake_sdk: SDKPath, monkeypatch):
        # Second read of same path returns same object without second disk read
        reader = HeaderReader(fake_sdk)
        first = reader.read("sys/sysctl.h")
        second = reader.read("sys/sysctl.h")
        assert first is second
        info = reader._cached_read.cache_info()
        assert info.hits >= 1

    def test_read_absolute(self, fake_sdk: SDKPath):
        reader = HeaderReader(fake_sdk)
        abs_path = fake_sdk.root / "usr" / "include" / "sys" / "proc_info.h"
        content = reader.read_absolute(abs_path)
        assert "proc_vnodepathinfo" in content.text
