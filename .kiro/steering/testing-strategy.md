---
inclusion: auto
name: testing-strategy
description: Testing rules for Gatekeeper's Ward — property-based testing targets, unit test structure, WardTrigger test harness usage, tccutil reset workflow, and what must be tested before submission. Read before writing any test or modifying GatekeepersWardTests/.
---

# Testing Strategy

Testing is a scored requirement — judges explicitly check for Property-Based
Testing (PBT) and ask *"Did PBT catch issues that unit tests would have missed?"*
This document is the single source of truth for what to test, how to test it,
and how to trigger real TCC events during development.

---

## 1. Test target structure

```
GatekeepersWardTests/
├── Core/
│   ├── ProcessInspectorTests.swift      ← unit + PBT
│   ├── ParseProcArgsBufferTests.swift   ← PBT primary target
│   └── ProcessTreeTests.swift          ← unit
├── Permissions/
│   ├── TCCWatcherTests.swift           ← unit (no live log stream)
│   ├── TCCEventParserTests.swift       ← unit + PBT
│   └── TCCServiceMappingTests.swift    ← unit (exhaustive enum coverage)
├── HUD/
│   └── RiskTagViewTests.swift          ← unit (argument detection logic)
└── Fixtures/
    ├── TCCLogFixtures.swift            ← static NDJSON fixture strings
    └── ProcArgsFixtures.swift          ← static byte buffer fixtures
```

All test files use `swift-testing` (`import Testing`) for new tests.
`XCTest` is acceptable for AppKit/UI tests that require `XCTestCase`.

---

## 2. Property-Based Testing — required targets

PBT is **mandatory** for these two parsers. They are the highest bug-risk
surfaces in the project and the ones judges will ask about.

### 2a. `parseProcArgsBuffer(_:)` — the KERN_PROCARGS2 parser

This function must withstand arbitrary byte sequences without crashing,
hanging, or returning malformed data.

PBT properties to verify:

| Property | Description |
|---|---|
| **No crash** | Any `[UInt8]` input of any length returns `nil` or a valid result — never traps |
| **argc honoured** | If `argc = n` is encoded in bytes 0–3, result contains ≤ n arguments |
| **Null safety** | Input with no null bytes anywhere returns `nil`, not a partial result |
| **Empty input** | Zero-length buffer returns `nil` |
| **Oversized argc** | `argc` value larger than the remaining buffer length returns `nil` or a truncated result without OOB read |
| **Non-UTF8 bytes** | Buffers containing invalid UTF-8 sequences produce arguments as empty strings or are skipped — never crash |
| **Idempotent** | Parsing the same buffer twice produces the same result |

PBT framework: use Swift Testing's built-in
[`withKnownIssue`](https://developer.apple.com/documentation/testing/known-issues)
and property-style parameterization, or integrate
[SwiftCheck](https://github.com/typelift/SwiftCheck) as a test-only dependency.

```swift
// Example using a simple home-grown generator if SwiftCheck is not added
@Test("parseProcArgsBuffer never crashes on arbitrary input", arguments: randomByteArrays(count: 500))
func noCrashOnArbitraryInput(_ buffer: [UInt8]) {
    // Must not trap
    let result = parseProcArgsBuffer(buffer)
    // result is nil or a valid ProcessSnapshot — both are acceptable
    _ = result
}
```

Seed a deterministic random source with a fixed seed in CI so failures are
reproducible:

```swift
var rng = SystemRandomNumberGenerator()  // or a seeded Xorshift for CI
```

### 2b. `extractTCCEvent(from:)` — the NDJSON event parser

| Property | Description |
|---|---|
| **No crash** | Arbitrary JSON objects (random keys, random value types) return `nil` or a valid `TCCEvent`, never trap |
| **Non-JSON input** | Arbitrary strings that are not valid JSON return `nil` |
| **Missing keys** | JSON objects with any subset of expected keys produce either a partial event or `nil` |
| **All TCCService cases** | Every `kTCCService*` string maps to a non-`.unknown` case or `.unknown(string)` — never silently drops |
| **Timestamp round-trip** | Timestamp strings in ISO 8601 format parse to a `Date` within ±1 second of the expected value |
| **Whitespace/newline in message** | `eventMessage` containing embedded newlines does not break regex matching |

---

## 3. Unit tests — required coverage

Beyond PBT, these specific behaviours must have explicit unit tests:

### Core/
- `ProcessInspector` with a known-exited PID returns a snapshot with
  `exitedBeforeInspection == true`
- `ProcessTree.walk(from:)` with PID 1 (launchd) terminates after one node
- `ProcessTree.walk(from:)` with the current process's PID includes
  `ProcessInfo.processInfo.processIdentifier` in the chain

### Permissions/
- Pattern A regex extracts correct `clientPID`, `responsiblePID`, and
  `service` from each `TCCLogFixtures.patternA*` fixture
- Pattern B regex extracts correctly from each `TCCLogFixtures.patternB*` fixture
- Malformed fixture returns `nil` without throwing
- `TCCService.init(rawKey:)` covers all 13 mapped cases plus one unmapped key
  that produces `.unknown("kTCCServiceFictional")`

### HUD/
- `isRisky(_:)` returns `true` for each pattern in `suspiciousPatterns`
- `isRisky(_:)` is case-insensitive: `".PEM"` and `".pem"` both return `true`
- `isRisky(_:)` returns `false` for `"README.md"`, `"main.swift"`,
  `"~/Documents/notes.txt"`

---

## 4. Test fixtures

Store all test input data in `GatekeepersWardTests/Fixtures/`. Never construct
fixture data inline in test bodies — it makes tests hard to read and impossible
to share across files.

### `TCCLogFixtures.swift`

```swift
enum TCCLogFixtures {
    /// macOS 14 Sonoma / 15 Sequoia — well-formed Pattern A
    static let patternA_documents = """
    {"timestamp":"2026-11-06T14:23:01.123456-0800","subsystem":"com.apple.TCC",\
    "category":"access","processID":312,"eventMessage":"requestor: TCCDProcess: \
    identifier=com.cursor.Cursor, pid=14201, auid=501, binary_path=/Applications/Cursor.app/Contents/MacOS/Cursor \
    is checking access for accessor TCCDProcess: ... service=kTCCServiceSystemPolicyDocumentsFolder"}
    """

    /// macOS 13 Ventura — well-formed Pattern B
    static let patternB_documents = """
    {"timestamp":"2026-11-06T14:23:01.123456-0800","subsystem":"com.apple.TCC",\
    "category":"access","processID":312,"eventMessage":"Prompting user for \
    [kTCCServiceSystemPolicyDocumentsFolder] from client [/usr/local/bin/rg] \
    with PID [14582] responsible PID [14201]"}
    """

    /// Missing clientPID — should produce Pattern C fallback
    static let patternC_fallback = """
    {"timestamp":"2026-11-06T14:23:01.123456-0800","subsystem":"com.apple.TCC",\
    "category":"access","processID":312,"eventMessage":"some new format we haven't seen"}
    """

    /// Malformed JSON — should return nil
    static let malformedJSON = "{ this is not valid json }"

    /// Empty string — should return nil
    static let emptyString = ""
}
```

### `ProcArgsFixtures.swift`

Provide at least:
- A well-formed `KERN_PROCARGS2` buffer for `["rg", "AWS_SECRET", "~/Documents"]`
  with `argc = 3` and correct null-termination.
- A buffer with `argc = 0`.
- A buffer that is exactly 4 bytes (only the `argc` field, no strings).
- A buffer of all-zero bytes.

Build these as computed `static var` properties using explicit byte arrays
so they are readable and version-controlled.

---

## 5. WardTrigger — development test harness

`WardTrigger` (bundle ID `com.gatekeepersward.ward-trigger`) is the dedicated
app for triggering real TCC prompts during development. Never use your primary
IDE or personal apps to generate test prompts — resetting their TCC permissions
disrupts your daily workflow.

### Reset before each test session

Run the companion script before every TCC testing session or demo recording:

```bash
bash scripts/reset_ward_trigger.sh
```

The script clears all five TCC scopes for `WardTrigger` only:

```bash
tccutil reset SystemPolicyDocumentsFolder com.gatekeepersward.ward-trigger
tccutil reset SystemPolicyDesktopFolder   com.gatekeepersward.ward-trigger
tccutil reset AddressBook                 com.gatekeepersward.ward-trigger
tccutil reset AppleEvents                 com.gatekeepersward.ward-trigger
tccutil reset Microphone                  com.gatekeepersward.ward-trigger
```

This resets permissions only for `WardTrigger`, not for any other app.

### Trigger modes

| Mode | Command | TCC service triggered |
|---|---|---|
| Filesystem / Documents | `WardTrigger docs` | `kTCCServiceSystemPolicyDocumentsFolder` |
| Contacts / AddressBook | `WardTrigger contacts` | `kTCCServiceAddressBook` |
| Microphone | `WardTrigger mic` | `kTCCServiceMicrophone` |

Extra positional arguments after the subcommand are echoed as a simulated
command line before the trigger fires — useful for demo recordings:

```bash
WardTrigger docs rg '"AWS_SECRET_KEY"' ~/Documents/prod.env
# stdout: > docs rg "AWS_SECRET_KEY" ~/Documents/prod.env
```

This makes the argv visible in ProcessInspector's `sysctl(KERN_PROCARGS2)`
output while the TCC dialog is suspended on screen.

### Launch via LaunchServices — `scripts/run_ward_trigger.sh` (required for prompts)

Launching the binary as a terminal child (`swift run`, or executing it
directly) never fires a prompt: macOS attributes the TCC decision to the
*responsible process* — the terminal — which typically already has access, so
WardTrigger's bundle ID is never consulted and `reset_ward_trigger.sh` has nothing
to reset. Always trigger prompts through the launcher:

```bash
scripts/run_ward_trigger.sh docs rg "AWS_SECRET" ~/Documents/prod.env   # or contacts / mic
cat tmp/ward-trigger.out    # captured stdout (reset_ward_trigger.sh removes it)
scripts/reset_ward_trigger.sh    # re-arm first-prompt state
```

`run_ward_trigger.sh` assembles `.build/WardTrigger.app` (same bundle ID) and
launches it via `open` so WardTrigger is its own responsible process. The
wrapper requires three things, all handled by the script — remove any one and
`tccd` silently auto-denies with **no dialog**:

1. **Usage-description keys** (`NSMicrophoneUsageDescription`,
   `NSContactsUsageDescription`, `NSDocumentsFolderUsageDescription`,
   `NSDesktopFolderUsageDescription`) in the Info.plist
2. **A code-sealed bundle** — `codesign --force --sign - .build/WardTrigger.app`
3. **A foreground app** (`LSUIElement=false`) — folder-access prompts are
   suppressed for background agents (mic/contacts prompt either way)

Additional behavior facts confirmed on macOS 26/27:

- Folder TCC gates **directory enumeration**, not `stat` — `triggerDocuments`
  lists `~/Documents` (checking for `.ward_canary`); a `stat` of a path inside
  the folder is not intercepted.
- `~/Documents/.ward_canary` must exist (create it once with `touch`) or the
  Documents probe errors before TCC evaluates.
- Grants are tied to the ad-hoc signature: a rebuild changes the identity, so
  re-run `reset_ward_trigger.sh` if prompts stop appearing after `swift build`.
- Diagnose "did a prompt appear" with `pgrep -f WardTrigger` — alive means
  suspended on a pending dialog; exited instantly means auto-deny.

### Verification workflow

During Phase 2 development, the minimal end-to-end verification loop is:

```
1. bash scripts/reset_ward_trigger.sh
2. Launch GatekeepersWard.app (with console output visible)
3. Run: scripts/run_ward_trigger.sh docs
4. Verify in console: "TCCWatcher received event: service=documents pid=XXXX"
5. Verify: ProcessInspector printed arguments including "docs"
6. Verify: FortressHUD window appeared on screen
```

Repeat with `scripts/run_ward_trigger.sh contacts` and `scripts/run_ward_trigger.sh mic`
to exercise all three TCC service paths.

---

## 6. CI and hooks

The `.kiro/hooks/` pre-commit hook must run `swift test` before allowing a
commit. The test suite must pass in under 30 seconds — if individual PBT runs
are slow, cap the iteration count to 200 in CI via an environment variable:

```swift
let iterationCount = ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
```

Tests that require a real running process (integration tests for
`ProcessInspector` calling `sysctl` on the current PID) should be gated with:

```swift
#if !CI
// ... integration test body
#endif
```

Or use `.tags(.integration)` in Swift Testing and exclude the tag in CI:
```bash
swift test --filter "!integration"
```

---

## 7. What judges will ask about PBT

From `ScoringWell.md`, judges specifically ask: *"Did PBT help catch any issues
you might have missed with unit tests?"*

Document any bugs PBT found in `docs/devlog.md` as they are discovered. A good
answer includes at least one concrete example:

> "PBT on `parseProcArgsBuffer` found that when `argc` encoded in the header
> was larger than the number of actual null-terminated strings in the remaining
> buffer, the parser would loop past the end of the array. The fix added a
> `guard offset < buffer.count` check before each string read."

This kind of discovery story is worth a point in the Technological Implementation
pillar. Keep notes as you go — don't reconstruct them from memory at submission time.
