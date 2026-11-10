# Design Document: Ward App

## Overview

The Ward App is a menu bar accessory application. A single pipeline turns `log stream` output into a HUD:

```
/usr/bin/log stream (NDJSON, subsystem com.apple.TCC)
  -> StreamReader (readabilityHandler)
  -> LineBuffer                    lines from arbitrary chunks
  -> TCCEventPipeline.process      one line -> TCCWatcherEvent?
       -> TCCRequestCorrelator     attach child PID by msgID
       -> extractTCCEvent          JSON first, regex fallback
  -> AsyncStream<TCCWatcherEvent>  newest 64
  -> AppDelegate.handle
       .prompt   -> ProcessInspector.hudContent(for:)
                      -> ProcessInspector.inspect (sysctl, proc_pidinfo)
                      -> RiskTagger.tags
                      -> HUDContent.build (status, master app, icons)
                 -> FortressHUDWindow.present
                 -> MenuBarController.recordPrompt (ghost alert)
       .resolved -> PromptTracker: show previous prompt, or HUD dismiss + ghost idle
```

Design principles from `.kiro/steering/project.md`:
- Inform, never intercept. The HUD has no buttons that answer the prompt.
- `tccd` suspends the requesting thread, so the process is in the process table while the dialog is open and `sysctl` inspection is reliable.
- The HUD never takes key focus from Apple's dialog.
- If the process already exited, show partial information with a note.
- Parse the structured NDJSON first and fall back to regex, because TCC wording changes between macOS versions.

## Package Layout

`Package.swift` (swift-tools 5.9, macOS 13):

| Target | Kind | Notes |
|---|---|---|
| `GatekeepersWard` | library | All logic and UI. Only `GatekeepersWardApp.run()` is public. |
| `GatekeepersWardApp` | executable | `main.swift` calls `GatekeepersWardApp.run()`. `Info.plist` is excluded from sources and copied by `run_ward.sh`. |
| `WardTrigger` | executable | See the `ward-trigger` spec. |
| `GatekeepersWardTests` | test | Swift Testing (`@Test`). |

`Info.plist` for the app: bundle ID `com.gatekeepersward.app`, `LSUIElement` true, minimum macOS 13.0. No usage-description keys are needed because the app only reads logs and process metadata.

## Components

### Permissions/

**LineBuffer** (struct). `append(_ chunk: Data) -> [String]` splits on `\n`, drops empty lines, keeps the partial tail between chunks (which also keeps a split UTF-8 sequence intact) and clears the tail past `maximumPendingBytes` (1 MiB).

**TCCEventParser** (`extractTCCEvent(from:)`). Decodes `TCCLogEvent` from JSON, then matches the `eventMessage` in order:

| Pattern | Wording | Fills |
|---|---|---|
| A | `service kTCCServiceX for client <path> with PID n` | service, clientPID |
| B | `kTCCServiceX, client pid: n` | service, clientPID |
| D | `service=kTCCServiceX, ... Resp:{TCCDProcess: ... pid=n` (macOS 27) | service, responsiblePID |
| C | any `kTCCService*` token | service only |
| none | valid JSON, no token | `.unknown(message)` |

Regexes use Swift `#/.../#` literals. `TCCService` has eleven named cases plus `.unknown(String)`.

**TCCRequestCorrelator** (struct). On macOS 27 the `AUTHREQ_PROMPTING` line names only the responsible app. The child that actually asks appears in an earlier `AUTHREQ_ATTRIBUTION` line with the same `msgID`:
- `ingest(_ line)` remembers `TCCAttribution(messageID, accessingPID, responsiblePID?)`. The accessing block is preferred; the requesting block is the fallback.
- A matching `AUTHREQ_PROMPTING` with an empty client PID gets `clientPID = accessingPID`, and `responsiblePID` from the prompt or else the attribution. The attribution is then deleted.
- Storage is a dictionary plus an arrival-order list, evicting the oldest at 256 entries.

**TCCEventPipeline** (struct, `process(_:now:)`). Wraps correlation and classification:
- `AUTHREQ_RESULT` with `msgID` and `authValue` -> `.resolved(TCCPromptResult)`; `isAllowed` iff `authValue == 2`.
- `AUTHREQ_PROMPTING` -> `.prompt(TCCPrompt)`.
- Non-`AUTHREQ_` line with a client PID (patterns A and B) -> `.prompt` without a `msgID`.
- Anything else -> `nil`.

**TCCWatcher** (actor). `logArguments` is static and tested. `events` is a `nonisolated AsyncStream` with `.bufferingNewest(64)`.
- `start()` launches the subprocess at userInitiated QoS, sets a `readabilityHandler` on stdout that feeds a `StreamReader` (one `LineBuffer` and one `TCCEventPipeline` per subprocess), drains stderr, and sets a `terminationHandler`.
- Unexpected exit while running, or a throwing `run()`, schedules a restart. The delay is `restartDelay(afterFailures:)`: 2 s, doubling per consecutive failure, capped at 60 s. A run of 30 s or more resets the count. Stderr is written to the application log (first 500 bytes per read).
- **Status.** `statuses` is a second `nonisolated AsyncStream<TCCWatcherStatus>` with `.bufferingNewest(1)`. `TCCWatcherStatus` is `.running` or `.failing(failures:retryIn:)`. The pure `TCCWatcher.status(afterFailures:retryIn:couldNotStart:)` decides: failing when `run()` threw, or on the second consecutive failure; a single exit (for example after sleep) restarts quietly. `scheduleRestart()` publishes the status; a successful start schedules a 5 s check and publishes `.running` if that same subprocess is still alive. Only changes are published. `TCCWatcherStatus.notice` gives the title, detail and tooltip text, so the wording is testable.
- `stop()` clears handlers, cancels the restart and the 5 s check, and terminates the process.
- `StreamReader` is `@unchecked Sendable`. It relies on `FileHandle` never running its readability handler concurrently with itself.

### Core/

**ProcessSnapshot**: `ProcessNode(pid, name, executablePath?)` and `ProcessSnapshot(pid, name, executablePath, arguments, workingDirectory?, lineage, exitedBeforeInspection, inspectionDenied)`. Placeholder paths `"<exited>"` and `"<restricted>"` appear in `executablePath` for the two degraded cases. `commandLine` shell-quotes only arguments that need it.

**ProcessInspector** (actor with `shared`). `snapshot(pid:)` calls the static, synchronous `inspect(pid:)` so tests can call it directly.
- `kernelInfo` reads `e_ppid` and `p_comm` through `sysctl(CTL_KERN, KERN_PROC, KERN_PROC_PID)`.
- `processArguments` uses a two-phase `KERN_PROCARGS2` read and `parseProcArgsBuffer` (from `ProcArgsParser.swift`, covered by property tests).
- `executablePath` uses `proc_pidpath`; `workingDirectory` uses `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
- `lineage(of:)` walks parents to a depth of 32 with a visited set (guards against PID reuse loops), stops at PID 1 and returns oldest first.
- Degradation: `pid <= 0` or no kernel info -> exited snapshot; no argv -> `inspectionDenied`.

**RiskTagger**: substring patterns for credential files and secret paths; word-level file-name matching for network and encoding tools (words split on whitespace and `|;&()`). The first match wins, so each argument gets at most one `RiskTag(argumentIndex, argument, pattern, category)`.

### HUD/

**HUDContent**. `HUDContent.build(prompt:inspect:)` takes an injectable inspector closure, which keeps the logic testable without live processes. `pid = clientPID ?? responsiblePID`. `masterApp` comes from a second inspection and only when the responsible PID differs from the inspected PID. Status resolution:

| Condition | `HUDStatus` | Text | Tone |
|---|---|---|---|
| no PID, or denied | `.veiled` | Spirit's Origins Are Veiled | amber |
| exited | `.slipped` | Spirit Slipped Through Before Inspection | amber |
| tags present | `.suspicious` | Suspicious Spirit at the Gate | crimson |
| otherwise | `.paused` | Spirit Paused at the Gate | amber |

`TCCService.vaultName` and `SpiritIcon.forProcess(named:)` hold the lore copy and the process-to-SF-Symbol table. The ghost, the Castle Keep palette and the spirit icons use SF Symbols or code-drawn art because SwiftPM cannot compile asset catalogs.

**CastlePalette**: hex values as code, with `CastleTone.color`. **FlowLayout**: a SwiftUI `Layout`; the pure `flowRows(widths:maxWidth:spacing:)` is tested separately and puts an oversized item on its own row.

**FortressHUDWindow** (`@MainActor NSPanel` subclass):

| Property | Value |
|---|---|
| `styleMask` | `[.nonactivatingPanel, .borderless, .fullSizeContentView]` |
| `level` | `.floating`, `isFloatingPanel = true` |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary]` |
| `canBecomeKey`, `canBecomeMain` | `false` |
| `hidesOnDeactivate` | `false` |
| Placement | top-right of `NSScreen.main.visibleFrame`, 16 pt margin |
| Show | `orderFrontRegardless()`, 0.2 s fade (none with Reduce Motion) |
| Dismiss | 0.25 s fade then `orderOut`; automatic after 30 s |

`.fullSizeContentView` is an addition to the steering mask, used so the SwiftUI card draws edge to edge. It does not affect key-window behaviour.

**FortressHUDView**: a 360 pt card (maximum height 480), dark colour scheme, `.ultraThinMaterial` over Obsidian Slate, Wrought Iron border. Sections: header with vault capsule, optional master app line, `ProcessLineageView`, `CommandSection` (command line, `in <cwd>`, `RiskTagView`), `StatusBadge` with the "Let Spirit Pass" and "Lower Portcullis" hint text.

### MenuBar/

**GhostIcon** draws an 18 x 18 template `NSImage` in code. Poses: `.idle` (eye height 1.0, no lantern), `.alert` (eye height 2.6, lantern raised) and `.alertBlink` (wide eyes, lantern lowered). Eyes are cut with `destinationOut` compositing.

**MenuBarController** (`@MainActor`). Holds up to 10 `RecentSpirit(name, vault, date)` entries. `recordPrompt` inserts at the front, rebuilds the menu and calls `startAlert`, which runs a 0.8 s repeating timer in `.common` run-loop mode that alternates `.alert` and `.alertBlink`. `endAlert` invalidates the timer and restores the resting pose. The resting pose is `.idle`, or `.unavailable` (sleepy faces and a crimson `!` badge) while the watcher status is failing; `setWatcherStatus(_:)` switches it, rebuilds the menu with a disabled "Not watching for prompts" notice and its detail at the top, and updates the tooltip and accessibility label. (The icon art itself is described in `.kiro/specs/castle-keep-visual-theme`, which supersedes the 18 x 18 template drawing described here.)

### App/

**PromptTracker\<Content\>** (struct, pure). Keeps open prompts in arrival order, keyed by `msgID`. Prompts without a `msgID` (older wordings) get a private id. `prompt(messageID:content:)` returns `.show(content)`. `resolve(messageID:)` returns `.show(previous)` when the shown prompt was answered and others remain, `.hide` when none remain, and `.none` for an unknown id or a prompt that is not on screen. `expire()` forgets everything. `AppDelegate` instantiates it with `HUDContent`.

**AppDelegate** (`@MainActor`) wires the watcher, HUD and menu bar, and runs the event loop in a `Task`. Each event goes through the `PromptTracker`, and `apply(_:)` turns the result into HUD and ghost calls. `FortressHUDWindow.onAutoDismiss` makes it call `expire()` and `endAlert()` when the 30 s timer fires. On quit it implements `applicationShouldTerminate`: it cancels the task, returns `.terminateLater`, awaits `watcher.stop()` in a `Task`, then calls `reply(toApplicationShouldTerminate: true)`. The main thread is never blocked.

**GatekeepersWardApp.run()** sets the `.accessory` activation policy, ignores `SIGTERM` and installs a `DispatchSource` handler that calls `NSApp.terminate`. Without this, `pkill` would orphan the `log stream` child.

### scripts/run_ward.sh

Builds `GatekeepersWardApp`, replaces any running copy, assembles `.build/GatekeepersWard.app`, signs it ad hoc and opens it. If `codesign` fails it prints an exFAT hint, because `._` files on FAT volumes break signing. `--stop` kills the running app.

## Error Handling

| Situation | Behaviour |
|---|---|
| Line is not JSON or not TCC | Parser returns `nil` or an `.unknown` event; the pipeline emits nothing |
| `log stream` exits or fails to launch | Restart with backoff (2 s doubling to 60 s), indefinitely; stderr is logged. After a failed launch or two failures in a row the menu bar icon shows the not-watching badge until a restarted subprocess has run for 5 s |
| Process exited before inspection | Exited snapshot, status "Slipped" |
| Arguments unreadable (root-owned or restricted) | `inspectionDenied`, status "Veiled", path from `proc_pidpath` when available |
| No PID known | No spirit, status "Veiled" |
| Attribution missing for a prompt | Client PID stays empty; HUD inspects the responsible app |
| `.resolved` for another `msgID` | Ignored |

## Testing Strategy

Tests use Swift Testing. Real macOS 27 captures live in `TCCLogFixtures`.

| Area | File | What it proves |
|---|---|---|
| Inspector | `ProcessInspectorTests` | own process, child process, exited, invalid PIDs, root-owned, quoting |
| Risk | `RiskTaggerTests` | README example, case-insensitive files, tools, shell one-liners, no false positives |
| HUD content | `HUDContentTests` | child under agent, self-responsible, status, PID fallback, icons, vault names |
| Layout | `FlowLayoutTests` | wrapping, exact fit, oversize item, real six-process Zed chain |
| Parser | `TCCEventParserTests` | pattern D and attribution wording; earlier PBT on main |
| Correlator | `TCCRequestCorrelatorTests` | msgID matching, single use, eviction, direct requests, old wording |
| Pipeline | `TCCWatcherPipelineTests` | chunking (including random chunking), header ignored, prompt then result, denied result, `logArguments` |
| Restart | `TCCWatcherRestartTests` | backoff doubles from 2 s, caps at 60 s, non-positive counts give the base delay |
| Prompt tracking | `PromptTrackerTests` | stacking, restoring the previous prompt, unknown and late results, repeated `msgID`, legacy prompts, expiry |

Property-based coverage of the `KERN_PROCARGS2` parser and the NDJSON parser predates this spec and lives in `ParseProcArgsBufferTests` and `TCCEventParserTests`.

Not covered by automated tests (manual verification with WardTrigger, see `tasks.md`): panel focus behaviour, auto-dismiss, ghost animation, multi-screen placement.

## Known Limitations and Risks

These came out of the review. Items 1, 2, 5 (partly), 6 and 9 are fixed; the rest are tracked as open tasks.

1. ~~**Ghost alert not cleared on HUD auto-dismiss.**~~ Fixed: `onAutoDismiss` ends the alert.
2. ~~**Single `shownMessageID`.**~~ Fixed by `PromptTracker`.
3. **Legacy-wording prompts have no `msgID`**, so only the 30 s timer dismisses them. They are now tracked separately and no longer block other prompts, but they still end only by timeout.
4. **Out-of-order lines.** If `AUTHREQ_PROMPTING` arrives before its attribution, the HUD inspects the responsible app (the parent) instead of the child. Not seen in any captured log; left unimplemented until a real capture shows it.
5. ~~**Restart loop** had no visible error in the UI when `/usr/bin/log` cannot launch.~~ Fixed: the not-watching state (task 8.5b).
6. ~~**Termination wait.**~~ Fixed with `.terminateLater`.
7. **Placement** uses `NSScreen.main`, which may not be the screen showing Apple's dialog.
8. **Menu times** ("2 min ago") refresh only when the menu is rebuilt.
9. ~~**Test environment.**~~ Fixed: `Package.swift` passes the Command Line Tools plugin path only if the file exists, and the root-owned process test is skipped when the tests run as root.
10. **Palette.** Spectral Ectoplasm secondary `#C7D2FE` is unused and the header uses an emoji.
