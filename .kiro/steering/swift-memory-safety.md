---
inclusion: auto
name: swift-memory-safety
description: Rules for safe raw-pointer and unmanaged-memory use in Swift — covers UnsafeRawBufferPointer, withUnsafeBytes, CChar buffers, and Unmanaged<T> patterns used throughout ProcessInspector and the KERN_PROCARGS2 parser.
---

# Swift Memory Safety — Raw Pointers & Unmanaged Objects

Gatekeeper's Ward makes direct Darwin system calls that return raw byte buffers.
This document establishes the rules for handling that memory safely in Swift
without force-unwraps, dangling pointers, or buffer overreads.

---

## 1. The golden rule: never escape an unsafe pointer

Unsafe pointer types (`UnsafePointer`, `UnsafeRawPointer`,
`UnsafeRawBufferPointer`, `UnsafeMutablePointer`) are **scoped**.
They are only valid inside the closure or function that provides them.

```swift
// ✅ Correct — pointer used only inside the closure
let value = withUnsafeBytes(of: someStruct) { ptr -> UInt32 in
    ptr.load(as: UInt32.self)
}

// ❌ Wrong — ptr escapes its valid lifetime
var storedPtr: UnsafeRawBufferPointer?
withUnsafeBytes(of: someStruct) { ptr in
    storedPtr = ptr   // dangling pointer after closure returns
}
```

If you need the value after the closure, copy it into a Swift value type inside
the closure.

---

## 2. Reading typed values from raw buffers

Use `UnsafeRawBufferPointer.load(fromByteOffset:as:)` rather than `memcpy`
into a Swift variable.

```swift
// ✅ Typed load — correct alignment handling
let argc: CInt = buffer.withUnsafeBytes { ptr in
    ptr.load(fromByteOffset: 0, as: CInt.self)
}

// ❌ memcpy into a Swift variable — bypasses Swift's memory model
var argc: CInt = 0
memcpy(&argc, buffer, MemoryLayout<CInt>.size)
```

`load(fromByteOffset:as:)` asserts alignment in debug builds and is the
documented Swift API for this pattern.

---

## 3. Walking null-terminated C strings in a buffer

The `KERN_PROCARGS2` parser walks a `[UInt8]` buffer collecting C strings.
Use the `baseAddress` of a `withUnsafeBytes` closure, not raw index arithmetic
with `CChar` casts.

```swift
func parseCString(from buffer: [UInt8], startingAt offset: inout Int) -> String? {
    guard offset < buffer.count else { return nil }
    let slice = buffer[offset...]
    guard let nullIndex = slice.firstIndex(of: 0) else { return nil }
    let strSlice = buffer[offset..<nullIndex]
    offset = nullIndex + 1   // advance past the null terminator
    return String(bytes: strSlice, encoding: .utf8)
}
```

- Use `firstIndex(of: 0)` on the `[UInt8]` slice to locate the null terminator
  without casting to `CChar`.
- Build the `String` with `String(bytes:encoding:)` — this is bounds-safe and
  returns `nil` for non-UTF-8 data rather than crashing.
- Never call `String(cString:)` on an arbitrary `[UInt8]` offset without first
  verifying a null terminator exists within the buffer bounds.

---

## 4. assumingMemoryBound — when and how

`assumingMemoryBound(to:)` is needed when bridging C APIs that return `void *`
(or Swift `UnsafeRawPointer`) and you know the concrete type.

Rules:
1. Only call it when you have authoritative knowledge of the layout (e.g., a
   documented C struct from a Darwin header).
2. Immediately bind in the narrowest scope possible.
3. Do not store the bound pointer; dereference it once and copy the value.

```swift
// Reading vip_path from proc_vnodepathinfo
let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { rawPtr -> String in
    let charPtr = rawPtr.baseAddress!.assumingMemoryBound(to: CChar.self)
    return String(cString: charPtr)   // safe — CChar array has null terminator by design
}
```

The only acceptable force-unwrap (`!`) in production code is `baseAddress!` on a
non-empty `UnsafeRawBufferPointer`, where emptiness has already been guarded.

---

## 5. Unmanaged<T> and CFTypeRef bridging

Avoid `Unmanaged` in new code. macOS 13+ APIs are fully ARC-annotated.
If you must call a legacy C API that returns an unretained `CFTypeRef`:

```swift
// Take ownership explicitly
let result: CFString = Unmanaged<CFString>
    .fromOpaque(rawPtr)
    .takeRetainedValue()   // or .takeUnretainedValue() if the API says +0
```

Document the retain/release policy of the API in a `///` comment on the
call site so future readers don't have to re-research it.

Never use `passRetained` / `passUnretained` without a matching `release()` or
ARC take on the other end.

---

## 6. Buffer size discipline

Any function that allocates a buffer for a C API must:

1. Obtain the required size via the two-phase `sysctl` pattern (see
   `darwin-c-interop.md`).
2. Declare the buffer as `var buffer = [UInt8](repeating: 0, count: size)`.
3. Slice to `buffer[..<actualSize]` after the second call if the API updates
   the size parameter.
4. Never index `buffer[offset]` without a preceding `guard offset < buffer.count`.

---

## 7. No raw pointer arithmetic

Swift discourages pointer arithmetic. Use the collection APIs on buffer types
instead.

```swift
// ✅ Idiomatic — collection API
let subSlice = buffer[offset..<(offset + length)]

// ❌ Pointer arithmetic — fragile and error-prone
let ptr = buffer.withUnsafeBufferPointer { $0.baseAddress! + offset }
```

The only exception is `proc_pidinfo` struct field access, which uses Swift's
built-in member access on the C struct — no manual offset math needed.

---

## 8. Property-based testing targets

The following functions are the highest-risk raw memory sites and **must** have
property-based tests (see `swift-testing-pbt.md` when created):

| Function | Risk | PBT strategy |
|---|---|---|
| `parseProcArgsBuffer(_:)` | Buffer overread, non-UTF8 data | Arbitrary `[UInt8]` inputs, fuzz argc/offsets |
| `parseCString(from:startingAt:)` | Missing null terminator | Buffers with no null byte, empty buffers |
| `ProcessInspector.getDetails(pid:)` | Invalid/exited PID | PID values: 0, -1, Int32.max, current PID |

---

## 9. Swift Concurrency safety

`[UInt8]` buffers passed into `async` functions must be treated as copied
value types — they are, but make this explicit by not passing `inout` buffers
across `await` suspension points.

```swift
// ✅ Copy before suspending
let bufferCopy = buffer
let result = await Task.detached { parseProcArgsBuffer(bufferCopy) }.value

// ❌ inout across await — compiler error in strict concurrency, avoid the pattern
```

Keep all `UnsafeRawPointer` work in synchronous helper functions called from
`async` contexts; this keeps the unsafe surface small and auditable.
