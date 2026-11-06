---
inclusion: auto
name: darwin-c-interop
description: Guidelines for calling Darwin/POSIX C APIs from Swift — sysctl, proc_pidinfo, and related system calls used in ProcessInspector and TCCWatcher.
---

# Darwin C Interop Guidelines

These rules govern every call into Darwin/POSIX C APIs in this project.
The primary call sites are `ProcessInspector` (`sysctl KERN_PROCARGS2`, `KERN_PROC_PID`)
and `TCCWatcher` (the `/usr/bin/log` subprocess wrapper).

---

## 1. Import discipline

Always import the minimal Darwin module needed.

```swift
import Darwin   // sysctl, proc_pidinfo, pid_t, mach_task_self
// NOT: import Glibc — that targets Linux and is unavailable on macOS
```

Never `#if canImport(Darwin)` guard code that is unconditionally macOS-only in
this project. Guards add noise without benefit here.

---

## 2. sysctl call pattern

Every `sysctl` call must follow the two-phase size-then-fetch pattern.
Never pre-allocate a fixed buffer and skip the size query.

```swift
// Phase 1 — query required size
var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
var size = 0
guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
    return nil   // process may have exited
}

// Phase 2 — fetch into exact-sized buffer
var buffer = [UInt8](repeating: 0, count: size)
guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
    return nil
}
```

- `mib` must be `[Int32]`, not `[CInt]` spelling — on arm64/x86_64 macOS they are
  the same width, but `Int32` is the canonical Swift type for these constants.
- Always pass `UInt32(mib.count)` as the `namelen` argument, not a literal.
- After the second call, `size` is updated to the actual bytes written; slice the
  buffer to `buffer[..<size]` before parsing.

---

## 3. KERN_PROCARGS2 buffer layout

```
[ argc: CInt (4 bytes) ]
[ executable path: null-terminated C string ]
[ null padding bytes (align to word boundary) ]
[ argv[0]: null-terminated C string ]
[ argv[1]: null-terminated C string ]
...
[ env[0]: null-terminated C string ]
...
```

Parsing rules:
1. Read `argc` with `withUnsafeBytes { $0.load(as: CInt.self) }` — never use
   `memcpy` into a Swift variable; use typed pointer loads.
2. Advance past the executable path by scanning for the first `\0`.
3. Skip additional `\0` padding bytes until a non-null byte is found —
   this is the start of `argv[0]`.
4. Collect strings until `parsedArgsCount == argc`; stop there even if more
   null-terminated strings follow (those are env vars).
5. Guard against `offset >= size` at every loop iteration to prevent
   reading past the buffer end.

---

## 4. proc_pidinfo usage

`proc_pidinfo` is used to fetch the current working directory (cwd) via
`PROC_PIDVNODEPATHINFO`.

```swift
import Darwin

func workingDirectory(for pid: pid_t) -> String? {
    var info = proc_vnodepathinfo()
    let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
    let result = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size)
    guard result == size else { return nil }
    return withUnsafeBytes(of: info.pvi_cdir.vip_path) { rawPtr in
        let ptr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
        return String(cString: ptr)
    }
}
```

- `proc_pidinfo` returns the number of bytes written on success, or `-1` on
  error. Always compare to the expected struct size, not just `> 0`.
- `PROC_PIDVNODEPATHINFO` requires no entitlements when inspecting processes
  owned by the same user. For other-user processes it returns `-1 EPERM` —
  handle silently.

---

## 5. Error handling

- Never force-unwrap (`!`) a value derived from a C API return.
- Return `nil` / `Optional` from functions that wrap C calls; let callers decide
  how to degrade gracefully.
- Log `errno` when a call unexpectedly returns `-1` in non-obvious cases:

```swift
if result == -1 {
    // errno is thread-local and valid immediately after the call
    let errStr = String(cString: strerror(errno))
    logger.debug("proc_pidinfo failed: \(errStr) (errno \(errno))")
}
```

---

## 6. Mixing Swift types with C integer types

| C type | Swift equivalent | Notes |
|---|---|---|
| `pid_t` | `pid_t` (typealias `Int32`) | Use `pid_t` in signatures, not `Int32` |
| `CInt` | `Int32` | Interchangeable; prefer `Int32` in Swift-only contexts |
| `size_t` | `Int` (on 64-bit) | `sysctl` size parameter must be `var size: Int` |
| `UInt32` | `UInt32` | Used for `namelen` in `sysctl` |

Never implicit-cast between `Int`, `Int32`, and `pid_t` — be explicit:
`Int32(pid)`, `pid_t(someInt)`.

---

## 7. Thread safety

- `sysctl` and `proc_pidinfo` are thread-safe system calls; they may be called
  from any thread or Swift concurrency context.
- Parse the returned buffer on the same thread/task that received it — do not
  store raw `[UInt8]` buffers on shared state; parse immediately and store the
  resulting Swift value type (`ProcessSnapshot`).
- Mark `ProcessInspector` as an actor or call it exclusively from a dedicated
  serial queue to avoid concurrent mutations of any caching layer.

---

## 8. Process-has-exited graceful degradation

`tccd` suspends the child thread, not the process. The process remains in the
Darwin process table for the duration of the TCC prompt. However, in rare
edge cases (rapid successive prompts, or the user dismisses the dialog extremely
fast), the process may have exited before inspection runs.

When `sysctl` or `proc_pidinfo` returns non-zero for a PID that was valid
milliseconds earlier, surface a `ProcessSnapshot` with:

```swift
ProcessSnapshot(
    pid: pid,
    executablePath: "<exited>",
    arguments: [],
    workingDirectory: nil,
    exitedBeforeInspection: true
)
```

The HUD must display "Spirit slipped through before inspection" rather than
crashing or showing an empty panel.
