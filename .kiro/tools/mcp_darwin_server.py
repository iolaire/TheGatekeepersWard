#!/usr/bin/env python3
"""mcp-darwin-context: Darwin SDK headers + TCC reference data as MCP resources/tools.

Runs over stdio via FastMCP. Exposes:

Resources:
    darwin://headers/sysctl      - text of sys/sysctl.h from the active SDK
    darwin://headers/proc_info   - text of sys/proc_info.h from the active SDK
    tcc://schema                 - TCC `access` table DDL (live or bundled)
    tcc://constants/services     - bundled kTCCService* catalogue (JSON array)
    darwin://procargs2/layout    - KERN_PROCARGS2 buffer layout document

Tools:
    lookup_tcc_service(name)          - exact/partial kTCCService* lookup
    get_darwin_struct(struct_name)    - arm64 struct field layouts
    search_darwin_headers(keyword)    - substring search across SDK headers
"""
from __future__ import annotations

import concurrent.futures
import functools
import json
import signal
import sys
from pathlib import Path

# The server runs as a script: .kiro/tools/ is sys.path[0], so the sibling
# modules import directly. When imported as a module (tests), ensure the path.
_TOOLS_DIR = Path(__file__).resolve().parent
if str(_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(_TOOLS_DIR))

from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.exceptions import ToolError
from mcp.shared.exceptions import McpError

from header_reader import HeaderNotFoundError, HeaderReader
from header_search import HeaderSearchEngine, SearchValidationError
from sdk_locator import SDKLocator, SDKUnavailableError
from struct_parser import StructParser, StructParseError
from tcc_registry import TCCRegistry

MCP_ERROR_RESOURCE_NOT_FOUND = -32002
MCP_ERROR_INTERNAL = -32603

STRUCT_SEARCH_TIMEOUT_S = 10.0

mcp = FastMCP("mcp-darwin-context")

# ---------------------------------------------------------------------------
# Component wiring: single SDK detection at startup, cached.
# ---------------------------------------------------------------------------

_sdk_error: str | None = None
try:
    _sdk = SDKLocator().locate()
    header_reader = HeaderReader(_sdk)
    search_engine = HeaderSearchEngine(_sdk)
    struct_parser = StructParser(header_reader)
    registry = TCCRegistry(data_path=_TOOLS_DIR / "resources" / "tcc_services.json")
except SDKUnavailableError as exc:
    _sdk_error = str(exc)
    header_reader = None  # type: ignore[assignment]
    search_engine = None  # type: ignore[assignment]
    struct_parser = None  # type: ignore[assignment]
    registry = TCCRegistry(data_path=_TOOLS_DIR / "resources" / "tcc_services.json")


def _require_sdk() -> None:
    if _sdk_error is not None:
        raise SDKUnavailableError(_sdk_error)


# ---------------------------------------------------------------------------
# Signal handling (Req 1.4): set a shutdown flag; in-flight handlers check it
# and return partial results / errors before the process exits with code 0.
# ---------------------------------------------------------------------------

_shutting_down = False


def _handle_signal(sig, frame) -> None:  # noqa: ANN001 - signal handler signature
    global _shutting_down
    _shutting_down = True
    if search_engine is not None:
        search_engine.request_stop()


signal.signal(signal.SIGTERM, _handle_signal)
signal.signal(signal.SIGINT, _handle_signal)


# ---------------------------------------------------------------------------
# Error mapping decorator (Req 1.5)
# ---------------------------------------------------------------------------


def handle_errors(func):
    """Map domain exceptions to MCP error responses; never let the process die."""

    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except McpError:
            raise
        except (HeaderNotFoundError, SDKUnavailableError) as exc:
            raise McpError(_mcp_error_data(
                MCP_ERROR_RESOURCE_NOT_FOUND, f"{type(exc).__name__}: {exc}"
            )) from exc
        except SearchValidationError as exc:
            # SearchValidationError -> MCP tool error (isError result, not a
            # JSON-RPC protocol error).
            raise ToolError(f"SearchValidationError: {exc.message}") from exc
        except StructParseError as exc:
            # Returned as a normal tool result for the struct tool.
            return {"found": False, "error": str(exc)}
        except Exception as exc:  # noqa: BLE001 - final safety net (Req 1.5)
            raise McpError(_mcp_error_data(
                MCP_ERROR_INTERNAL, f"{type(exc).__name__}: {exc}"
            )) from exc

    return wrapper


def _mcp_error_data(code: int, message: str):
    from mcp.types import ErrorData

    return ErrorData(code=code, message=message)


# ---------------------------------------------------------------------------
# Static resource: darwin://procargs2/layout (Req 8)
# ---------------------------------------------------------------------------

PROCARGS2_LAYOUT_DOC = """KERN_PROCARGS2 Buffer Layout (macOS, 64-bit)

## Byte Layout

A `sysctl(3)` call with MIB `[CTL_KERN, KERN_PROCARGS2, pid]` returns a
byte buffer laid out as this five-part sequence:

1. argc (4 bytes) - a `CInt` at offset 0 counting the argv entries that follow.
2. Executable path - a null-terminated string (`char *`, CChar sequence)
   immediately after argc.
3. Null padding - one or more zero bytes filling the gap between the end of
   the executable path string and the 8-byte boundary
   (`MemoryLayout<Int>.size` == 8 on 64-bit macOS). argv[0] always begins at
   an 8-byte-aligned offset, so walk past the padding before parsing argv.
4. argv strings - `argv[0]` through `argv[argc-1]`, each a null-terminated
   string (`argv[0]` repeats the executable path).
5. Environment strings - consecutive null-terminated `KEY=VALUE` strings
   running to the end of the buffer.

## Swift Code Example

    import Darwin

    func readProcArgs2(pid: pid_t) -> (argc: CInt, args: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0

        // Phase 1: size-then-fetch - first call with nil buffer returns size
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else {
            // errno is set (e.g. ESRCH if pid is gone, EIO for kernel procs)
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)

        // Phase 2: fetch into the sized buffer
        guard sysctl(&mib, 4, &buffer, &size, nil, 0) == 0 else {
            return nil
        }

        // argc is the leading CInt
        let argc = buffer.withUnsafeBytes {
            $0.load(as: CInt.self, from: 0)
        }
        // ... then walk: exec path, 8-byte-aligned padding, argv strings
        return (argc, [])
    }

## Parser Cautions

- CAUTION: alignment gap. Between the executable path and argv[0] there is a
  run of null padding bytes whose only purpose is 8-byte alignment. It is NOT
  an empty argv entry. Parse argv[0] at the first offset after the exec path
  that is aligned to `MemoryLayout<Int>.size` (8) bytes; do not treat the
  padding as data.
- CAUTION: environment termination sentinel. The environment region is
  terminated by a double-null (two consecutive 0x00 bytes). Stop parsing
  environment strings when you see `\\0\\0`; a single `\\0` only separates
  individual `KEY=VALUE` entries. Buffers from sysctl may be larger than the
  data actually present, so the sentinel - not the buffer length - ends the
  environment.
- CAUTION: some kernel processes return `EIO` for KERN_PROCARGS2; treat any
  sysctl failure as "layout unavailable" rather than retrying.
"""


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------


@mcp.resource(
    "darwin://headers/sysctl",
    name="Darwin sysctl.h",
    description="Full text of sys/sysctl.h from the active macOS SDK",
    mime_type="application/json",
)
@handle_errors
def resource_sysctl_header() -> dict:
    return _header_resource("sys/sysctl.h")


@mcp.resource(
    "darwin://headers/proc_info",
    name="Darwin proc_info.h",
    description="Full text of sys/proc_info.h from the active macOS SDK",
    mime_type="application/json",
)
@handle_errors
def resource_proc_info_header() -> dict:
    return _header_resource("sys/proc_info.h")


def _header_resource(relative_path: str) -> dict:
    _require_sdk()
    content = header_reader.read(relative_path)
    return {
        "content": content.text,
        "source_path": content.source_path,
        "used_fallback": content.used_fallback,
    }


@mcp.resource(
    "tcc://schema",
    name="TCC schema",
    description="SQLite DDL for the TCC `access` table (live or bundled)",
    mime_type="application/json",
)
@handle_errors
def resource_tcc_schema() -> dict:
    result = registry.tcc_schema_ddl()
    return {"ddl": result.ddl, "source": result.source}


@mcp.resource(
    "tcc://constants/services",
    name="TCC service constants",
    description="All known kTCCService* keys with scope, description, UI label",
    mime_type="application/json",
)
@handle_errors
def resource_tcc_services() -> list[dict]:
    return [
        {
            "key": e.key,
            "display_name": e.display_name,
            "scope": e.scope,
            "description": e.description,
            "ui_prompt_label": e.ui_prompt_label,
        }
        for e in registry.all_services()
    ]


@mcp.resource(
    "darwin://procargs2/layout",
    name="KERN_PROCARGS2 layout",
    description="Byte layout, Swift example, and parser cautions for KERN_PROCARGS2",
)
@handle_errors
def resource_procargs2_layout() -> str:
    return PROCARGS2_LAYOUT_DOC


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------


@mcp.tool(
    name="lookup_tcc_service",
    description="Look up a kTCCService* key by exact or partial name; returns "
    "key, display_name, scope, description, and ui_prompt_label.",
)
@handle_errors
def tool_lookup_tcc_service(name: str) -> dict:
    if not isinstance(name, str) or len(name) > 256:
        return {"found": False, "error": "name must be a string of at most 256 characters"}
    result = registry.lookup(name)
    if result.found:
        return {
            "found": True,
            "results": [_entry_dict(e) for e in result.results],
        }
    payload: dict = {"found": False}
    if result.error:
        payload["error"] = result.error
    if result.suggestions is not None:
        payload["suggestions"] = result.suggestions
    return payload


def _entry_dict(e) -> dict:
    return {
        "key": e.key,
        "display_name": e.display_name,
        "scope": e.scope,
        "description": e.description,
        "ui_prompt_label": e.ui_prompt_label,
    }


@mcp.tool(
    name="get_darwin_struct",
    description="Get the C definition and arm64 field layout (name, c_type, "
    "byte_offset, byte_size) for a Darwin struct such as proc_vnodepathinfo.",
)
@handle_errors
def tool_get_darwin_struct(struct_name: str) -> dict:
    _require_sdk()
    if _shutting_down:
        return {"found": False, "error": "server is shutting down"}
    # Full header search can be slow: wrap in a worker thread with a 10 s
    # timeout; the known-struct hot path returns from the table immediately.
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
        try:
            result = pool.submit(struct_parser.get_struct, struct_name).result(
                timeout=STRUCT_SEARCH_TIMEOUT_S
            )
        except concurrent.futures.TimeoutError:
            return {
                "found": False,
                "error": f"struct lookup timed out after {STRUCT_SEARCH_TIMEOUT_S:.0f}s",
            }
    payload: dict = {
        "found": result.found,
    }
    if result.found:
        payload.update({
            "definition": result.definition,
            "fields": [
                {
                    "name": f.name,
                    "c_type": f.c_type,
                    "byte_offset": f.byte_offset,
                    "byte_size": f.byte_size,
                    "in_union": f.in_union,
                }
                for f in result.fields
            ],
            "source_header": result.source_header,
            "arm64_byte_size": result.arm64_byte_size,
        })
    else:
        if result.searched_headers:
            payload["searched_headers"] = result.searched_headers
        if result.error:
            payload["error"] = result.error
    return payload


@mcp.tool(
    name="search_darwin_headers",
    description="Case-insensitive substring search across all macOS SDK .h "
    "headers; returns matches with 2-line context, capped at max_results.",
)
@handle_errors
def tool_search_darwin_headers(keyword: str, max_results: int = 20) -> dict:
    _require_sdk()
    if _shutting_down:
        return {"total_matches": 0, "timed_out": False, "results": [],
                "error": "server is shutting down"}
    result = search_engine.search(keyword, max_results=max_results)
    return {
        "total_matches": result.total_matches,
        "timed_out": result.timed_out,
        "results": [
            {
                "file": m.file,
                "line_number": m.line_number,
                "line_content": m.line_content,
                "context": m.context,
            }
            for m in result.results
        ],
    }


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
