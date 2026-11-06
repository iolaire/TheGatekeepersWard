---
inclusion: auto
name: swift-coding-standards
description: Swift coding conventions for Gatekeeper's Ward — no force-unwrap policy, file size limits, doc comment requirements, type preferences, concurrency patterns, and naming rules. Read before writing any Swift file.
---

# Swift Coding Standards

These are the non-negotiable conventions for every Swift file in this project.
They apply equally to production code and test code.

---

## 1. No force-unwrap in production paths

`!` is banned in any file under `GatekeepersWard/`. The only permitted
exception is `baseAddress!` on a non-empty `UnsafeRawBufferPointer` where
emptiness has been explicitly guarded one line above (see `swift-memory-safety.md`).

Prefer in this order:
1. `guard let` / `guard else { return nil }` — for functions that can
   legitimately produce no result
2. `if let` — for optional branches
3. `??` with a safe default — for non-critical UI values
4. `try?` — for calls where failure is acceptable
5. `try` + structured error handling — for calls where failure should propagate

```swift
// ✅
guard let pid = extractPID(from: message) else { return nil }

// ✅
let label = snapshot.executablePath.lastPathComponent ?? "<unknown>"

// ❌ Force-unwrap
let pid = extractPID(from: message)!
```

Test code may use `XCTUnwrap(_:)` instead of `!` — it throws a test failure
on nil rather than crashing the process.

---

## 2. File size limit — ~300 lines

When a file approaches 300 lines, extract to a new type. Common extraction
patterns:

- A large `switch` on an enum → a lookup table (`Dictionary`) or a dedicated
  mapper type
- A view that grows beyond 200 lines → extract subviews into their own `View`
  structs in separate files
- A class with multiple responsibilities → split along responsibility lines

The 300-line ceiling is a signal, not a hard compiler error. Use judgment;
a 320-line file with a clean single responsibility is fine. A 220-line file
doing three jobs needs extraction.

---

## 3. Doc comments on every public type and function

Every `public` and `internal` type, property, and function must have a `///`
doc comment. `private` helpers are encouraged but not required.

```swift
/// Resolves the full process details for a given PID using Darwin's
/// `sysctl(KERN_PROCARGS2)` and `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
///
/// - Parameter pid: The process ID to inspect. Must be a currently running
///   process owned by the current user.
/// - Returns: A `ProcessSnapshot` if inspection succeeds, or `nil` if the
///   process has exited or belongs to another user (EPERM).
func snapshot(pid: pid_t) -> ProcessSnapshot?
```

For SwiftUI `View` types, document the view's purpose and any required
environment or binding contracts at the type level:

```swift
/// Displays the Castle Keep risk analysis for a single `ProcessSnapshot`.
///
/// Expects `ProcessSnapshot` to be non-nil; shows a "Spirit slipped away"
/// placeholder if the snapshot reports `exitedBeforeInspection == true`.
struct FortressHUDView: View { ... }
```

---

## 4. Value types over classes

Prefer `struct` unless reference semantics are explicitly required.

Use a `class` (or `actor`) when:
- The type wraps an OS resource that must be deallocated (`NSPanel`, `Process`,
  `Pipe`, `FileHandle`)
- The type needs to be `@MainActor` or is an `actor`
- Identity matters (two instances of the same data should be distinguishable)

`ProcessSnapshot`, `TCCEvent`, `RiskTag`, `ProcessNode` must be `struct`.
`FortressHUDWindow`, `TCCWatcher`, `MenuBarController` must be `class` or
`actor`.

---

## 5. Concurrency model

This project uses Swift Concurrency (async/await + actors) for all new code.
`DispatchQueue` and completion handlers are permitted only when bridging legacy
AppKit/Darwin APIs that don't yet have async versions.

Rules:
- UI updates always happen on `@MainActor`. Annotate view models and
  `@Observable` objects with `@MainActor`.
- `TCCWatcher` and `ProcessInspector` are `actor` types — they do CPU work off
  the main thread and publish results via `AsyncStream` or `await`.
- Never use `DispatchQueue.main.async` inside a `@MainActor` context —
  it's redundant and obscures intent.
- `Task.detached` requires explicit justification in a comment; prefer
  structured `Task {}` from the calling context.

```swift
// ✅ Structured concurrency — inherits actor context from caller
Task {
    let snapshot = await ProcessInspector.shared.snapshot(pid: event.clientPID)
    await MainActor.run { hudViewModel.update(with: snapshot) }
}

// ❌ DispatchQueue in a new async function
DispatchQueue.global().async {
    let snapshot = ProcessInspector.shared.snapshot(pid: pid)
    DispatchQueue.main.async { ... }
}
```

---

## 6. Error types

Use typed errors (`enum` conforming to `Error`) for any `throws` function whose
callers need to distinguish failure modes.

```swift
enum ProcessInspectionError: Error {
    case processNotFound(pid: pid_t)
    case permissionDenied(pid: pid_t)
    case bufferParseFailure(reason: String)
}
```

Avoid `throw NSError(...)` in new Swift code.
Avoid stringly-typed errors (`throw "something went wrong"`).

For functions where the only meaningful caller response is "show a fallback",
return `Optional` instead of throwing — reserve `throws` for errors callers
must handle explicitly.

---

## 7. Naming conventions

Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). Specific rules for this project:

- Types named after their lore concept where it aids clarity:
  - `ProcessSnapshot` (not `ProcessInfo` — conflicts with Foundation)
  - `TCCEvent` (not `PermissionEvent`)
  - `FortressHUDWindow` (not `HUDWindow`)
- Boolean properties use the `is` / `has` / `should` prefix:
  `isRisky`, `hasExited`, `shouldAutoDismiss`
- Async functions ending in a noun are preferred over `-Async` suffixes:
  `func snapshot(pid:) async -> ProcessSnapshot?`
  not `func getSnapshotAsync(pid:)`
- Avoid abbreviations except for well-known ones: `pid`, `url`, `id`.
  Use `executable` not `exec`, `arguments` not `args` in public APIs
  (private locals may use short names).

---

## 8. Import hygiene

Only import what a file actually uses. Sort imports alphabetically within groups:

```swift
// 1. System / Apple frameworks
import AppKit
import Darwin
import Foundation
import SwiftUI

// 2. (no third-party frameworks in this project)
```

Never `import UIKit` — this is a macOS-only project.
Never `import XCTest` in production targets.

---

## 9. SwiftUI-specific rules

- Extract any `body` exceeding ~40 lines into named subviews.
- `@State` is private by default — always mark it `private`.
- Avoid `@ObservableObject` / `@StateObject` for new types; use `@Observable`
  (Swift 5.9 / macOS 14+ macro). For macOS 13 compatibility, use `@StateObject`
  with an `ObservableObject` conforming class and document the macOS version
  constraint.
- Never put business logic inside `body`. Extract to a view model or computed
  property.

---

## 10. Logging

Use `os.Logger` (not `print`) in all production paths.

```swift
import os.log
private let logger = Logger(subsystem: "com.gatekeepersward.app", category: "ProcessInspector")

logger.debug("sysctl buffer size: \(size, privacy: .public)")
logger.error("proc_pidinfo failed for pid \(pid, privacy: .public): \(errStr, privacy: .public)")
```

- `.debug` — verbose, off in release builds by default.
- `.info` — key lifecycle events (watcher started, event received).
- `.error` — unexpected failures that should be investigated.
- Never log user data (file paths, process arguments) above `.debug` level.
- Mark values as `privacy: .public` only when they cannot contain PII.
