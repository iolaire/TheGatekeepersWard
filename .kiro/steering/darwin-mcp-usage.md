---
inclusion: manual
name: darwin-mcp-usage
description: When and how to call the darwin-tcc-docs MCP server tools during Gatekeeper's Ward development.
---

# Darwin TCC MCP Usage

The `darwin-tcc-docs` MCP server (`mcp-darwin-context`) is running locally and exposes Darwin SDK headers and TCC reference data as live tools. Call these tools **before** generating or modifying any code in the areas below — never hardcode struct offsets, TCC service key strings, or KERN_PROCARGS2 buffer positions from memory.

---

## When to Call Each Tool

### `search_darwin_headers(keyword)`

Call this **before writing or modifying any code** that references:
- `KERN_PROCARGS2` or `KERN_PROC_PID` — always verify the MIB constant value and any related struct/typedef from the live SDK
- `proc_pidinfo` or `PROC_PIDVNODEPATHINFO` — confirm the flavour constant and expected buffer type
- Any Darwin constant or typedef you are not 100% certain of — search first, then write

```
search_darwin_headers("KERN_PROCARGS2")
search_darwin_headers("PROC_PIDVNODEPATHINFO")
search_darwin_headers("proc_pidinfo")
```

### `get_darwin_struct(struct_name)`

Call this **before writing or modifying** any code that reads or writes into a Darwin struct buffer, especially:
- `ProcessInspector.workingDirectory(for:)` — call `get_darwin_struct("proc_vnodepathinfo")` first; use the returned `byte_offset` and `byte_size` values directly, do not guess
- Any `sysctl` or `proc_pidinfo` buffer parsing — confirm field layout for `kinfo_proc`, `extern_proc`, `proc_bsdinfo`, `vnode_info_path`

```
get_darwin_struct("proc_vnodepathinfo")
get_darwin_struct("kinfo_proc")
```

Supported structs with pre-computed arm64 layouts (sub-second response):
`proc_vnodepathinfo`, `vnode_info_path`, `kinfo_proc`, `extern_proc`, `proc_bsdinfo`

### `lookup_tcc_service(name)`

Call this **before inserting any `kTCCService*` string literal** into Swift source, including:
- The `TCCService` enum in `GatekeepersWard/Permissions/TCCEvent.swift`
- Any hardcoded service string in `TCCWatcher` or log parsing code
- Any test fixture that uses a TCC service name

```
lookup_tcc_service("kTCCServiceCamera")
lookup_tcc_service("Documents")       # partial match works too
```

---

## When to Fetch Resources

### `tcc://constants/services`

Fetch this resource **before updating the `TCCService` Swift enum** to verify exhaustive case coverage. Every `key` returned by the resource must have a corresponding enum case — do not add cases that are not in the catalogue.

### `darwin://procargs2/layout`

Fetch this resource **before writing any KERN_PROCARGS2 buffer parser**. It contains:
- The exact five-part byte layout (argc → exec path → null padding → argv[] → env strings)
- A Swift two-phase sysctl code example
- Labelled caution notes on the null-padding alignment gap and double-null env terminator

### `darwin://headers/sysctl` / `darwin://headers/proc_info`

Fetch these when you need the full header text in context — useful when `search_darwin_headers` returns a match and you want surrounding declarations, `#define` guards, or typedef chains.

---

## Quick Reference

| Situation | Tool / Resource |
|---|---|
| Writing `KERN_PROCARGS2` buffer parser | `darwin://procargs2/layout` then `search_darwin_headers("KERN_PROCARGS2")` |
| Parsing `proc_pidinfo` result buffer | `get_darwin_struct("proc_vnodepathinfo")` |
| Adding a case to `TCCService` enum | `lookup_tcc_service(<name>)` then verify against `tcc://constants/services` |
| Updating full `TCCService` enum | `tcc://constants/services` — check every key has a case |
| Any unfamiliar Darwin constant | `search_darwin_headers(<symbol>)` |
| Struct field offset doubt | `get_darwin_struct(<struct>)` |
