"""Unit and property-based tests for StructParser (Tasks 7.2–7.5)."""
from __future__ import annotations

import pytest
from hypothesis import given, settings
import hypothesis.strategies as st

from conftest import KNOWN_STRUCT_DEFINITIONS, UNION_CONTAINING_STRUCT_DEFINITIONS
from struct_parser import StructParseError, StructParser, format_fields_to_struct
from sdk_locator import FALLBACK_SDK_PATH


class _StubReader:
    class _Sdk:
        root = FALLBACK_SDK_PATH
    sdk = _Sdk()


@pytest.fixture()
def parser() -> StructParser:
    return StructParser(header_reader=_StubReader())


@pytest.fixture()
def strict_parser(parser: StructParser, monkeypatch) -> StructParser:
    """Parser that fails if the header-search path is ever entered."""
    def _no_search(name):
        raise AssertionError(f"header search invoked for {name!r}; known path must win")
    monkeypatch.setattr(parser, "_search_and_parse", _no_search)
    return parser


class TestKnownStructs:
    def test_all_five_known_structs_found_without_search(self, strict_parser):
        # All five known structs return found=True immediately (no header search)
        for name in ("proc_vnodepathinfo", "vnode_info_path", "kinfo_proc",
                     "extern_proc", "proc_bsdinfo"):
            result = strict_parser.get_struct(name)
            assert result.found is True
            assert result.fields
            assert result.arm64_byte_size > 0
            assert result.source_header.endswith(".h")

    def test_proc_vnodepathinfo_field_count_and_first_offset(self, parser):
        result = parser.get_struct("proc_vnodepathinfo")
        assert result.found is True
        assert len(result.fields) == 50
        first = result.fields[0]
        assert first.name == "pvi_cdir.vip_vi.vi_stat.vst_dev"
        assert first.byte_offset == 0
        assert first.c_type == "uint32_t"
        assert result.arm64_byte_size == 2352

    def test_dot_notation_for_nested_anonymous_structs(self, parser):
        result = parser.get_struct("vnode_info_path")
        names = [f.name for f in result.fields]
        assert "vip_vi.vi_stat.vst_dev" in names
        assert "vip_path" in names

    def test_union_members_share_offset_in_extern_proc(self, parser):
        result = parser.get_struct("extern_proc")
        union_fields = [f for f in result.fields if f.in_union]
        assert union_fields, "extern_proc must contain union members"
        offsets = {f.byte_offset for f in union_fields}
        assert offsets == {0}

    def test_empty_struct_name_returns_error(self, parser):
        # Empty struct name returns StructResult(found=False, error=...)
        for name in ("", "   ", "\t\n"):
            result = parser.get_struct(name)
            assert result.found is False
            assert result.error

    def test_invalid_c_text_raises_struct_parse_error(self, parser):
        # Invalid C text raises StructParseError
        for text in ("", "   ", "struct broken {", "not c at all",
                     "struct x { unknown_weird_type y; };"):
            with pytest.raises(StructParseError):
                parser.parse_struct_text(text)


class TestParseStructText:
    def test_returns_struct_fields(self, parser):
        fields = parser.parse_struct_text("struct s { int a; char b[4]; };")
        assert [f.name for f in fields] == ["a", "b"]
        assert fields[0].byte_offset == 0 and fields[0].byte_size == 4
        assert fields[1].byte_offset == 4 and fields[1].byte_size == 4

    def test_nested_anonymous_struct_dot_names(self, parser):
        fields = parser.parse_struct_text(
            "struct s { struct { int inner; } outer; int tail; };")
        assert [f.name for f in fields] == ["outer.inner", "tail"]


# Feature: darwin-tcc-mcp-server, Property 1: Struct Parse Round-Trip
@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_struct_parse_round_trip(struct_text):
    # Property 1: Struct Parse Round-Trip (validates Req 10.4)
    parser = StructParser(header_reader=_StubReader())
    fields_first = parser.parse_struct_text(struct_text)
    reconstructed = format_fields_to_struct(fields_first)
    fields_second = parser.parse_struct_text(reconstructed)
    assert fields_first == fields_second


# Feature: darwin-tcc-mcp-server, Property 7: Struct Fields Have Monotonically
# Non-Decreasing Offsets
@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_struct_field_offsets_non_decreasing(struct_text):
    # Property 7: Monotonically Non-Decreasing Offsets (validates Req 10.2, 10.3)
    parser = StructParser(header_reader=_StubReader())
    fields = parser.parse_struct_text(struct_text)
    non_union_offsets = [f.byte_offset for f in fields if not f.in_union]
    assert non_union_offsets == sorted(non_union_offsets)


# Feature: darwin-tcc-mcp-server, Property 8: Union Members Share the Union's
# Base Offset
@given(st.sampled_from(UNION_CONTAINING_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_union_members_share_base_offset(struct_text):
    # Property 8: Union Members Share Base Offset (validates Req 10.5)
    parser = StructParser(header_reader=_StubReader())
    fields = parser.parse_struct_text(struct_text)
    union_fields = [f for f in fields if f.in_union]
    assert union_fields, "union-containing definitions must yield in_union fields"
    offsets = {f.byte_offset for f in union_fields}
    assert len(offsets) == 1, f"union members span multiple offsets: {sorted(offsets)}"
