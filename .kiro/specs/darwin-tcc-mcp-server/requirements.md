# Requirements Document

## Introduction

`mcp-darwin-context` is a local Model Context Protocol (MCP) server that exposes macOS Darwin SDK headers and TCC framework reference data as resources and callable tools within Kiro's development context. It runs as a stdio subprocess on the developer's machine, requiring no network access or Apple entitlements, and serves as the authoritative runtime source of truth for system struct layouts and TCC service key constants during Gatekeeper's Ward development. By grounding Kiro's context in the active macOS SDK on disk, the server eliminates hallucinated `sysctl` buffer offsets and invalid `kTCCService*` keys before they ever reach production Swift code.

## Glossary

- **MCP_Server**: The `mcp-darwin-context` Python process that implements the Model Context Protocol using stdio transport (JSON-RPC 2.0).
- **Kiro**: The AI coding environment that acts as an MCP client, consuming resources and invoking tools exposed by the MCP_Server.
- **Darwin_SDK**: The macOS SDK installed at the active Xcode or Command Line Tools path (e.g., `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`).
- **TCC_Database**: The macOS Transparency, Consent, and Control SQLite database at `/Library/Application Support/com.apple.TCC/TCC.db`, readable in schema form without privileged access.
- **TCC_Service_Key**: A canonical `kTCCService*` string constant (e.g., `kTCCServiceSystemPolicyDocumentsFolder`) that identifies a protected resource category in the TCC access table.
- **Struct_Layout**: The C struct definition including field names, types, byte sizes, and memory offsets as compiled for the current macOS SDK target architecture.
- **Resource_URI**: A URI following the `darwin://` or `tcc://` scheme that uniquely identifies a document or data source exposed by the MCP_Server.
- **Tool**: An MCP-callable function exposed by the MCP_Server that accepts typed arguments and returns structured text results.
- **FastMCP**: The Python `mcp` library's high-level decorator-based server API used to implement the MCP_Server.
- **KERN_PROCARGS2**: The `sysctl` MIB key used by `ProcessInspector` in GatekeepersWard to extract argv and environment from a live process.
- **PROC_PIDVNODEPATHINFO**: The `proc_pidinfo` flavour used to retrieve the current working directory of a process.

## Requirements

### Requirement 1: Server Bootstrap and Transport

**User Story:** As a developer, I want the MCP server to start as a subprocess managed by Kiro, so that Darwin and TCC reference data is available in context whenever I am writing Swift interop code.

#### Acceptance Criteria

1. THE MCP_Server SHALL implement JSON-RPC 2.0 over stdio transport using the FastMCP library.
2. THE MCP_Server SHALL register itself under the server name `mcp-darwin-context` in its MCP handshake.
3. WHEN the MCP_Server process starts, THE MCP_Server SHALL emit a valid MCP `initialize` response on stdout within 3 seconds.
4. WHEN the MCP_Server receives a `SIGTERM` or `SIGINT` signal, THE MCP_Server SHALL send a JSON-RPC error response for each in-flight request that cannot complete, then exit with code 0 within 1 second.
5. IF the MCP_Server encounters an unhandled exception during request processing, THEN THE MCP_Server SHALL return a JSON-RPC error response whose `message` field is non-empty and contains the exception type, and SHALL NOT exit the process.
6. WHEN `python3 .kiro/tools/mcp_darwin_server.py` is executed from the workspace root, THE MCP_Server SHALL emit a valid MCP `initialize` response within 5 seconds without requiring any additional PATH manipulation.
7. THE MCP_Server SHALL require no network access; all data SHALL be read from the local filesystem.

### Requirement 2: Kiro MCP Client Configuration

**User Story:** As a developer, I want Kiro to automatically load the MCP server on workspace open, so that Darwin tools are available without manual setup.

#### Acceptance Criteria

1. THE MCP_Server configuration SHALL be declared in `.kiro/settings/mcp.json` under the key `darwin-tcc-docs`.
2. THE MCP_Server config entry SHALL specify `"command": "python3"`, `"args": [".kiro/tools/mcp_darwin_server.py"]`, and `"disabled": false`.
3. WHEN Kiro opens the workspace, THE MCP_Client SHALL discover the `darwin-tcc-docs` entry in `.kiro/settings/mcp.json`, start the MCP_Server subprocess, and register all exposed tools as callable — without any manual user action.
4. THE MCP_Server implementation file SHALL reside at `.kiro/tools/mcp_darwin_server.py`.
5. IF the MCP_Server subprocess fails to start or does not emit a valid MCP `initialize` response within 10 seconds of workspace open, THEN Kiro SHALL surface an observable error notification and SHALL leave any previously registered tools unchanged.

### Requirement 3: Darwin Header Resources

**User Story:** As a developer, I want to retrieve raw Darwin SDK header content through stable URIs, so that Kiro can reference exact struct definitions without reading the filesystem manually each time.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose the resource `darwin://headers/sysctl` returning the full text of `sys/sysctl.h` from the active Darwin SDK.
2. THE MCP_Server SHALL expose the resource `darwin://headers/proc_info` returning the full text of `sys/proc_info.h` from the active Darwin SDK.
3. WHEN a Darwin header resource is requested, THE MCP_Server SHALL locate the active Darwin SDK by running `xcrun --sdk macosx --show-sdk-path` and SHALL resolve the header path relative to that SDK root.
4. WHEN a Darwin header resource is requested, THE MCP_Server SHALL complete the `xcrun` invocation within 5 seconds; IF `xcrun` does not complete within 5 seconds, THE MCP_Server SHALL treat it as unavailable and proceed to the fallback path.
5. IF `xcrun` is unavailable or returns a non-zero exit code, THEN THE MCP_Server SHALL fall back to the path `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` and SHALL include a warning string in the resource metadata indicating that the fallback SDK path was used.
6. IF the resolved header file does not exist at the expected path, THEN THE MCP_Server SHALL return an MCP error with code `-32002` and an error message identifying the missing absolute path.
7. WHEN returning a Darwin header resource, THE MCP_Server SHALL include the resolved absolute SDK path as a `source_path` field in the resource metadata and SHALL include a boolean `used_fallback` field set to `true` if the fallback path was used, or `false` otherwise.

### Requirement 4: TCC Schema and Service Key Resources

**User Story:** As a developer, I want canonical TCC schema and service key data available as resources, so that I never reference an invalid `kTCCService*` constant in Swift code.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose the resource `tcc://schema` returning the SQLite DDL for the `access` table in the TCC framework.
2. THE MCP_Server SHALL expose the resource `tcc://constants/services` returning a JSON array where each entry has the fields `key`, `display_name`, `scope`, and `description`, covering all known `kTCCService*` keys.
3. THE `tcc://constants/services` resource SHALL include at minimum the following service keys: `kTCCServiceSystemPolicyDocumentsFolder`, `kTCCServiceSystemPolicyDesktopFolder`, `kTCCServiceSystemPolicyDownloadsFolder`, `kTCCServiceSystemPolicyAllFiles`, `kTCCServiceAddressBook`, `kTCCServiceContactsFull`, `kTCCServiceCalendar`, `kTCCServiceReminders`, `kTCCServiceCamera`, `kTCCServiceMicrophone`, `kTCCServiceScreenCapture`, `kTCCServiceAccessibility`, `kTCCServiceAppleEvents`.
4. WHEN the `tcc://schema` resource is requested and the TCC_Database is accessible, THE MCP_Server SHALL return the DDL text with a `"source": "live"` field in the resource metadata.
5. IF the TCC_Database is inaccessible due to SIP or permissions, THEN THE MCP_Server SHALL return a hardcoded authoritative schema string and SHALL include a `"source": "bundled"` field in the resource metadata.
6. THE `scope` field in each `tcc://constants/services` entry SHALL be one of the values `"user"`, `"system"`, or `"both"`.

### Requirement 5: `lookup_tcc_service` Tool

**User Story:** As a developer, I want to look up a TCC service key by name, so that I can verify the exact docstring, scope, and UI label for any service I reference in Swift.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose a tool named `lookup_tcc_service` accepting a single string argument `name` of at most 256 characters.
2. WHEN `lookup_tcc_service` is called with a valid `kTCCService*` key, THE MCP_Server SHALL return a JSON object containing `key`, `display_name`, `scope`, `description`, and `ui_prompt_label`.
3. WHEN `lookup_tcc_service` is called with a non-empty partial name (e.g., `"Documents"`), THE MCP_Server SHALL perform a case-insensitive substring match against both key names and display names and SHALL return a JSON object with `"found": true` and a `"results"` array where each entry contains `key`, `display_name`, `scope`, `description`, and `ui_prompt_label`.
4. IF `lookup_tcc_service` is called with an empty string, THEN THE MCP_Server SHALL return a JSON object with `"found": false` and an error message, and SHALL NOT return any service entries.
5. IF `lookup_tcc_service` is called with a name that matches no known service key and no partial match, THEN THE MCP_Server SHALL return a JSON object with `"found": false` and `"suggestions": []` and SHALL NOT raise an error.
6. THE MCP_Server SHALL resolve the `lookup_tcc_service` tool call within 500 milliseconds.

### Requirement 6: `get_darwin_struct` Tool

**User Story:** As a developer, I want to retrieve the C struct layout and field offsets for Darwin structs, so that Kiro can generate correct `sysctl` buffer parsing code without guessing byte positions.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose a tool named `get_darwin_struct` accepting a single string argument `struct_name`.
2. WHEN `get_darwin_struct` is called with a known struct name (e.g., `"proc_vnodepathinfo"`, `"kinfo_proc"`), THE MCP_Server SHALL return a JSON object containing a `definition` field with the raw C struct text and a `fields` array where each entry has `name`, `c_type`, `byte_offset`, and `byte_size`.
3. THE `get_darwin_struct` tool SHALL support at minimum the following structs: `proc_vnodepathinfo`, `vnode_info_path`, `kinfo_proc`, `extern_proc`, `proc_bsdinfo`.
4. WHEN `get_darwin_struct` is called, THE MCP_Server SHALL include in the response the source header file path and the byte size of the struct compiled for arm64.
5. IF `get_darwin_struct` is called with an unrecognised struct name, THEN THE MCP_Server SHALL search the Darwin_SDK header files and SHALL return a JSON object with the same `definition` and `fields` format as criterion 2 for the first match found.
6. IF no definition is found after searching, THEN THE MCP_Server SHALL return a JSON object with `"found": false` and `"searched_headers"` as a JSON array of absolute path strings listing the files that were scanned.
7. THE MCP_Server SHALL resolve the `get_darwin_struct` tool call within 2 seconds for known structs and within 10 seconds for an exhaustive header search.
8. IF `get_darwin_struct` is called with an empty or whitespace-only `struct_name`, THEN THE MCP_Server SHALL return a JSON object with `"found": false` and an error message without performing any header search.

### Requirement 7: `search_darwin_headers` Tool

**User Story:** As a developer, I want to search across all macOS SDK headers by keyword, so that I can discover relevant constants, typedefs, and struct fields without leaving Kiro's context.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose a tool named `search_darwin_headers` accepting a string argument `keyword` and an optional integer argument `max_results` (default 20, maximum 100).
2. WHEN `search_darwin_headers` is called with a valid keyword, THE MCP_Server SHALL perform a case-insensitive substring search across all `.h` files under `$(xcrun --sdk macosx --show-sdk-path)/usr/include/`.
3. WHEN results are found, THE MCP_Server SHALL return a JSON array where each entry contains `file`, `line_number`, `line_content`, and `context` (up to 2 lines before and 2 lines after the match).
4. THE MCP_Server SHALL limit results to `max_results` entries and SHALL include a `"total_matches"` count in the response even when truncated.
5. WHEN `search_darwin_headers` is called with `keyword` shorter than 3 characters, THE MCP_Server SHALL return an error with the message `"keyword must be at least 3 characters"`.
6. IF `max_results` is provided as a value less than 1 or greater than 100, THEN THE MCP_Server SHALL return an error with the message `"max_results must be between 1 and 100"`.
7. IF the Darwin SDK is unavailable (xcrun fails or the include directory does not exist), THEN THE MCP_Server SHALL return a JSON-RPC error identifying the unavailable SDK path.
8. WHEN `search_darwin_headers` is called with a valid keyword that has no matches, THE MCP_Server SHALL return a JSON object with `"total_matches": 0` and an empty `"results"` array.
9. THE MCP_Server SHALL abort `search_darwin_headers` after 15 seconds and SHALL return a partial result with a `"timed_out": true` flag and the `"total_matches"` count found so far.

### Requirement 8: KERN_PROCARGS2 Buffer Layout Resource

**User Story:** As a developer, I want an authoritative description of the `KERN_PROCARGS2` buffer layout, so that `ProcessInspector` parse logic exactly matches the kernel's memory layout.

#### Acceptance Criteria

1. THE MCP_Server SHALL expose the resource `darwin://procargs2/layout` returning a UTF-8 text document containing three mandatory named sections: "Byte Layout", "Swift Code Example", and "Parser Cautions".
2. THE "Byte Layout" section SHALL document the five-part buffer sequence: (a) 4-byte `argc` as `CInt`, (b) null-terminated executable path string, (c) null padding bytes aligned to the next `MemoryLayout<Int>.size`-byte (8 bytes on 64-bit macOS) boundary, (d) null-terminated `argv[0]` through `argv[argc-1]`, (e) null-terminated environment strings.
3. THE "Swift Code Example" section SHALL include a Swift code snippet that covers both sysctl calls of the two-phase size-then-fetch pattern, uses the MIB array `[CTL_KERN, KERN_PROCARGS2, pid]`, and includes error-indication guards on each sysctl call.
4. THE "Parser Cautions" section SHALL include at least two labelled caution notes: one describing the null-padding alignment gap between the executable path and `argv[0]`, and one describing the double-null termination sentinel marking the end of environment strings.

### Requirement 9: Steering Document Integration

**User Story:** As a developer, I want a Kiro steering document that instructs Kiro when and how to call MCP tools, so that Darwin reference data is pulled automatically during relevant coding tasks.

#### Acceptance Criteria

1. THE MCP_Server steering document SHALL be created at `.kiro/steering/darwin-mcp-usage.md` with a YAML front-matter block containing `inclusion: manual` and a non-empty `description` field of at most 120 characters.
2. WHEN the steering document instructs Kiro to write or modify code that references `KERN_PROCARGS2`, `KERN_PROC_PID`, or `proc_pidinfo`, THE Steering_Document SHALL direct Kiro to call `search_darwin_headers` with the relevant symbol name before generating the code.
3. WHEN the steering document instructs Kiro to insert a `kTCCService*` string literal into Swift source or the `TCCService` enum, THE Steering_Document SHALL direct Kiro to call `lookup_tcc_service` with the service name before inserting the literal.
4. WHEN the steering document instructs Kiro to update the `TCCService` Swift enum, THE Steering_Document SHALL direct Kiro to fetch `tcc://constants/services` and verify that every returned key has a corresponding enum case before finalising the edit.
5. WHEN the steering document instructs Kiro to write or modify `ProcessInspector.workingDirectory(for:)`, THE Steering_Document SHALL direct Kiro to call `get_darwin_struct` with `"proc_vnodepathinfo"` before generating the implementation.

### Requirement 10: Struct Offset Extraction Parser

**User Story:** As a developer, I want the struct layout parser to extract field names and byte offsets from header text, so that I can verify pointer arithmetic in Swift against the actual SDK definition.

#### Acceptance Criteria

1. THE MCP_Server SHALL implement a parser that extracts field names, C types, and byte offsets measured from the outermost struct boundary from C struct definitions found in Darwin SDK headers.
2. WHEN given a valid C struct definition string, THE Struct_Parser SHALL return a list of fields each containing `name`, `c_type`, `byte_offset` (from the outermost struct boundary), and `byte_size`.
3. WHEN given a C struct definition containing nested anonymous structs or unions up to 8 levels deep, THE Struct_Parser SHALL flatten them with dot-notation field names (e.g., `pvi_cdir.vip_path`), with all offsets measured from the outermost struct boundary.
4. FOR ALL valid C struct definition strings extracted from the Darwin_SDK, parsing the struct then formatting it back to a definition string then parsing again SHALL produce a field list with identical `name`, `c_type`, `byte_offset`, and `byte_size` values in the same order as the original parse (round-trip property).
5. WHEN given a C struct definition containing a nested union, THE Struct_Parser SHALL assign each direct member of the union the union's own offset from the outermost struct boundary and SHALL annotate each with `"in_union": true`.
6. IF given a string that is not a valid C struct definition (including empty string, missing braces, or unbalanced braces), THEN THE Struct_Parser SHALL return an error object with `"valid": false` and a `"reason"` string describing the specific syntax violation.

### Requirement 11: TCC Service Key Enumeration Property

**User Story:** As a developer, I want property-based tests for the TCC service key enumerator, so that the `tcc://constants/services` resource is verifiably correct and exhaustive against the Swift `TCCService` enum.

#### Acceptance Criteria

1. THE MCP_Server test suite SHALL include a property-based test that calls `tcc://constants/services` once to obtain the full key list, then for each returned `kTCCService*` key individually calls `lookup_tcc_service` and verifies the response contains `"found": true`.
2. THE MCP_Server test suite SHALL include a deterministic test that reads all case names matching the pattern `kTCCService[A-Za-z]+` from `GatekeepersWard/Permissions/TCCEvent.swift` and verifies that each extracted key has a corresponding entry in the `tcc://constants/services` resource.
3. IF `GatekeepersWard/Permissions/TCCEvent.swift` does not exist at test run time, THEN the test in criterion 2 SHALL be skipped with a recorded warning rather than failing.
4. THE MCP_Server test suite SHALL include a property-based test using `hypothesis` with strategy `st.text(min_size=0, max_size=200)` verifying that `lookup_tcc_service` with any generated string either returns a JSON object with the five required fields (`key`, `display_name`, `scope`, `description`, `ui_prompt_label`) or returns `"found": false` — it SHALL never raise an exception.
5. THE property-based tests in criteria 1 and 4 SHALL use the `hypothesis` Python library.
6. THE MCP_Server test suite SHALL be runnable with `python3 -m pytest .kiro/tools/tests/` from the workspace root, SHALL exit with code 0 on success, and SHALL require only `mcp`, `hypothesis`, and `pytest` as dependencies.
