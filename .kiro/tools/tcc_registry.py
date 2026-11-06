"""TCC service-key registry: bundled data as primary, live TCC.db for DDL only."""
from __future__ import annotations

import json
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path

TCC_DB_PATH = Path("/Library/Application Support/com.apple.TCC/TCC.db")

VALID_SCOPES = {"user", "system", "both"}

REQUIRED_FIELDS = ("key", "display_name", "scope", "description", "ui_prompt_label")

# Canonical TCC `access` table DDL as of macOS 14 (embedded fallback for when
# the live TCC.db is SIP-protected or otherwise unreadable).
BUNDLED_TCC_SCHEMA = (
    "CREATE TABLE access (service TEXT NOT NULL, client TEXT NOT NULL, "
    "client_type INTEGER NOT NULL, auth_value INTEGER NOT NULL, "
    "auth_reason INTEGER NOT NULL, auth_version INTEGER NOT NULL, csreq BLOB, "
    "policy_id INTEGER, indirect_object_identifier_type INTEGER, "
    "indirect_object_identifier TEXT, indirect_object_code_identity INTEGER, "
    "flags INTEGER, last_modified INTEGER NOT NULL, pid INTEGER, "
    "pid_version INTEGER NOT NULL, boot_uuid TEXT NOT NULL, "
    "last_accessed INTEGER NOT NULL, "
    "PRIMARY KEY (service, client, client_type, indirect_object_identifier), "
    "FOREIGN KEY (policy_id) REFERENCES policies(id) ON DELETE CASCADE "
    "ON UPDATE CASCADE)"
)


@dataclass
class TCCServiceEntry:
    key: str
    display_name: str
    scope: str
    description: str
    ui_prompt_label: str


@dataclass
class LookupResult:
    found: bool
    results: list[TCCServiceEntry] = field(default_factory=list)
    error: str | None = None
    suggestions: list[str] = field(default_factory=list)


@dataclass
class SchemaDDLResult:
    ddl: str
    source: str  # "live" or "bundled"


class TCCRegistry:
    def __init__(self, data_path: Path):
        self._data_path = Path(data_path)
        raw = json.loads(self._data_path.read_text(encoding="utf-8"))
        self._entries = [TCCServiceEntry(**item) for item in raw]
        self._validate()
        self._by_key = {e.key: e for e in self._entries}

    def _validate(self) -> None:
        for entry in self._entries:
            for name in REQUIRED_FIELDS:
                if not getattr(entry, name) or not isinstance(getattr(entry, name), str):
                    raise ValueError(f"TCC entry {entry.key!r} missing field {name!r}")
            if entry.scope not in VALID_SCOPES:
                raise ValueError(
                    f"TCC entry {entry.key!r} has invalid scope {entry.scope!r}; "
                    f"must be one of {sorted(VALID_SCOPES)}"
                )

    def all_services(self) -> list[TCCServiceEntry]:
        """Return all known kTCCService* entries from bundled data."""
        return list(self._entries)

    def lookup(self, name: str) -> LookupResult:
        """Exact match first, then case-insensitive substring on key and display name."""
        if not isinstance(name, str) or not name.strip():
            return LookupResult(found=False, error="name must be a non-empty string")
        needle = name.strip()
        exact = self._by_key.get(needle)
        if exact is not None:
            return LookupResult(found=True, results=[exact])
        lowered = needle.lower()
        matches = [
            e for e in self._entries
            if lowered in e.key.lower() or lowered in e.display_name.lower()
        ]
        if matches:
            return LookupResult(found=True, results=matches)
        return LookupResult(found=False, suggestions=[])

    def tcc_schema_ddl(self) -> SchemaDDLResult:
        """Attempt to read DDL from live TCC.db; fall back to bundled schema."""
        try:
            conn = sqlite3.connect(str(TCC_DB_PATH), timeout=2.0)
            try:
                cursor = conn.execute(
                    "SELECT sql FROM sqlite_master "
                    "WHERE type='table' AND name='access'"
                )
                row = cursor.fetchone()
                if row and row[0]:
                    return SchemaDDLResult(ddl=row[0], source="live")
            finally:
                conn.close()
        except (PermissionError, sqlite3.OperationalError, sqlite3.DatabaseError, OSError):
            pass  # SIP-protected or unreadable — fall through to bundled
        return SchemaDDLResult(ddl=BUNDLED_TCC_SCHEMA, source="bundled")
