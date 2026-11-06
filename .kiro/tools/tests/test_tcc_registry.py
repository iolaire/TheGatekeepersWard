"""Unit, property-based, and coverage tests for TCCRegistry (Tasks 5.2, 12.1, 12.2)."""
from __future__ import annotations

import json
import re

import pytest
from hypothesis import given, settings
import hypothesis.strategies as st

from conftest import BUNDLED_DATA_PATH, TCC_EVENT_SWIFT_PATH
from tcc_registry import TCCRegistry

REQUIRED_KEYS = [
    "kTCCServiceSystemPolicyDocumentsFolder",
    "kTCCServiceSystemPolicyDesktopFolder",
    "kTCCServiceSystemPolicyDownloadsFolder",
    "kTCCServiceSystemPolicyAllFiles",
    "kTCCServiceAddressBook",
    "kTCCServiceContactsFull",
    "kTCCServiceCalendar",
    "kTCCServiceReminders",
    "kTCCServiceCamera",
    "kTCCServiceMicrophone",
    "kTCCServiceScreenCapture",
    "kTCCServiceAccessibility",
    "kTCCServiceAppleEvents",
]

REQUIRED_FIELDS = {"key", "display_name", "scope", "description", "ui_prompt_label"}


@pytest.fixture()
def registry() -> TCCRegistry:
    return TCCRegistry(data_path=BUNDLED_DATA_PATH)


class TestUnit:
    def test_all_13_required_keys_present(self, registry):
        # All 13 required service keys are present in all_services()
        keys = {e.key for e in registry.all_services()}
        for required in REQUIRED_KEYS:
            assert required in keys, f"{required} missing from bundled data"

    def test_exact_lookup_by_full_key(self, registry):
        # Exact lookup by full key returns found=True
        result = registry.lookup("kTCCServiceCamera")
        assert result.found is True
        assert len(result.results) == 1
        assert result.results[0].key == "kTCCServiceCamera"
        assert result.results[0].display_name == "Camera"

    def test_case_insensitive_partial_match(self, registry):
        # Case-insensitive partial match returns found=True with subset results
        result = registry.lookup("documents")
        assert result.found is True
        keys = {e.key for e in result.results}
        assert "kTCCServiceSystemPolicyDocumentsFolder" in keys
        all_keys = {e.key for e in registry.all_services()}
        assert keys <= all_keys

    def test_partial_match_on_display_name(self, registry):
        result = registry.lookup("Full Disk")
        assert result.found is True
        assert any(e.key == "kTCCServiceSystemPolicyAllFiles" for e in result.results)

    def test_empty_string_lookup_returns_error(self, registry):
        # Empty-string lookup returns found=False with error message
        result = registry.lookup("")
        assert result.found is False
        assert result.error
        assert result.results == []

    def test_no_match_returns_suggestions_empty(self, registry):
        # No-match lookup returns found=False with suggestions=[]
        result = registry.lookup("kTCCServiceDefinitelyNotARealService")
        assert result.found is False
        assert result.suggestions == []
        assert result.results == []

    def test_schema_ddl_inaccessible_db_returns_bundled(self, monkeypatch, tmp_path):
        # tcc_schema_ddl() with inaccessible DB returns source="bundled"
        import tcc_registry
        monkeypatch.setattr(tcc_registry, "TCC_DB_PATH", tmp_path / "no" / "such" / "TCC.db")
        result = TCCRegistry(data_path=BUNDLED_DATA_PATH).tcc_schema_ddl()
        assert result.source == "bundled"
        assert "CREATE TABLE access" in result.ddl

    def test_validate_raises_on_invalid_scope(self, tmp_path):
        # _validate() raises on invalid scope value
        bad_data = tmp_path / "bad.json"
        bad_data.write_text(json.dumps([{
            "key": "kTCCServiceX", "display_name": "X", "scope": "weird",
            "description": "d", "ui_prompt_label": "l",
        }]), encoding="utf-8")
        with pytest.raises(ValueError, match="invalid scope"):
            TCCRegistry(data_path=bad_data)


# Feature: darwin-tcc-mcp-server, Property 2: lookup_tcc_service Never Raises
@given(st.text(min_size=0, max_size=200))
@settings(max_examples=200)
def test_lookup_never_raises(name):
    # Property 2: lookup_tcc_service Never Raises (validates Req 5.1, 11.4)
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    result = registry.lookup(name)  # must not raise for any input
    assert hasattr(result, "found")
    if result.found:
        for entry in result.results:
            data = {"key": entry.key, "display_name": entry.display_name,
                    "scope": entry.scope, "description": entry.description,
                    "ui_prompt_label": entry.ui_prompt_label}
            assert REQUIRED_FIELDS <= set(data)


# Feature: darwin-tcc-mcp-server, Property 3: Service Catalogue Round-Trip Lookup
def test_all_services_individually_lookable(registry):
    # Property 3: Service Catalogue Round-Trip Lookup (validates Req 5.2, 11.1)
    for entry in registry.all_services():
        result = registry.lookup(entry.key)
        assert result.found is True, f"{entry.key} not individually lookable"
        assert any(r.key == entry.key for r in result.results)


# Feature: darwin-tcc-mcp-server, Property 4: Partial Match Returns Only
# Catalogue Members
@given(st.text(min_size=1, max_size=50))
@settings(max_examples=100)
def test_partial_match_returns_only_catalogue_members(name):
    # Property 4: Partial Match Returns Only Catalogue Members (Req 5.3, 4.2)
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    result = registry.lookup(name)
    if result.found:
        catalogue = {e.key for e in registry.all_services()}
        for entry in result.results:
            assert entry.key in catalogue, f"phantom key {entry.key}"


# Feature: darwin-tcc-mcp-server, Property 5: All Service Entries Have Valid Scope
def test_all_service_scope_values_valid(registry):
    # Property 5: All Service Entries Have Valid Scope (validates Req 4.6, 4.2)
    for entry in registry.all_services():
        assert entry.scope in {"user", "system", "both"}, \
            f"{entry.key} has invalid scope '{entry.scope}'"


def test_tcc_event_swift_key_coverage(registry):
    # Task 12.2: TCCEvent.swift key coverage (Req 11.2, 11.3)
    if not TCC_EVENT_SWIFT_PATH.exists():
        pytest.skip(
            "TCCEvent.swift not found — skipping enum coverage check "
            f"(looked at {TCC_EVENT_SWIFT_PATH})"
        )
    text = TCC_EVENT_SWIFT_PATH.read_text(encoding="utf-8")
    keys = re.findall(r"\bkTCCService[A-Za-z]+\b", text)
    assert keys, "expected at least one kTCCService* reference in TCCEvent.swift"
    all_keys = {e.key for e in registry.all_services()}
    for key in keys:
        assert key in all_keys, f"{key} in TCCEvent.swift has no registry entry"
