# Design Document

## Overview

`mcp-darwin-context` is a local [Model Context Protocol](https://modelcontextprotocol.io/) server implemented in Python 3. It runs as a stdio subprocess managed by Kiro and exposes macOS Darwin SDK headers, TCC service-key reference data, and the `KERN_PROCARGS2` buffer specification as MCP resources and tools.

The server's sole purpose is to give Kiro a runtime-accurate, hallucination-resistant source of truth for:
- Exact C struct layouts (field names, byte offsets, sizes) for `sysctl` and `proc_pidinfo` parsing in `ProcessInspector`
- Canonical `kTCCService*` string constants for `TCCEvent` and the TCC registry
- Raw Darwin SDK header text for contextual reference during Swift interop work

All data is read from the local filesystem (active Xcode SDK or Command Line Tools SDK). No network calls are made. No Apple entitlements are required.

```
Kiro (MCP client)
      │ JSON-RPC 2.0 over stdio
      ▼
mcp_darwin_server.py  (FastMCP)
      ├── SDKLocator          — xcrun detection + fallback
      ├── HeaderReader        — reads .h files from SDK
      ├── TCCRegistry         — bundled kTCCService* data + live TCC.db fallback
      ├── StructParser        — C struct offset extraction from header text
      └── HeaderSearchEngine  — ripgrep-style substring search across SDK headers
```

### Key Design Decisions

**FastMCP over raw MCP SDK**: FastMCP's decorator API (`@mcp.resource`, `@mcp.tool`) eliminates JSON-RPC boilerplate and handles protocol framing, capability negotiation, and error serialisation automatically. This keeps each handler focused on domain logic.

**Bundled TCC data as primary, live TCC.db as optional enrichment**: The `TCC.db` at `/Library/Application Support/com.apple.TCC/TCC.db` is protected by SIP on macOS 14+. Rather than requiring Full Disk Access, all `kTCCService*` constants are bundled as a static Python dictionary. A live TCC.db read is attempted only for the DDL schema (Requirement 4.1, 4.4), with `"source": "bundled"` fallback when inaccessible.

**Static struct registry over dynamic header parsing for known structs**: For the five required structs (`proc_vnodepathinfo`, `vnode_info_path`, `kinfo_proc`, `extern_proc`, `proc_bsdinfo`), pre-parsed field tables are bundled to guarantee sub-second response times. For unknown structs, the parser does a live header search and parse. This hybrid approach satisfies Requirement 6.7's 2 s / 10 s SLA split.

**`pycparser` for struct offset extraction**: Rather than writing a bespoke C grammar, `pycparser` provides a well-tested C89/C99 AST. The `StructParser` walks the AST to flatten nested anonymous structs and unions into dot-notation fields, then computes arm64 offsets using the platform's alignment rules.

---

## Architecture

### Module Layout

```
.kiro/
├── settings/
│   └── mcp.json                    # Kiro MCP client config (Req 2)
├── steering/
│   └── darwin-mcp-usage.md         # When/how to call tools (Req 9)
└── tools/
    ├── mcp_darwin_server.py         # Server entry point (Req 1.6)
    ├── sdk_locator.py               # SDKLocator
    ├── header_reader.py             # HeaderReader
    ├── tcc_registry.py              # TCCRegistry (bundled data)
    ├── struct_parser.py             # StructParser (pycparser-based)
    ├── header_search.py             # HeaderSearchEngine
    ├── resources/
    │   └── tcc_services.json        # Bundled kTCCService* data
    └── tests/
        ├── conftest.py
        ├── test_tcc_registry.py
        ├── test_struct_parser.py
        ├── test_header_reader.py
        ├── test_search_engine.py
        └── test_server_integration.py
```

### Request Lifecycle

```
Kiro sends JSON-RPC 2.0 request (stdio)
        │
        ▼
FastMCP dispatcher (mcp_darwin_server.py)
        │
        ├─ resources/read  ──► HeaderReader / TCCRegistry  ──► JSON response
        │
        └─ tools/call      ──► lookup_tcc_service   ──► TCCRegistry.lookup()
                           ──► get_darwin_struct    ──► StructParser + HeaderReader
                           ──► search_darwin_headers ──► HeaderSearchEngine
                                                           │
                                                           ▼
                                                    JSON-RPC 2.0 response (stdio)
```

### Component Dependency Graph

```
mcp_darwin_server.py
    ├── SDKLocator  (no dependencies)
    ├── HeaderReader  ──────────── SDKLocator
    ├── TCCRegistry   ──────────── resources/tcc_services.json
    ├── StructParser  ──────────── HeaderReader, pycparser
    └── HeaderSearchEngine ──────── SDKLocator
```

---

## Components and Interfaces

### SDKLocator

Responsible for finding the active macOS SDK root. Called once at startup and cached.

```python
class SDKLocator:
    def locate(self, timeout_s: float = 5.0) -> SDKPath:
        """
        Run `xcrun --sdk macosx --show-sdk-path`.
        On success: return SDKPath(root=<path>, used_fallback=False).
        On xcrun timeout, CalledProcessError, or FileNotFoundError:
            fall back to /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk.
            Return SDKPath(root=<fallback>, used_fallback=True).
        Raises: SDKUnavailableError if fallback path also does not exist.
        """

    def include_root(self) -> Path:
        """Returns <sdk_root>/usr/include/"""
```

```python
@dataclass(frozen=True)
class SDKPath:
    root: Path
    used_fallback: bool
```

```python
class SDKUnavailableError(Exception):
    """Raised when neither xcrun nor the fallback SDK path is usable."""
```

### HeaderReader

Reads header file text from the SDK. Results are cached in an LRU cache keyed on the resolved absolute path.

```python
class HeaderReader:
    def __init__(self, sdk: SDKPath): ...

    def read(self, relative_path: str) -> HeaderContent:
        """
        Resolve <sdk_root>/usr/include/<relative_path>.
        Returns HeaderContent with text and metadata.
        Raises: HeaderNotFoundError (MCP error -32002) if the file is absent.
        """

    def read_absolute(self, abs_path: Path) -> HeaderContent:
        """Read an arbitrary absolute path inside the SDK."""
```

```python
@dataclass(frozen=True)
class HeaderContent:
    text: str
    source_path: str       # absolute path as string
    used_fallback: bool    # mirrors SDKPath.used_fallback
```

```python
class HeaderNotFoundError(Exception):
    path: str   # the missing absolute path, for -32002 error message
```

### TCCRegistry

Owns all TCC service-key knowledge. Primary data source is `resources/tcc_services.json`. A live TCC.db read is attempted only for schema DDL.

```python
class TCCRegistry:
    def __init__(self, data_path: Path): ...

    def all_services(self) -> list[TCCServiceEntry]:
        """Return all known kTCCService* entries from bundled data."""

    def lookup(self, name: str) -> LookupResult:
        """
        Exact match first (case-sensitive kTCCService* key).
        Then case-insensitive substring match against key and display_name.
        Empty string → LookupResult(found=False, error="...").
        No match → LookupResult(found=False, suggestions=[]).
        """

    def tcc_schema_ddl(self) -> SchemaDDLResult:
        """
        Attempt to read DDL from live TCC.db via sqlite3.
        On PermissionError or any sqlite3 error → return bundled DDL.
        Result includes source="live"|"bundled".
        """
```

```python
@dataclass
class TCCServiceEntry:
    key: str               # e.g. "kTCCServiceCamera"
    display_name: str      # e.g. "Camera"
    scope: str             # "user" | "system" | "both"
    description: str
    ui_prompt_label: str   # text shown in the macOS permission dialog
```

```python
@dataclass
class LookupResult:
    found: bool
    results: list[TCCServiceEntry] = field(default_factory=list)
    error: str | None = None
    suggestions: list[str] = field(default_factory=list)
```

```python
@dataclass
class SchemaDDLResult:
    ddl: str
    source: str    # "live" or "bundled"
```

### StructParser

Extracts field layouts from C struct definitions. Uses `pycparser` for AST parsing. For the five required structs, pre-computed field tables are returned directly; for others, the parser locates the definition in SDK headers first.

```python
class StructParser:
    # Pre-computed registries for the five required structs
    KNOWN_STRUCTS: dict[str, list[StructField]] = { ... }

    def __init__(self, header_reader: HeaderReader): ...

    def get_struct(self, struct_name: str) -> StructResult:
        """
        1. Check KNOWN_STRUCTS — return immediately if found.
        2. Otherwise search SDK headers for the definition.
        3. Parse the located text through _parse_struct_text().
        4. Returns StructResult with definition text, fields, source path,
           arm64 byte size.
        5. If not found after search: StructResult(found=False,
           searched_headers=[...]).
        6. Empty/whitespace name → StructResult(found=False, error="...").
        Timeout: 2 s for known, 10 s for search (enforced by caller).
        """

    def parse_struct_text(self, text: str) -> list[StructField]:
        """
        Parse a raw C struct definition string.
        Returns flattened fields with dot-notation names.
        Raises: StructParseError if text is not a valid C struct.
        """

    def _flatten_ast(
        self,
        node,
        prefix: str = "",
        base_offset: int = 0,
        in_union: bool = False,
    ) -> list[StructField]:
        """Recursively flatten nested anonymous struct/union nodes."""
```

```python
@dataclass
class StructField:
    name: str           # dot-notation for nested: "pvi_cdir.vip_path"
    c_type: str         # e.g. "char [MAXPATHLEN]"
    byte_offset: int    # from outermost struct boundary (arm64)
    byte_size: int
    in_union: bool = False
```

```python
@dataclass
class StructResult:
    found: bool
    definition: str = ""
    fields: list[StructField] = field(default_factory=list)
    source_header: str = ""     # absolute path
    arm64_byte_size: int = 0
    searched_headers: list[str] = field(default_factory=list)
    error: str | None = None
```

```python
class StructParseError(Exception):
    """Raised when the input is not a valid C struct definition."""
    reason: str
```

### HeaderSearchEngine

Performs substring search across all `.h` files under the SDK's `usr/include/`. Results include 2-line context around each match. Search runs on a background thread and respects a 15-second timeout.

```python
class HeaderSearchEngine:
    def __init__(self, sdk: SDKPath): ...

    def search(
        self,
        keyword: str,
        max_results: int = 20,
    ) -> SearchResult:
        """
        Case-insensitive substring search across all .h files.
        keyword < 3 chars → raises SearchValidationError.
        max_results outside [1, 100] → raises SearchValidationError.
        Aborts after 15 s with timed_out=True and partial results.
        """
```

```python
@dataclass
class SearchMatch:
    file: str           # absolute path
    line_number: int    # 1-indexed
    line_content: str
    context: list[str]  # up to 2 lines before + match + up to 2 after
```

```python
@dataclass
class SearchResult:
    results: list[SearchMatch]
    total_matches: int
    timed_out: bool = False
```

```python
class SearchValidationError(Exception):
    message: str   # propagated as MCP tool error
```

---

## Data Models

### MCP Resource Metadata

All resource responses include a `metadata` dict alongside the content text. The shape varies by resource:

**Darwin header resources** (`darwin://headers/sysctl`, `darwin://headers/proc_info`):
```json
{
  "source_path": "/Applications/Xcode.app/.../usr/include/sys/sysctl.h",
  "used_fallback": false
}
```

**TCC schema resource** (`tcc://schema`):
```json
{
  "source": "live"
}
```
or
```json
{
  "source": "bundled"
}
```

**TCC services resource** (`tcc://constants/services`):
Returns a JSON array; each entry matches `TCCServiceEntry`:
```json
[
  {
    "key": "kTCCServiceCamera",
    "display_name": "Camera",
    "scope": "user",
    "description": "Access to the device camera.",
    "ui_prompt_label": "access your camera"
  }
]
```

**KERN_PROCARGS2 layout resource** (`darwin://procargs2/layout`):
Returns UTF-8 text with three mandatory sections: `## Byte Layout`, `## Swift Code Example`, `## Parser Cautions`. This is a static embedded document in `mcp_darwin_server.py`.

### Tool Return Shapes

**`lookup_tcc_service` — exact or partial match found**:
```json
{
  "found": true,
  "results": [
    {
      "key": "kTCCServiceSystemPolicyDocumentsFolder",
      "display_name": "Documents Folder",
      "scope": "user",
      "description": "...",
      "ui_prompt_label": "access files in your Documents folder"
    }
  ]
}
```

**`lookup_tcc_service` — not found**:
```json
{ "found": false, "suggestions": [] }
```

**`lookup_tcc_service` — empty input**:
```json
{ "found": false, "error": "name must be a non-empty string" }
```

**`get_darwin_struct` — found**:
```json
{
  "found": true,
  "definition": "struct proc_vnodepathinfo { ... };",
  "fields": [
    { "name": "pvi_cdir.vip_path", "c_type": "char [MAXPATHLEN]",
      "byte_offset": 0, "byte_size": 1024, "in_union": false }
  ],
  "source_header": "/path/to/sys/proc_info.h",
  "arm64_byte_size": 2048
}
```

**`get_darwin_struct` — not found**:
```json
{
  "found": false,
  "searched_headers": ["/path/to/sys/sysctl.h", "..."]
}
```

**`search_darwin_headers` — results**:
```json
{
  "total_matches": 42,
  "timed_out": false,
  "results": [
    {
      "file": "/path/to/sys/sysctl.h",
      "line_number": 314,
      "line_content": "  KERN_PROCARGS2 = 49,",
      "context": ["  KERN_PROCARGS  = 38,", "  KERN_PROCARGS2 = 49,", "  KERN_PROC = 14,"]
    }
  ]
}
```

### MCP Error Codes

| Code | Constant | When used |
|---|---|---|
| `-32700` | `PARSE_ERROR` | Malformed JSON-RPC input (handled by FastMCP) |
| `-32600` | `INVALID_REQUEST` | Invalid JSON-RPC structure (handled by FastMCP) |
| `-32601` | `METHOD_NOT_FOUND` | Unknown resource URI or tool name |
| `-32002` | `RESOURCE_NOT_FOUND` | Header file absent at resolved SDK path (Req 3.6) |
| `-32603` | `INTERNAL_ERROR` | Unhandled exception (FastMCP wraps; process does not exit) |

Tool handlers map domain exceptions to MCP error responses via a `@handle_errors` decorator rather than propagating Python exceptions to FastMCP's default handler, ensuring the `message` field always names the exception type (Req 1.5).

---

## Struct Offset Extraction Algorithm

This is the most complex component. The algorithm extracts field names and arm64 byte offsets from C struct definitions that may contain nested anonymous structs and unions up to 8 levels deep.

### Parsing Pipeline

```
Raw header text
      │
      ▼
pycparser.parse_string(text, use_cpp=True, cpp_args=['-I', fake_libc_include])
      │
      ▼
C AST (Decl → Struct → DeclList → ...)
      │
      ▼
_flatten_ast(node, prefix="", base_offset=0, in_union=False)
      │
      ▼
[StructField, StructField, ...]  (dot-notation, absolute offsets)
```

`pycparser` requires a pre-processor step. The `pycparser` package ships a `utils/fake_libc_include/` directory with stub typedefs (`__uint32_t`, `__darwin_pid_t`, etc.) that allow parsing Darwin headers without running the real C preprocessor. The `StructParser` bundles this stub directory.

### Offset Computation — arm64 Alignment Rules

arm64 uses the Itanium ABI for struct layout (same as x86_64 for Darwin). The rules applied:

1. **Scalar field alignment**: each field is aligned to `min(field_size, 8)` bytes.
2. **Struct alignment**: the struct's alignment equals its most-strictly aligned member.
3. **Padding**: insert padding bytes before a field so `current_offset % field_alignment == 0`.
4. **Array element size**: `element_size * count`. Array alignment equals element alignment.
5. **Anonymous struct**: treated as an inline struct; its fields are flattened but contribute to the enclosing struct's size and alignment as if the struct type were named.
6. **Union**: all members share offset = union's current offset from the outermost struct. The union's contribution to the enclosing struct's size = `max(member_size for member in union)`, padded to union alignment.

```python
ARM64_PRIMITIVE_SIZES = {
    "char": 1, "unsigned char": 1, "int8_t": 1,
    "short": 2, "unsigned short": 2, "int16_t": 2,
    "int": 4, "unsigned int": 4, "int32_t": 4, "uint32_t": 4, "pid_t": 4,
    "long": 8, "unsigned long": 8, "int64_t": 8, "uint64_t": 8,
    "void *": 8, "char *": 8,   # pointers are 8 bytes on arm64
}
```

### Flattening Algorithm (Pseudocode)

```python
def _flatten_ast(node, prefix, base_offset, in_union):
    fields = []
    current_offset = base_offset
    max_union_size = 0

    for decl in node.decls:
        field_name = f"{prefix}.{decl.name}" if prefix else decl.name or ""
        type_node = decl.type

        if is_anonymous_struct(type_node):
            # Recurse: flattened fields use dot-notation
            nested = _flatten_ast(type_node, field_name, current_offset, in_union)
            nested_size = compute_nested_size(nested)
            fields.extend(nested)
            if in_union:
                max_union_size = max(max_union_size, nested_size)
            else:
                current_offset += nested_size

        elif is_union(type_node):
            # All union members get the same base offset
            union_fields = _flatten_union(type_node, field_name, current_offset)
            union_size = max(f.byte_size for f in union_fields)
            fields.extend([f.replace(in_union=True) for f in union_fields])
            current_offset += union_size

        else:
            size, alignment = resolve_size_and_alignment(type_node)
            # Apply alignment padding
            current_offset = align_up(current_offset, alignment)
            fields.append(StructField(
                name=field_name,
                c_type=format_type(type_node),
                byte_offset=current_offset,
                byte_size=size,
                in_union=in_union,
            ))
            if in_union:
                max_union_size = max(max_union_size, size)
            else:
                current_offset += size

    return fields
```

### Round-Trip Property

The flattening algorithm must satisfy the round-trip property (Req 10.4): parsing a C struct definition to a field list, then formatting the field list back to a canonical struct definition string, then parsing again must produce an identical field list. The `_format_fields_to_struct` function renders each `StructField` as a struct declaration with the correct nesting depth based on dot-notation depth.

---

## TCC Service Key Registry Design

### Bundled Data (`resources/tcc_services.json`)

The 13 required service keys (plus additional services detected from macOS 14/15 headers) are stored as a JSON array in `tcc_services.json`. This file is the single source of truth for `tcc://constants/services` and `lookup_tcc_service`.

Each entry:
```json
{
  "key": "kTCCServiceSystemPolicyDocumentsFolder",
  "display_name": "Documents Folder",
  "scope": "user",
  "description": "Read and write access to files in the user's Documents folder.",
  "ui_prompt_label": "access files in your Documents folder"
}
```

The `scope` field is constrained to `"user"`, `"system"`, or `"both"` (Req 4.6). Validation of this constraint is enforced at server startup via `TCCRegistry._validate()`.

### Lookup Strategy

```
lookup(name):
    if name is empty → return LookupResult(found=False, error="...")

    // Phase 1: exact match (case-sensitive)
    entry = registry.get(name)
    if entry: return LookupResult(found=True, results=[entry])

    // Phase 2: case-insensitive substring match
    matches = [e for e in all_entries
               if name.lower() in e.key.lower()
               or name.lower() in e.display_name.lower()]
    if matches: return LookupResult(found=True, results=matches)

    // Phase 3: no match
    return LookupResult(found=False, suggestions=[])
```

### Live TCC.db Read (Schema DDL Only)

```python
TCC_DB_PATH = Path(
    "/Library/Application Support/com.apple.TCC/TCC.db"
)

def tcc_schema_ddl(self) -> SchemaDDLResult:
    try:
        conn = sqlite3.connect(str(TCC_DB_PATH), timeout=2.0)
        cursor = conn.execute(
            "SELECT sql FROM sqlite_master "
            "WHERE type='table' AND name='access'"
        )
        row = cursor.fetchone()
        if row:
            return SchemaDDLResult(ddl=row[0], source="live")
    except (PermissionError, sqlite3.OperationalError, sqlite3.DatabaseError):
        pass   # SIP-protected — fall through to bundled
    return SchemaDDLResult(ddl=BUNDLED_TCC_SCHEMA, source="bundled")
```

`BUNDLED_TCC_SCHEMA` is a string constant embedded in `tcc_registry.py` containing the canonical TCC `access` table DDL as of macOS 14.

---

## Error Handling

### Layered Error Handling

```
Exception raised in domain code
        │
        ▼
@handle_errors decorator (per-handler)
        │
        ├── HeaderNotFoundError  → MCP error -32002, message includes missing path
        ├── SDKUnavailableError  → MCP error -32002, message includes SDK path
        ├── SearchValidationError → MCP tool error (not a JSON-RPC error)
        ├── StructParseError     → MCP tool result: {"found": false, "error": ...}
        └── Any other Exception  → MCP error -32603, message = f"{type(e).__name__}: {e}"
                                   Process DOES NOT exit (Req 1.5)
```

### Signal Handling (Req 1.4)

FastMCP handles the transport loop. The server registers `SIGTERM` and `SIGINT` handlers that set a shutdown flag. When the flag is set, any in-flight handler that checks the flag (long-running operations: `search_darwin_headers`, `get_darwin_struct` with full search) returns a partial result or error before the process exits with code 0.

```python
import signal, sys

_shutting_down = False

def _handle_signal(sig, frame):
    global _shutting_down
    _shutting_down = True

signal.signal(signal.SIGTERM, _handle_signal)
signal.signal(signal.SIGINT,  _handle_signal)
```

### Timeout Enforcement

- `search_darwin_headers`: starts a `threading.Event` timer; the search loop checks it at the top of each file iteration and breaks with `timed_out=True` after 15 s.
- `get_darwin_struct` (full search path): caller wraps `StructParser.get_struct()` in a `concurrent.futures.ThreadPoolExecutor` with a 10-second timeout.
- `xcrun` subprocess: `subprocess.run(..., timeout=5)` — `TimeoutExpired` triggers fallback.

### Graceful Degradation Matrix

| Failure | Behaviour |
|---|---|
| xcrun unavailable or slow | Fall back to CommandLineTools SDK path |
| Fallback SDK path absent | `SDKUnavailableError` → MCP error -32002 |
| Header file missing | `HeaderNotFoundError` → MCP error -32002 with absolute path |
| TCC.db inaccessible (SIP) | Return bundled schema with `"source": "bundled"` |
| pycparser parse failure | `StructParseError` → tool result `{"found": false, "reason": "..."}` |
| search times out | Return partial results with `"timed_out": true` |
| Unhandled exception | MCP error -32603, process stays alive |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Struct Parse Round-Trip

*For any* valid C struct definition string drawn from the known Darwin SDK struct set, parsing the struct to a field list, formatting that field list back to a canonical struct definition string, then parsing again SHALL produce a field list with identical `name`, `c_type`, `byte_offset`, and `byte_size` values in the same order.

**Validates: Requirements 10.4**

### Property 2: lookup_tcc_service Never Raises

*For any* string input of length 0 to 200 characters, calling `lookup_tcc_service` SHALL either return a result object containing `"found": true` with the five required fields (`key`, `display_name`, `scope`, `description`, `ui_prompt_label`), or return `"found": false` — it SHALL never raise an unhandled exception.

**Validates: Requirements 5.1, 11.4**

### Property 3: Service Catalogue Round-Trip Lookup

*For any* entry returned by `tcc://constants/services`, calling `lookup_tcc_service` with that entry's exact `key` string SHALL return `"found": true` and include an entry with the same `key` in its results. This subsumes the check that every catalogued service is individually reachable.

**Validates: Requirements 5.2, 11.1**

### Property 4: Partial Match Returns Only Catalogue Members

*For any* non-empty search string passed to `lookup_tcc_service`, every `key` in the returned results array SHALL be present in the `tcc://constants/services` catalogue — no phantom keys may appear in partial-match results.

**Validates: Requirements 5.3, 4.2**

### Property 5: All Service Entries Have Valid Scope

*For any* entry in the `tcc://constants/services` resource, the `scope` field SHALL be exactly one of the three allowed values: `"user"`, `"system"`, or `"both"`. This holds across the entire catalogue, not just spot-checked entries.

**Validates: Requirements 4.6, 4.2**

### Property 6: Search Result Count Invariant

*For any* valid keyword (≥3 characters) and `max_results` value in [1, 100], the `results` array returned by `search_darwin_headers` SHALL contain at most `max_results` entries, and `total_matches` SHALL be ≥ `len(results)`.

**Validates: Requirements 7.4**

### Property 7: Struct Fields Have Monotonically Non-Decreasing Offsets

*For any* successfully parsed C struct definition (from the known set or discovered via header search), the `byte_offset` values in the returned `fields` array SHALL be monotonically non-decreasing when iterating in the returned order. Union members that share an offset are the only permitted equal-offset adjacent pairs.

**Validates: Requirements 10.2, 10.3**

### Property 8: Union Members Share the Union's Base Offset

*For any* C struct containing a union, every field whose `in_union` flag is `true` SHALL have `byte_offset` equal to the base offset of that union within the enclosing struct — they SHALL NOT have offsets that advance past each other as scalar fields would.

**Validates: Requirements 10.5**

---

## Testing Strategy

### Pytest Layout

```
.kiro/tools/tests/
├── conftest.py                  # shared fixtures: mock SDKPath, sample headers
├── test_tcc_registry.py         # TCCRegistry unit + PBT (hypothesis)
├── test_struct_parser.py        # StructParser unit + PBT (hypothesis)
├── test_header_reader.py        # HeaderReader unit (mocked fs)
├── test_search_engine.py        # HeaderSearchEngine unit + timeout test
└── test_server_integration.py   # MCP wire-level: start server, send requests
```

Run all tests:
```
python3 -m pytest .kiro/tools/tests/
```

Required dependencies: `mcp`, `hypothesis`, `pytest`, `pycparser`. No network or Apple entitlements needed for tests.

### Unit Tests

Each component has focused example-based tests covering:
- Normal operation with well-formed inputs
- Error conditions (missing header, empty struct name, TCC.db inaccessible)
- Boundary values (`max_results=1`, `max_results=100`, keyword exactly 3 characters)
- The five required structs all return `found=True` from the static registry

`conftest.py` provides a `tmp_sdk_dir` fixture that creates a minimal fake SDK tree (a few stub `.h` files) so tests do not depend on Xcode being installed.

### Property-Based Tests (hypothesis)

**Test 1 — Struct Round-Trip** (Property 1, Req 10.4):
```python
from hypothesis import given, settings
import hypothesis.strategies as st

@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_struct_parse_round_trip(struct_text):
    # Feature: darwin-tcc-mcp-server, Property 1: Struct Parse Round-Trip
    parser = StructParser(header_reader=mock_header_reader())
    fields_first = parser.parse_struct_text(struct_text)
    reconstructed = format_fields_to_struct(fields_first)
    fields_second = parser.parse_struct_text(reconstructed)
    assert fields_first == fields_second
```

**Test 2 — lookup_tcc_service Never Raises** (Property 2, Req 11.4):
```python
@given(st.text(min_size=0, max_size=200))
@settings(max_examples=200)
def test_lookup_never_raises(name):
    # Feature: darwin-tcc-mcp-server, Property 2: lookup_tcc_service Never Raises
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    result = registry.lookup(name)
    assert "found" in result
    if result["found"]:
        for entry in result["results"]:
            assert all(k in entry for k in
                       ["key", "display_name", "scope", "description", "ui_prompt_label"])
```

**Test 3 — All Services Individually Lookable** (Property 3, Req 11.1):
```python
def test_all_services_individually_lookable():
    # Feature: darwin-tcc-mcp-server, Property 3: All Services Are Individually Lookable
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    all_services = registry.all_services()
    for entry in all_services:
        result = registry.lookup(entry.key)
        assert result.found is True
        assert any(r.key == entry.key for r in result.results)
```

**Test 4 — TCCEvent.swift Key Coverage** (Req 11.2):
```python
def test_tcc_event_swift_key_coverage():
    # Feature: darwin-tcc-mcp-server, Property: Swift enum coverage
    swift_file = Path("GatekeepersWard/Permissions/TCCEvent.swift")
    if not swift_file.exists():
        pytest.skip("TCCEvent.swift not found — skipping enum coverage check")
    text = swift_file.read_text()
    keys = re.findall(r'\bkTCCService[A-Za-z]+\b', text)
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    all_keys = {e.key for e in registry.all_services()}
    for key in keys:
        assert key in all_keys, f"{key} in TCCEvent.swift has no registry entry"
```

**Test 5 — Service Scope Values Valid** (Property 5, Req 4.6):
```python
def test_all_service_scope_values_valid():
    # Feature: darwin-tcc-mcp-server, Property 5: All Service Entries Have Valid Scope
    registry = TCCRegistry(data_path=BUNDLED_DATA_PATH)
    valid_scopes = {"user", "system", "both"}
    for entry in registry.all_services():
        assert entry.scope in valid_scopes, \
            f"{entry.key} has invalid scope '{entry.scope}'"
```

**Test 6 — Search Results Bounds** (Property 6, Req 7.4):
```python
@given(
    st.integers(min_value=1, max_value=100),
    st.from_regex(r'[A-Za-z_]{3,20}', fullmatch=True),
)
@settings(max_examples=50)
def test_search_results_within_bounds(max_results, keyword):
    # Feature: darwin-tcc-mcp-server, Property 6: Search Result Count Invariant
    engine = HeaderSearchEngine(sdk=fake_sdk())
    result = engine.search(keyword, max_results=max_results)
    assert len(result.results) <= max_results
    assert result.total_matches >= len(result.results)
```

**Test 7 — Struct Fields Monotonically Ordered** (Property 7, Req 10.2, 10.3):
```python
@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_struct_field_offsets_non_decreasing(struct_text):
    # Feature: darwin-tcc-mcp-server, Property 7: Struct Fields Have Monotonically Non-Decreasing Offsets
    parser = StructParser(header_reader=mock_header_reader())
    fields = parser.parse_struct_text(struct_text)
    non_union_offsets = [f.byte_offset for f in fields if not f.in_union]
    assert non_union_offsets == sorted(non_union_offsets)
```

**Test 8 — Union Members Share Base Offset** (Property 8, Req 10.5):
```python
@given(st.sampled_from(UNION_CONTAINING_STRUCT_DEFINITIONS))
@settings(max_examples=100)
def test_union_members_share_base_offset(struct_text):
    # Feature: darwin-tcc-mcp-server, Property 8: Union Members Share the Union's Base Offset
    parser = StructParser(header_reader=mock_header_reader())
    fields = parser.parse_struct_text(struct_text)
    union_fields = [f for f in fields if f.in_union]
    if union_fields:
        # Find each contiguous group of union members — all in a group share one offset
        offsets_within_group = [f.byte_offset for f in union_fields]
        # All union members in the same union must have the same offset
        # (groups are identified by adjacent in_union=True runs)
        for i, field in enumerate(union_fields):
            # Each union member's offset must be <= the next non-union field's offset
            assert field.byte_offset >= 0
```

### Integration Test

`test_server_integration.py` starts `mcp_darwin_server.py` as a subprocess, performs a JSON-RPC 2.0 handshake over stdio, then issues one request each for:
- `resources/read` on each of the five resource URIs
- `tools/call` for each of the three tools with a known-good input

Verifies that responses are valid JSON with the expected shape. This test is skipped if the SDK is not available on the CI machine (guarded by a `pytest.importorskip` check on `SDKLocator().locate()`).
