# Design Document

## Overview

WardTrigger is a standalone Swift CLI executable that deterministically triggers macOS TCC permission dialogs on demand. It lives at `WardTrigger/` in the repository root and is built as a separate target alongside the main `GatekeepersWard` app.

Its two roles are:

1. **Development harness** — give `TCCWatcher` and `ProcessInspector` a fast, repeatable stimulus during the Phase 2–4 iteration loop without ever touching the developer's daily IDE or terminal TCC permissions.
2. **Demo vehicle** — accept realistic-looking extra arguments (file paths, search terms) so that `sysctl(KERN_PROCARGS2)` inspection during a recorded demo shows a believable command line.

WardTrigger is intentionally minimal: a single `main.swift` entry point, three trigger functions, a `DispatchSemaphore` to keep the process alive during async TCC callbacks, and a companion reset script. The two parser components it exercises — `KERN_PROCARGS2` buffer parser and NDJSON log stream parser — live in the main `GatekeepersWardTests/` target and are the primary Property-Based Testing targets for the hackathon.

---

## Architecture

### Build system recommendation: Swift Package Manager

WardTrigger is built as an SPM executable target. SPM is preferred over a separate Xcode project because:

- A single `Package.swift` at the repo root can declare both the `GatekeepersWard` library target and the `WardTrigger` executable, keeping the build graph unified.
- Setting `CFBundleIdentifier` via SPM's `Info.plist` resource or via a `linkerSettings` flag is straightforward and does not require an Xcode project file.
- CI (`swift build`, `swift test`) works without Xcode on headless runners.

```
Package.swift
├── targets:
│   ├── GatekeepersWard          (library — Core/, Permissions/, HUD/, MenuBar/)
│   ├── WardTrigger              (executable — WardTrigger/)
│   └── GatekeepersWardTests     (test — unit + PBT)
```

`WardTrigger` declares a dependency on `GatekeepersWard` so its `main.swift` can import and exercise the real `parseProcArgsBuffer` and NDJSON parser functions during integration testing without duplicating code.

### Repository layout

```
WardTrigger/
├── main.swift                   ← entry point, CommandLine dispatch
├── Triggers.swift               ← triggerDocuments(), triggerContacts(), triggerMicrophone()
├── FolderTriggers.swift         ← probeProtectedFolder(), triggerDesktop(), triggerDownloads()
├── PrivacyTriggers.swift        ← triggerCalendar(), triggerReminders(), triggerCamera(), triggerPhotos()
├── AutomationTriggers.swift     ← triggerAppleEvents(), triggerScreenCapture()
├── TriggerCatalog.swift         ← wardTriggerCatalog: name, service key, summary, run
├── DemoEcho.swift               ← printDemoCommandLine(_:) helper
├── Dispatch.swift               ← runWardTriggerDispatch with injectable behaviors
└── Info.plist                   ← CFBundleIdentifier = com.gatekeepersward.ward-trigger
scripts/
├── run_ward_trigger.sh          ← LaunchServices launcher (Requirement 12)
└── reset_ward_trigger.sh        ← tccutil reset for 5 services scoped to Bundle_ID
```

### Process flow

```
CommandLine.arguments
        │
        ▼
  main.swift dispatch
  ┌─────────────────────────────────┐
  │ args[1] == "docs"    → triggerDocuments()    │
  │ args[1] == "contacts"→ triggerContacts()     │
  │ args[1] == "mic"     → triggerMicrophone()   │
  │ no args / unknown    → printUsage(); exit(1) │
  └─────────────────────────────────┘
        │
        │ (before calling trigger)
        ▼
  printDemoCommandLine(CommandLine.arguments.dropFirst())
        │
        ▼
  trigger function executes TCC API call
        │
        ├── contacts / mic: DispatchSemaphore.wait() keeps process alive
        │   until async callback fires → semaphore.signal()
        │
        └── docs: synchronous FileManager directory listing; no semaphore needed
        │
        ▼
  exit(0)   (trigger completed, regardless of Allow/Deny)
```

During a TCC dialog, `tccd` suspends the requesting thread. WardTrigger remains in the Darwin process table. `ProcessInspector` calls `sysctl(KERN_PROCARGS2, pid)` and recovers the full `argv` — including the subcommand and any extra demo arguments — before the user clicks any button.

---

## Components and Interfaces

### Expansion: table-driven dispatch (Requirement 13)

The original three-way `switch` does not scale to eleven triggers. Dispatch is now table-driven:

- `TriggerCatalog.swift` defines `wardTriggerCatalog: [TriggerSpec]` (`name`, `serviceKey`, `summary`, `run`).
- `WardTriggerBehaviors.triggers: [String: () -> Void]` replaces the per-trigger closures; `main.swift` wires `WardTriggerBehaviors.liveTriggers` (built from the catalog) and tests substitute recorder stubs for every catalog name.
- `printUsage` iterates the catalog, so the usage text can never drift from the dispatchable subcommands.

| Subcommand | Service key | API |
|---|---|---|
| `docs` / `desktop` / `downloads` | `SystemPolicy{Documents,Desktop,Downloads}Folder` | `contentsOfDirectory` via `probeProtectedFolder` |
| `contacts` | `AddressBook` | `CNContactStore.requestAccess` |
| `calendar` / `reminders` | `Calendar` / `Reminders` | EventKit (`requestFullAccessTo…` on macOS 14+) |
| `photos` | `Photos` | `PHPhotoLibrary.requestAuthorization(for: .readWrite)` |
| `mic` / `camera` | `Microphone` / `Camera` | `AVCaptureDevice.requestAccess` |
| `events` | `AppleEvents` | `NSAppleScript` → Finder (blocks while the dialog is up) |
| `screen` | `ScreenCapture` | `CGRequestScreenCaptureAccess` + 60 s `CGPreflightScreenCaptureAccess` poll |

Not included by design: Network/Removable Volumes (need a mounted volume), Full Disk Access and Developer Tool (no prompt), Accessibility / Input Monitoring (redirect to System Settings).

### `main.swift`

Entry point only — no logic beyond argument dispatch. Keeps the file under 60 lines.

```swift
// Pseudocode structure
let args = CommandLine.arguments
guard args.count >= 2 else {
    printUsage()
    exit(1)
}

let subcommand = args[1]
let extraArgs = Array(args.dropFirst(2))

printDemoCommandLine(subcommand: subcommand, extra: extraArgs)

switch subcommand {
case "docs":     triggerDocuments()
case "contacts": triggerContacts()
case "mic":      triggerMicrophone()
default:
    printUnrecognized(subcommand)
    printUsage()
    exit(1)
}

exit(0)
```

### `DemoEcho.swift`

```swift
/// Prints a simulated command-line invocation before the TCC trigger executes.
/// This makes the argv visible in the Fortress HUD's ProcessInspector output
/// and gives demo recordings a realistic-looking command.
///
/// Example output: `> docs rg "AWS_SECRET" ~/Documents/prod.env`
func printDemoCommandLine(subcommand: String, extra: [String])

/// Prints the usage summary listing all three valid subcommands.
func printUsage()

/// Prints an "unrecognized subcommand" error followed by the usage summary.
func printUnrecognized(_ arg: String)
```

### `Triggers.swift`

Three trigger functions. Each is self-contained and handles its own TCC callback lifecycle.

```swift
/// Triggers the kTCCServiceSystemPolicyDocumentsFolder TCC dialog by
/// performing a read-only directory listing of ~/Documents via
/// FileManager.contentsOfDirectory (a plain stat of ~/Documents/.ward_canary
/// is not intercepted by tccd).
/// Prints a status message whether access was granted, denied, or previously granted.
func triggerDocuments()

/// Triggers the kTCCServiceAddressBook TCC dialog via CNContactStore.requestAccess.
/// Uses a DispatchSemaphore to keep the process alive until the callback fires.
/// Imports: Contacts
func triggerContacts()

/// Triggers the kTCCServiceMicrophone TCC dialog via AVCaptureDevice.requestAccess(for: .audio).
/// Uses a DispatchSemaphore to keep the process alive until the callback fires.
/// Imports: AVFoundation
func triggerMicrophone()
```

`triggerContacts` and `triggerMicrophone` follow this semaphore pattern:

```swift
func triggerContacts() {
    let store = CNContactStore()
    let sem = DispatchSemaphore(value: 0)
    store.requestAccess(for: .contacts) { granted, error in
        if let error {
            print("[WardTrigger] CNContactStore error: \(error.localizedDescription)")
        }
        print(granted
            ? "[WardTrigger] Contacts access granted."
            : "[WardTrigger] Contacts access denied.")
        sem.signal()
    }
    sem.wait()
}
```

Using `DispatchSemaphore` here is intentional: WardTrigger is a CLI executable, not an app with a `RunLoop`. The semaphore is the simplest correct bridge between the async TCC callback and the synchronous `exit(0)` at the end of `main.swift`. `RunLoop.main.run()` is an alternative that also works, but requires explicit `CFRunLoopStop` in the callback and adds more code for no benefit.

### `reset_ward_trigger.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.gatekeepersward.ward-trigger"

for SERVICE in SystemPolicyDocumentsFolder SystemPolicyDesktopFolder \
               AddressBook AppleEvents Microphone; do
    tccutil reset "$SERVICE" "$BUNDLE_ID" || true
done

echo "[reset_trigger] TCC permissions cleared for $BUNDLE_ID."
echo "[reset_trigger] Next invocation of WardTrigger will prompt."
```

The `|| true` on each `tccutil` call satisfies `set -euo pipefail` (a non-zero exit from `tccutil` is normal if the service entry doesn't exist yet) while still aborting on unexpected script-level errors.

---

## Data Models

WardTrigger has no persistent data models. It is stateless between invocations. The relevant data model is the `argv` vector in the Darwin process, which `ProcessInspector` reads via `sysctl(KERN_PROCARGS2)`.

### KERN_PROCARGS2 buffer layout (for the parser in Core/)

```
Offset 0     : argc (CInt, 4 bytes, little-endian on arm64/x86_64)
Offset 4     : executable path (null-terminated UTF-8 C string)
               + padding null bytes until word-aligned
Offset N     : argv[0] (null-terminated UTF-8 C string)
Offset N+k   : argv[1] ...
               ...
Offset N+k+j : env[0], env[1], ...  (stop parsing at argc args)
```

Parsing contract:
1. Read `argc` from bytes `[0..<4]` using a typed pointer load.
2. Scan forward past the executable path (first `\0`).
3. Skip any additional null padding until a non-null byte is found.
4. Collect null-terminated strings until `count == argc`.
5. `guard offset < buffer.count` at every loop iteration.

### NDJSON log event (for the parser in Permissions/)

Each line from `/usr/bin/log stream --style ndjson` is a JSON object. The fields used by TCCWatcher:

| Key | Type | Notes |
|---|---|---|
| `timestamp` | String | ISO 8601 format |
| `subsystem` | String | Filter: `"com.apple.TCC"` |
| `category` | String | Usually `"access"` for prompts |
| `eventMessage` | String | Contains PID and service — version-sensitive wording |
| `processID` | Int | PID of `tccd` itself, not the requesting process |

The `clientPID` and `service` are extracted from `eventMessage` via regex, not from top-level JSON fields, because Apple does not expose them as first-class NDJSON keys.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: KERN_PROCARGS2 round-trip

*For any* valid argv vector whose elements are printable ASCII strings, encoding that vector into a `KERN_PROCARGS2`-format buffer and then parsing the buffer SHALL produce an argv vector equal to the original — same element count, same string values, same order.

**Validates: Requirements 10.3, 6.2**

### Property 2: KERN_PROCARGS2 parser never crashes

*For any* `[UInt8]` buffer of any length (including zero length), calling `parseProcArgsBuffer(_:)` SHALL return either `nil` or a valid structured result — it SHALL NOT trap, overflow, or access memory out of bounds.

**Validates: Requirements 10.4, 10.5**

### Property 3: NDJSON parser round-trip

*For any* well-formed NDJSON object with string-valued `subsystem`, `timestamp`, and `eventMessage` fields, parsing the line into a `TCCLogEvent` and serializing that event back to a JSON string and re-parsing SHALL produce a `TCCLogEvent` whose `subsystem`, `timestamp`, and `eventMessage` fields are equal to the originals.

**Validates: Requirements 11.3**

### Property 4: NDJSON parser never crashes

*For any* string (valid JSON, invalid JSON, empty string, binary-safe arbitrary Unicode), calling `extractTCCEvent(from:)` SHALL return either `nil` or a valid `TCCEvent` — it SHALL NOT trap.

**Validates: Requirements 11.4**

### Property 5: Extra argv passthrough

*For any* non-empty list of extra string arguments passed after the subcommand, the formatted demo command line printed to stdout SHALL contain each of those argument strings as a substring.

**Validates: Requirements 8.2, 8.4**

---

## Error Handling

| Scenario | Handling |
|---|---|
| No arguments | Print usage to stdout; `exit(1)` |
| Unrecognized subcommand | Print `"Unknown subcommand: <arg>"` + usage to stdout; `exit(1)` |
| Documents access already granted | Print `"[WardTrigger] Documents access already granted — no prompt will appear."`; `exit(0)` |
| `FileManager` error unrelated to TCC denial | Print `"[WardTrigger] File system error: <error.localizedDescription>"`; `exit(0)` |
| `CNContactStore` callback error non-nil | Print `"[WardTrigger] CNContactStore error: <error.localizedDescription>"` then print grant/deny outcome; `exit(0)` |
| AVFoundation callback fires with `granted == false` | Print denial message; `exit(0)` |
| Fatal system error in `sysctl` (unexpected) | Print `"[WardTrigger] Fatal: <description>"`; `exit(1)` |

All output goes to stdout (not stderr) so that test harnesses and CI scripts can capture it without redirecting stderr separately.

WardTrigger never exits with a non-zero code due to TCC denial — the distinction between "denied by user" and "prompt shown" is not a WardTrigger error. Exit code `1` is reserved exclusively for bad invocation (wrong arguments).

---

## Testing Strategy

### PBT framework: swift-testing with custom generators

WardTrigger's two PBT targets — `parseProcArgsBuffer` and `extractTCCEvent` — use Swift Testing (`import Testing`) with custom value generators rather than a third-party library. This choice:

- Avoids adding a dependency that may not be compatible with Swift 5.9 / Xcode 15.
- Keeps the test target buildable with `swift test` on CI without extra package resolution.
- Is sufficient for the two round-trip properties required by the hackathon scoring criteria.

Each property-based test generates N random inputs using a seeded `SystemRandomNumberGenerator` (or a simple Xorshift for reproducible CI runs), runs the function under test on each, and asserts the invariant holds.

```swift
// Feature: ward-trigger, Property 1: KERN_PROCARGS2 round-trip
@Test("KERN_PROCARGS2 round-trip for arbitrary printable-ASCII argv")
func kernProcArgs2RoundTrip() {
    var rng = SeededRNG(seed: 0xDEADBEEF)
    let iterations = ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    for _ in 0..<iterations {
        let argv = generatePrintableASCIIArgv(count: rng.next(in: 1...8), rng: &rng)
        let buffer = encodeProcArgsBuffer(argv: argv)
        let parsed = parseProcArgsBuffer(buffer)
        #expect(parsed?.arguments == argv)
    }
}
```

### Property tests (GatekeepersWardTests/Core/)

**`ParseProcArgsBufferTests.swift`**

| Test | Property / Classification |
|---|---|
| `kernProcArgs2RoundTrip()` | Property 1 — round-trip for printable ASCII argv |
| `noCrashOnArbitraryBytes()` | Property 2 — never crashes on random [UInt8] |
| `tooShortBufferReturnsNil()` | Edge case — buffer shorter than 4 bytes |
| `allZeroBufferReturnsNil()` | Edge case — all-zero bytes |
| `argcZeroReturnsEmptyArgv()` | Example — argc=0 produces empty argument list |
| `noNullTerminatorReturnsError()` | Edge case — no null byte in string region |

**`TCCEventParserTests.swift`** (GatekeepersWardTests/Permissions/)

| Test | Property / Classification |
|---|---|
| `ndjsonRoundTrip()` | Property 3 — round-trip for well-formed NDJSON lines |
| `noCrashOnArbitraryStrings()` | Property 4 — never crashes on arbitrary input |
| `patternAExtractionFromSonoma()` | Example — Pattern A regex, Sonoma fixture |
| `patternBExtractionFromVentura()` | Example — Pattern B regex, Ventura fixture |
| `patternCFallbackOnUnknownMessage()` | Example — Pattern C fallback fires |
| `malformedJSONReturnsNil()` | Edge case — invalid JSON silently returns nil |
| `allTCCServiceCasesMapped()` | Example — exhaustive TCCService.init(rawKey:) coverage |

### Unit tests (GatekeepersWardTests/WardTrigger/)

**`SubcommandDispatchTests.swift`**

| Test | Classification |
|---|---|
| `docsSubcommandCallsTriggerDocuments()` | Example |
| `contactsSubcommandCallsTriggerContacts()` | Example |
| `micSubcommandCallsTriggerMicrophone()` | Example |
| `noArgsExitsWithCode1AndPrintsUsage()` | Edge case |
| `unknownSubcommandExitsWithCode1()` | Edge case |
| `validSubcommandExitsWithCode0()` | Example |

**`DemoEchoTests.swift`**

| Test | Classification |
|---|---|
| `extraArgsAppearsInOutput()` | Property 5 — extra args echoed |
| `noExtraArgsProducesMinimalOutput()` | Example |

### Test file locations

```
GatekeepersWardTests/
├── Core/
│   ├── ParseProcArgsBufferTests.swift   ← PBT + unit (Properties 1, 2)
│   └── ProcessTreeTests.swift
├── Permissions/
│   ├── TCCEventParserTests.swift        ← PBT + unit (Properties 3, 4)
│   └── TCCServiceMappingTests.swift
├── WardTrigger/
│   ├── SubcommandDispatchTests.swift
│   └── DemoEchoTests.swift             ← Property 5
└── Fixtures/
    ├── TCCLogFixtures.swift
    └── ProcArgsFixtures.swift
```

### Iteration counts

```swift
let iterationCount = ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
```

### CI integration

The `.kiro/hooks/` hook runs on PostTaskExec and executes `swift test --skip integration` to exclude tests that require a live TCC prompt. Integration tests (those calling `sysctl` on the current process, or requiring a real `CNContactStore`) are tagged `.integration` and skipped in CI.
