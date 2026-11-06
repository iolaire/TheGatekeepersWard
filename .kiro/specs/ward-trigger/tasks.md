# Implementation Plan: WardTrigger

## Overview

Build the `WardTrigger` Swift CLI executable as an SPM target alongside the main `GatekeepersWard` library. The implementation proceeds in layers: project scaffold first, then the three Swift source files in dependency order (`DemoEcho` → `Triggers` → `main`), then the reset script, then property-based and unit tests, and finally CI hook integration. Each step is independently buildable and testable so that `ProcessInspector` / `TCCWatcher` development can begin as soon as the trigger fires a real TCC dialog.

## Tasks

- [x] 1. Set up SPM project scaffold

  - [x] 1.1 Create `Package.swift` at the repository root declaring three targets: `GatekeepersWard` (library, sources in `GatekeepersWard/`), `WardTrigger` (executable, sources in `WardTrigger/`, depends on `GatekeepersWard`), and `GatekeepersWardTests` (test target, depends on `GatekeepersWard`). Set `platforms: [.macOS(.v13)]` and `swift_tools_version: "5.9"`.
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 1.2 Create `WardTrigger/Info.plist` with `CFBundleIdentifier` set to `com.gatekeepersward.ward-trigger`. Wire it into the `WardTrigger` target via SPM's `infoPlistSettings` or a `linkerSettings` `-sectcreate` flag so the bundle ID is embedded in the binary at build time.
    - _Requirements: 2.1, 2.2_

  - [x] 1.3 Create stub Swift source files (`WardTrigger/main.swift`, `WardTrigger/DemoEcho.swift`, `WardTrigger/Triggers.swift`) containing empty or `// TODO` placeholders so that `swift build --target WardTrigger` succeeds from this point forward.
    - _Requirements: 1.1_

- [x] 2. Implement `DemoEcho.swift`

  - [x] 2.1 Implement `printDemoCommandLine(subcommand:extra:)` in `WardTrigger/DemoEcho.swift`. The function should print a formatted line like `> docs rg "AWS_SECRET" ~/Documents/prod.env` — the `>` prefix, the subcommand, then each extra argument space-separated. Add the doc comment (`///`) required by coding standards.
    - _Requirements: 8.2, 8.4_

  - [x] 2.2 Implement `printUsage()` in `WardTrigger/DemoEcho.swift`. Output must list all three subcommands (`docs`, `contacts`, `mic`) each with a one-line description on the same line, to standard output.
    - _Requirements: 1.5_

  - [x] 2.3 Implement `printUnrecognized(_:)` in `WardTrigger/DemoEcho.swift`. Output must identify the unrecognized argument by value (e.g., `"Unknown subcommand: foo"`) and then call `printUsage()`.
    - _Requirements: 1.6_

  - [x]* 2.4 Write property test for `printDemoCommandLine` (Property 5)
    - Create `GatekeepersWardTests/WardTrigger/DemoEchoTests.swift`.
    - **Property 5: Extra argv passthrough** — *For any* non-empty list of extra string arguments passed after the subcommand, the formatted demo command line printed to stdout SHALL contain each of those argument strings as a substring.
    - Use a seeded generator producing random word lists (1–6 elements); capture stdout via a pipe or string buffer; assert each word appears in the output string.
    - Run at least 200 iterations (`CI` env var present) or 1000 locally.
    - Tag: `// Feature: ward-trigger, Property 5: extra argv passthrough`
    - _Requirements: 8.2, 8.4_

  - [x]* 2.5 Write unit tests for `DemoEcho.swift`
    - Extend `GatekeepersWardTests/WardTrigger/DemoEchoTests.swift` with example-based tests:
      - `noExtraArgsProducesMinimalOutput()` — empty extra array, output contains subcommand only after `> `.
      - `usageMentionsAllThreeSubcommands()` — `printUsage()` output contains `"docs"`, `"contacts"`, `"mic"`.
      - `unrecognizedPrefixesArgName()` — `printUnrecognized("bogus")` output contains `"bogus"`.
    - _Requirements: 1.5, 1.6, 8.2_

- [x] 3. Checkpoint — build passes, DemoEcho tests pass
  - Run `swift build --target WardTrigger` and `swift test --filter DemoEchoTests`. Ensure all tests pass. Ask the user if questions arise.

- [x] 4. Implement `Triggers.swift`

  - [x] 4.1 Implement `triggerDocuments()` in `WardTrigger/Triggers.swift`. Use a read-only `FileManager.default.contentsOfDirectory(atPath:)` listing of `NSHomeDirectory() + "/Documents"` to attempt access that causes `tccd` to evaluate the `kTCCServiceSystemPolicyDocumentsFolder` entitlement. Handle three outcomes: (a) access already granted — print the "previously granted" message; (b) TCC denial error — print that the prompt should have appeared; (c) other file-system error — print the `localizedDescription`. The function must be read-only and must not create or modify the canary file.
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 4.2 Implement `triggerContacts()` in `WardTrigger/Triggers.swift`. Import `Contacts`. Call `CNContactStore().requestAccess(for: .contacts)`. Use `DispatchSemaphore(value: 0)` to block until the callback fires. In the callback: if `error != nil` print the `localizedDescription`; then print grant or denial message; call `sem.signal()`. After `sem.wait()` returns the function exits normally.
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 4.3 Implement `triggerMicrophone()` in `WardTrigger/Triggers.swift`. Import `AVFoundation`. Call `AVCaptureDevice.requestAccess(for: .audio)`. Use the same `DispatchSemaphore` pattern as `triggerContacts`. Print grant or denial message inside the callback before signalling.
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 5. Implement `main.swift`

  - [x] 5.1 Implement the dispatch logic in `WardTrigger/main.swift`. Read `CommandLine.arguments`. Guard that `count >= 2` — if not, call `printUsage()` and `exit(1)`. Extract `args[1]` as the subcommand and `Array(args.dropFirst(2))` as extra args. Call `printDemoCommandLine(subcommand:extra:)`. Switch on the subcommand: `"docs"` → `triggerDocuments()`, `"contacts"` → `triggerContacts()`, `"mic"` → `triggerMicrophone()`, default → `printUnrecognized` + `exit(1)`. Call `exit(0)` after a successful trigger. Keep the file under 60 lines.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 8.1, 8.3_

  - [x]* 5.2 Write unit tests for subcommand dispatch
    - Create `GatekeepersWardTests/WardTrigger/SubcommandDispatchTests.swift`.
    - Use protocol-based dependency injection or function-pointer substitution so trigger functions can be replaced with stubs in tests. Tests to include:
      - `docsSubcommandCallsTriggerDocuments()` — stub fires, others do not.
      - `contactsSubcommandCallsTriggerContacts()` — stub fires.
      - `micSubcommandCallsTriggerMicrophone()` — stub fires.
      - `noArgsExitsWithCode1AndPrintsUsage()` — output contains all three subcommand names.
      - `unknownSubcommandExitsWithCode1()` — output contains the bad argument string.
      - `validSubcommandExitsWithCode0()` — no `exit(1)` path reached.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [x] 6. Checkpoint — full build and dispatch tests pass
  - Run `swift build` and `swift test --filter SubcommandDispatchTests`. Ensure all tests pass. Ask the user if questions arise.

- [x] 7. Implement `scripts/reset_ward_trigger.sh`

  - [x] 7.1 Create `scripts/reset_ward_trigger.sh`. The script must: begin with `#!/usr/bin/env bash` and `set -euo pipefail`; define `BUNDLE_ID="com.gatekeepersward.ward-trigger"`; loop over the five services `SystemPolicyDocumentsFolder SystemPolicyDesktopFolder AddressBook AppleEvents Microphone`; call `tccutil reset "$SERVICE" "$BUNDLE_ID" || true` for each; print the confirmation message `"[reset_trigger] TCC permissions cleared for $BUNDLE_ID."` and `"[reset_trigger] Next invocation of WardTrigger will prompt."` to stdout; exit `0`. Mark the file executable (`chmod +x`).
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 8. Implement PBT scaffolding for `parseProcArgsBuffer` and `extractTCCEvent`

  - [x] 8.1 Create `GatekeepersWardTests/Fixtures/ProcArgsFixtures.swift` with:
    - `encodeProcArgsBuffer(argv:)` — encodes an `[String]` into a valid `KERN_PROCARGS2`-format `[UInt8]` buffer (4-byte little-endian argc, null-terminated executable path placeholder, padding to word alignment, then each arg as null-terminated UTF-8 bytes).
    - `generatePrintableASCIIArgv(count:rng:)` — returns a `[String]` of random printable-ASCII strings using the provided RNG.
    - `SeededRNG` struct conforming to `RandomNumberGenerator` using a simple Xorshift64 algorithm for reproducible CI runs.
    - _Requirements: 10.1, 10.2, 10.3_

  - [x] 8.2 Create `GatekeepersWardTests/Fixtures/TCCLogFixtures.swift` with:
    - `generateWellFormedNDJSON(subsystem:timestamp:eventMessage:)` — returns a JSON string with at least the three required fields.
    - `sonomaEventMessageFixture` and `venturaEventMessageFixture` — static string constants matching the two known TCC log wording patterns used in example tests.
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 8.3 Create `GatekeepersWardTests/Core/ParseProcArgsBufferTests.swift` with all six test cases defined in the design:
    - `kernProcArgs2RoundTrip()` — Property 1 PBT, 200/1000 iterations, tag `// Feature: ward-trigger, Property 1: KERN_PROCARGS2 round-trip`
    - `noCrashOnArbitraryBytes()` — Property 2 PBT, arbitrary `[UInt8]`, assert no trap, tag `// Feature: ward-trigger, Property 2: KERN_PROCARGS2 parser never crashes`
    - `tooShortBufferReturnsNil()` — edge case, buffer length 0–3
    - `allZeroBufferReturnsNil()` — edge case
    - `argcZeroReturnsEmptyArgv()` — example
    - `noNullTerminatorReturnsError()` — edge case
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 8.4 Create `GatekeepersWardTests/Permissions/TCCEventParserTests.swift` with all seven test cases defined in the design:
    - `ndjsonRoundTrip()` — Property 3 PBT, tag `// Feature: ward-trigger, Property 3: NDJSON parser round-trip`
    - `noCrashOnArbitraryStrings()` — Property 4 PBT, tag `// Feature: ward-trigger, Property 4: NDJSON parser never crashes`
    - `patternAExtractionFromSonoma()` — example with Sonoma fixture
    - `patternBExtractionFromVentura()` — example with Ventura fixture
    - `patternCFallbackOnUnknownMessage()` — example
    - `malformedJSONReturnsNil()` — edge case
    - `allTCCServiceCasesMapped()` — example, exhaustive `TCCService.init(rawKey:)` coverage
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 9. Checkpoint — all PBT and unit tests pass
  - Run `swift test`. Ensure all tests pass (integration-tagged tests may be skipped). Ask the user if questions arise.

- [x] 10. Wire CI hook integration

  - [x] 10.1 Create the Kiro hook `.kiro/hooks/build-test-gate.json` (v1 schema, PostTaskExec trigger) running `swift build && swift test --skip integration`. Integration-tagged tests (those requiring a live TCC prompt or real sysctl call on the current process) must be excluded from the hook run via the `--skip integration` flag. Additionally, provide a git pre-commit gate at `scripts/git-hooks/pre-commit` (installed by symlinking into `.git/hooks/pre-commit`) that runs the same two commands and blocks the commit on failure.
    - _Requirements: 6.1, 6.2, 6.3 (indirectly — ensures the pipeline is always buildable)_

- [x] 11. Final verification
  - [x] 11.1 Run `swift build` from the repository root and confirm the build completes with zero errors and zero warnings for both the `GatekeepersWard` library and the `WardTrigger` executable.
    - _Requirements: 9.4_

  - [x] 11.2 Run `bash scripts/reset_ward_trigger.sh` and confirm it prints both confirmation lines and exits `0`. If run on a fresh machine where no TCC entry exists yet, individual `tccutil` calls returning non-zero must not abort the script.
    - _Requirements: 7.3, 7.4, 7.5_

  - [x]* 11.3 Write a smoke test that invokes the built `WardTrigger` binary with no arguments and asserts it exits with code `1` and its stdout contains the strings `"docs"`, `"contacts"`, and `"mic"`.
    - _Requirements: 1.5_

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP.
- Properties 1–4 require `parseProcArgsBuffer` and `extractTCCEvent` to be implemented in `GatekeepersWard/Core/` and `GatekeepersWard/Permissions/` respectively — those implementations are covered by the Phase 2 spec (ProcessInspector + TCCWatcher). The test scaffolding in task 8 should compile against the real function signatures once they exist; stubs or empty implementations are acceptable until Phase 2 delivers the real code.
- The `DispatchSemaphore` pattern in `Triggers.swift` is intentional for a CLI with no `RunLoop`. Do not replace it with `RunLoop.main.run()` without updating the design.
- All output goes to stdout — do not redirect anything to stderr.
- Bundle ID embedding via SPM `infoPlistSettings` requires Swift 5.9+ toolchain and Xcode 15+. If the build environment uses an older toolchain, fall back to the `-sectcreate __TEXT __info_plist` linker flag approach.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3"] },
    { "id": 2, "tasks": ["2.4", "2.5", "4.1", "4.2", "4.3"] },
    { "id": 3, "tasks": ["5.1", "8.1", "8.2", "7.1"] },
    { "id": 4, "tasks": ["5.2", "8.3", "8.4"] },
    { "id": 5, "tasks": ["10.1"] },
    { "id": 6, "tasks": ["11.1", "11.2", "11.3"] }
  ]
}
```

### Implementation deviations

- Script names: the reset script is `scripts/reset_ward_trigger.sh` (not `reset_trigger.sh`), and `scripts/run_ward_trigger.sh` was added as a LaunchServices launcher (Requirement 12). Printed lines keep the `[reset_trigger]` prefix.
- The Documents probe is a read-only directory listing of `~/Documents`, because a plain stat of the canary path is not intercepted by `tccd`.
- The Kiro hook is `build-test-gate.json` using a v1 PostTaskExec trigger (Kiro has no commit trigger), and commit-time blocking is provided by the git hook script.
