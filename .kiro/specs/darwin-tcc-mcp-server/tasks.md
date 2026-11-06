# Implementation Plan: mcp-darwin-context MCP Server

## Overview

Build `mcp-darwin-context` — a local Python MCP server that exposes macOS Darwin SDK headers, TCC service-key data, and `KERN_PROCARGS2` layout as resources and tools via FastMCP over stdio. Implementation follows the dependency graph: scaffold → SDKLocator → HeaderReader / TCCRegistry (parallel) → tcc_services.json → StructParser / HeaderSearchEngine (parallel) → server wiring → tests → steering doc.

## Tasks

- [ ] 1. Project scaffolding — directory structure, dependencies, MCP config
  - Create `.kiro/tools/`, `.kiro/tools/resources/`, `.kiro/tools/tests/` directories
  - Create `requirements.txt` at `.kiro/tools/requirements.txt` with pinned versions: `mcp`, `pycparser`, `hypothesis`, `pytest`
  - Create `.kiro/settings/mcp.json` with the `darwin-tcc-docs` entry: `"command": "python3"`, `"args": [".kiro/tools/mcp_darwin_server.py"]`, `"disabled": false`
  - Create empty stub `__init__.py` files so modules are importable from the test suite
  - _Requirements: 1.6, 2.1, 2.2, 2.4_

- [ ] 2. Implement `SDKLocator`
  - [ ] 2.1 Write `sdk_locator.py` with `SDKLocator`, `SDKPath`, and `SDKUnavailableError`
    - Run `xcrun --sdk macosx --show-sdk-path` with `subprocess.run(..., timeout=5)`
    - On `TimeoutExpired`, `CalledProcessError`, or `FileNotFoundError`: fall back to `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`
    - Raise `SDKUnavailableError` if the fallback path also does not exist
    - `include_root()` returns `<sdk_root>/usr/include/`
    - _Requirements: 3.3, 3.4, 3.5_

  - [ ]* 2.2 Write unit tests for `SDKLocator`
    - Test normal xcrun success path (mock `subprocess.run`)
    - Test xcrun timeout → fallback path used, `used_fallback=True`
    - Test xcrun error → fallback path used
    - Test both paths absent → `SDKUnavailableError` raised
    - _Requirements: 3.4, 3.5_

- [ ] 3. Implement `HeaderReader`
  - [ ] 3.1 Write `header_reader.py` with `HeaderReader`, `HeaderContent`, and `HeaderNotFoundError`
    - Accept `SDKPath` in constructor
    - `read(relative_path)` resolves `<sdk_root>/usr/include/<relative_path>`, reads with UTF-8, returns `HeaderContent`
    - `read_absolute(abs_path)` reads an arbitrary absolute path inside the SDK
    - Apply `functools.lru_cache` on resolved absolute path
    - Raise `HeaderNotFoundError` (carries missing absolute path) when file absent
    - _Requirements: 3.1, 3.2, 3.6, 3.7_

  - [ ]* 3.2 Write unit tests for `HeaderReader`
    - Use `tmp_path` fixture to create a fake SDK tree with stub `.h` files
    - Test successful read returns correct `HeaderContent.text` and `source_path`
    - Test `used_fallback` mirrors the `SDKPath` value
    - Test missing file raises `HeaderNotFoundError` with the absolute path in its message
    - Test LRU cache: second read of same path returns same object without second disk read
    - _Requirements: 3.6, 3.7_

- [ ] 4. Build `tcc_services.json` bundled data file
  - [ ] 4.1 Create `.kiro/tools/resources/tcc_services.json` containing all 13+ required `kTCCService*` entries
    - Each entry: `key`, `display_name`, `scope` (`"user"` | `"system"` | `"both"`), `description`, `ui_prompt_label`
    - Must include all 13 keys listed in Requirement 4.3: `kTCCServiceSystemPolicyDocumentsFolder`, `kTCCServiceSystemPolicyDesktopFolder`, `kTCCServiceSystemPolicyDownloadsFolder`, `kTCCServiceSystemPolicyAllFiles`, `kTCCServiceAddressBook`, `kTCCServiceContactsFull`, `kTCCServiceCalendar`, `kTCCServiceReminders`, `kTCCServiceCamera`, `kTCCServiceMicrophone`, `kTCCServiceScreenCapture`, `kTCCServiceAccessibility`, `kTCCServiceAppleEvents`
    - _Requirements: 4.2, 4.3, 4.6_

- [ ] 5. Implement `TCCRegistry`
  - [ ] 5.1 Write `tcc_registry.py` with `TCCRegistry`, `TCCServiceEntry`, `LookupResult`, and `SchemaDDLResult`
    - Constructor accepts `data_path: Path`; load and validate JSON on init (validate `scope` in `{"user","system","both"}`)
    - `all_services()` returns full list of `TCCServiceEntry`
    - `lookup(name)`: empty string → `LookupResult(found=False, error=...)`, exact match first (case-sensitive), then case-insensitive substring match on `key` and `display_name`, no match → `LookupResult(found=False, suggestions=[])`
    - `tcc_schema_ddl()`: attempt `sqlite3.connect` to TCC.db with 2s timeout; on `PermissionError`/`sqlite3` errors fall back to embedded `BUNDLED_TCC_SCHEMA` string with `source="bundled"`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [ ]* 5.2 Write unit tests for `TCCRegistry`
    - Test all 13 required service keys are present in `all_services()`
    - Test exact lookup by full key returns `found=True`
    - Test case-insensitive partial match returns `found=True` with subset of results
    - Test empty-string lookup returns `found=False` with error message
    - Test no-match lookup returns `found=False` with `suggestions=[]`
    - Test `tcc_schema_ddl()` with inaccessible DB returns `source="bundled"`
    - Test `_validate()` raises on invalid `scope` value
    - _Requirements: 4.3, 4.4, 4.5, 4.6, 5.1–5.6_

- [ ] 6. Checkpoint — SDKLocator, HeaderReader, TCCRegistry, and tcc_services.json complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Implement `StructParser`
  - [ ] 7.1 Write `struct_parser.py` with `StructParser`, `StructField`, `StructResult`, and `StructParseError`
    - Bundle `pycparser` fake-libc stub directory path (or reference the installed package's `utils/fake_libc_include`)
    - Populate `KNOWN_STRUCTS` dict with pre-computed field tables for all five required structs: `proc_vnodepathinfo`, `vnode_info_path`, `kinfo_proc`, `extern_proc`, `proc_bsdinfo`
    - `get_struct(struct_name)`: check `KNOWN_STRUCTS` first; else search headers via `HeaderReader`; return `StructResult`
    - `parse_struct_text(text)`: call `pycparser.parse_string()` → `_flatten_ast()` → list of `StructField`
    - `_flatten_ast(node, prefix, base_offset, in_union)`: arm64 alignment rules, anonymous struct/union flattening, dot-notation names, union members share base offset
    - `ARM64_PRIMITIVE_SIZES` dict covering all Darwin primitive types
    - Empty/whitespace name → `StructResult(found=False, error=...)`
    - Invalid C text → `StructParseError`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 10.1, 10.2, 10.3, 10.5, 10.6_

  - [ ]* 7.2 Write property test for `StructParser` — Property 1: Struct Parse Round-Trip
    - **Property 1: Struct Parse Round-Trip**
    - **Validates: Requirements 10.4**
    - Use `@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))` with `max_examples=100`
    - Parse → format → re-parse; assert `fields_first == fields_second`

  - [ ]* 7.3 Write property test for `StructParser` — Property 7: Monotonically Non-Decreasing Offsets
    - **Property 7: Struct Fields Have Monotonically Non-Decreasing Offsets**
    - **Validates: Requirements 10.2, 10.3**
    - Use `@given(st.sampled_from(KNOWN_STRUCT_DEFINITIONS))` with `max_examples=100`
    - Assert non-union `byte_offset` values are sorted ascending

  - [ ]* 7.4 Write property test for `StructParser` — Property 8: Union Members Share Base Offset
    - **Property 8: Union Members Share the Union's Base Offset**
    - **Validates: Requirements 10.5**
    - Use `@given(st.sampled_from(UNION_CONTAINING_STRUCT_DEFINITIONS))` with `max_examples=100`
    - Assert all `in_union=True` fields within the same union share the same `byte_offset`

  - [ ]* 7.5 Write unit tests for `StructParser`
    - Test all five known structs return `found=True` immediately (no header search)
    - Test field count and first-field offset for `proc_vnodepathinfo`
    - Test empty struct name returns `StructResult(found=False, error=...)`
    - Test invalid C text raises `StructParseError`
    - Test nested anonymous struct produces dot-notation field names
    - _Requirements: 6.2, 6.3, 6.4, 6.8, 10.3, 10.6_

- [ ] 8. Implement `HeaderSearchEngine`
  - [ ] 8.1 Write `header_search.py` with `HeaderSearchEngine`, `SearchMatch`, `SearchResult`, and `SearchValidationError`
    - Constructor accepts `SDKPath`
    - `search(keyword, max_results=20)`: validate keyword ≥ 3 chars and max_results in [1, 100]; iterate `.h` files under `include_root()` in a background thread; collect up to `max_results` matches with 2-line context; abort after 15 s with `timed_out=True`
    - Use `threading.Event` timer checked at top of each file iteration loop
    - Empty / too-short keyword → `SearchValidationError`
    - `total_matches` counts all hits found before the limit/timeout
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

  - [ ]* 8.2 Write property test for `HeaderSearchEngine` — Property 6: Search Result Count Invariant
    - **Property 6: Search Result Count Invariant**
    - **Validates: Requirements 7.4**
    - Use `@given(st.integers(min_value=1, max_value=100), st.from_regex(r'[A-Za-z_]{3,20}', fullmatch=True))`
    - Assert `len(result.results) <= max_results` and `result.total_matches >= len(result.results)`

  - [ ]* 8.3 Write unit tests for `HeaderSearchEngine`
    - Use `tmp_path` fixture to create a fake SDK with two stub `.h` files containing known strings
    - Test keyword < 3 chars raises `SearchValidationError`
    - Test `max_results=0` raises `SearchValidationError`
    - Test `max_results=101` raises `SearchValidationError`
    - Test known keyword returns correct `file`, `line_number`, and `line_content`
    - Test no-match keyword returns `total_matches=0` and empty `results`
    - Test 15-second timeout logic using a monkeypatched clock
    - _Requirements: 7.3, 7.4, 7.5, 7.6, 7.8, 7.9_

- [ ] 9. Checkpoint — StructParser and HeaderSearchEngine complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement `mcp_darwin_server.py` — server entry point, all resources and tools
  - [ ] 10.1 Wire FastMCP server with all resources and tools
    - Import `SDKLocator`, `HeaderReader`, `TCCRegistry`, `StructParser`, `HeaderSearchEngine`
    - Instantiate all components at module level (single SDK detection at startup, cached)
    - Register `@mcp.resource` handlers for: `darwin://headers/sysctl`, `darwin://headers/proc_info`, `tcc://schema`, `tcc://constants/services`, `darwin://procargs2/layout`
    - Register `@mcp.tool` handlers for: `lookup_tcc_service`, `get_darwin_struct`, `search_darwin_headers`
    - Server name in `initialize` response: `mcp-darwin-context`
    - _Requirements: 1.1, 1.2, 1.3, 1.6, 2.4, 3.1, 3.2, 4.1, 4.2, 5.1, 6.1, 7.1_

  - [ ] 10.2 Implement `darwin://procargs2/layout` static resource
    - Embed the static UTF-8 document directly in `mcp_darwin_server.py`
    - Include three mandatory sections: `## Byte Layout`, `## Swift Code Example`, `## Parser Cautions`
    - Byte Layout: five-part buffer sequence (argc, exec path, null padding to 8-byte boundary, argv[], env strings)
    - Swift Code Example: two-phase size-then-fetch sysctl pattern with `[CTL_KERN, KERN_PROCARGS2, pid]` and error guards
    - Parser Cautions: null-padding alignment gap + double-null environment termination sentinel
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ] 10.3 Implement `@handle_errors` decorator and signal handlers
    - `@handle_errors` maps `HeaderNotFoundError` → MCP error -32002, `SDKUnavailableError` → -32002, `SearchValidationError` → MCP tool error, `StructParseError` → `{"found": false, "error": ...}`, any other Exception → MCP error -32603 (process does not exit)
    - Register `SIGTERM` and `SIGINT` handlers that set `_shutting_down = True`
    - Long-running handlers (`search_darwin_headers`, `get_darwin_struct` full-search path) check `_shutting_down` flag and return partial result or error before exit
    - Wrap `get_darwin_struct` full-search path in `concurrent.futures.ThreadPoolExecutor` with 10-second timeout
    - _Requirements: 1.4, 1.5_

- [ ] 11. Implement `conftest.py` shared test fixtures
  - Create `.kiro/tools/tests/conftest.py`
  - `tmp_sdk_dir` fixture: creates a minimal fake SDK tree under `tmp_path` with stub `.h` files containing enough C to exercise `HeaderReader` and `HeaderSearchEngine`
  - `mock_header_reader` fixture: returns a `HeaderReader` backed by `tmp_sdk_dir`
  - `fake_sdk` fixture: returns `SDKPath(root=tmp_sdk_dir, used_fallback=False)`
  - `KNOWN_STRUCT_DEFINITIONS` constant: list of raw C struct strings for the five required structs (used by PBT tests)
  - `UNION_CONTAINING_STRUCT_DEFINITIONS` constant: subset with union-bearing structs
  - _Requirements: 11.6_

- [ ] 12. Implement TCC service key property and coverage tests
  - [ ] 12.1 Write `test_tcc_registry.py` — Property 2, 3, 4, 5 PBT and deterministic tests
    - **Property 2: lookup_tcc_service Never Raises** (`@given(st.text(min_size=0, max_size=200))`, `max_examples=200`) — assert result has `"found"` key; if found, assert all five required fields present
    - **Property 3: Service Catalogue Round-Trip Lookup** — for each entry in `all_services()`, call `lookup(entry.key)` and assert `found=True` and key present in results
    - **Property 4: Partial Match Returns Only Catalogue Members** — for any non-empty search string, every returned `key` must appear in `all_services()` catalogue
    - **Property 5: All Service Entries Have Valid Scope** — iterate `all_services()`, assert each `scope` in `{"user","system","both"}`
    - **Validates: Requirements 4.2, 4.6, 5.1, 5.2, 5.3, 11.1, 11.4**

  - [ ] 12.2 Write `test_tcc_registry.py` — TCCEvent.swift key coverage test (Req 11.2)
    - Read `GatekeepersWard/Permissions/TCCEvent.swift`; extract all `kTCCService[A-Za-z]+` patterns with `re.findall`
    - Assert each extracted key has a corresponding entry in `TCCRegistry.all_services()`
    - Skip with recorded warning if `TCCEvent.swift` does not exist (Req 11.3)
    - _Requirements: 11.2, 11.3_

- [ ] 13. Implement server integration test
  - Create `.kiro/tools/tests/test_server_integration.py`
  - Start `mcp_darwin_server.py` as a subprocess; perform JSON-RPC 2.0 handshake over stdio
  - Issue `resources/read` requests for all five resource URIs; verify JSON shape and required fields
  - Issue `tools/call` for each of the three tools with known-good inputs; verify JSON shape
  - Skip entire module if `SDKLocator().locate()` raises `SDKUnavailableError` (guards CI without Xcode)
  - _Requirements: 1.1, 1.2, 1.3, 3.1, 3.2, 4.1, 4.2, 5.1, 6.1, 7.1, 8.1_

- [ ] 14. Checkpoint — All tests pass
  - Run `python3 -m pytest .kiro/tools/tests/` from workspace root; confirm exit code 0.
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Create steering document
  - [ ] 15.1 Write `.kiro/steering/darwin-mcp-usage.md`
    - YAML front-matter: `inclusion: manual`, `description` ≤ 120 characters
    - Rule: when writing/modifying code referencing `KERN_PROCARGS2`, `KERN_PROC_PID`, or `proc_pidinfo` → call `search_darwin_headers` with the symbol name first
    - Rule: before inserting a `kTCCService*` string literal or enum case → call `lookup_tcc_service` first
    - Rule: before updating the `TCCService` Swift enum → fetch `tcc://constants/services` and verify every returned key has a corresponding case
    - Rule: before writing or modifying `ProcessInspector.workingDirectory(for:)` → call `get_darwin_struct` with `"proc_vnodepathinfo"` first
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The design uses Python 3 throughout; all code must be compatible with the Python 3 stdlib available on macOS 13+
- `pycparser`'s `utils/fake_libc_include/` directory ships with the package — reference it via `import pycparser; Path(pycparser.__file__).parent / "utils" / "fake_libc_include"` rather than copying it
- The five known structs in `KNOWN_STRUCTS` bypass the live header search entirely; this is the hot path for `ProcessInspector` work
- Tests must not require Xcode to be installed: use `tmp_path` fixtures for all file system operations; guard the integration test with a `SDKUnavailableError` skip
- Each property-based test comment must include the feature name and property number for traceability: `# Feature: darwin-tcc-mcp-server, Property N: ...`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1", "4.1", "5.1"] },
    { "id": 2, "tasks": ["2.2", "3.1", "5.2"] },
    { "id": 3, "tasks": ["3.2", "7.1", "8.1"] },
    { "id": 4, "tasks": ["7.2", "7.3", "7.4", "7.5", "8.2", "8.3", "11"] },
    { "id": 5, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 6, "tasks": ["12.1", "12.2", "13"] },
    { "id": 7, "tasks": ["15.1"] }
  ]
}
```
