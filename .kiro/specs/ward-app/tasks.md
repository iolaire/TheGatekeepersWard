# Implementation Plan: Ward App

## Overview

Retroactive plan for the Ward App built on the `dev` branch by Dharshaneshwaran. Completed tasks reflect delivered and reviewed code (70 tests passing at `2e1b562`). Open tasks cover manual verification and follow-ups from review.

## Tasks

- [x] 1. Package and app scaffold
  - [x] 1.1 Add the `GatekeepersWardApp` executable target and `GatekeepersWardApp/Info.plist` (`LSUIElement`, bundle ID `com.gatekeepersward.app`).
    - _Requirements: 10.1, 11.6_
  - [x] 1.2 Add `scripts/run_ward.sh` (build, wrap, ad hoc sign, launch, `--stop`).
    - _Requirements: 11.6_

- [x] 2. Event stream and parsing
  - [x] 2.1 Implement `LineBuffer`.
    - _Requirements: 1.2, 1.3_
  - [x] 2.2 Extend `TCCEventParser` with pattern D (macOS 27) and the `TCCService` vault cases.
    - _Requirements: 2.1 to 2.7_
  - [x] 2.3 Implement `TCCRequestCorrelator` (`msgID` attribution, requesting-PID fallback).
    - _Requirements: 3.1 to 3.8_
  - [x] 2.4 Implement `TCCEventPipeline` and `TCCWatcher` (subprocess, restart, `AsyncStream`).
    - _Requirements: 1.1, 1.4 to 1.7, 4.1 to 4.5_
  - [x]* 2.5 Tests: `TCCEventParserTests`, `TCCRequestCorrelatorTests`, `TCCWatcherPipelineTests`, with real macOS 27 fixtures in `TCCLogFixtures`.
    - _Requirements: 13.1, 13.3_

- [x] 3. Process inspection and risk tagging
  - [x] 3.1 Implement `ProcessSnapshot` and `ProcessInspector` with graceful degradation.
    - _Requirements: 5.1 to 5.7_
  - [x] 3.2 Implement `RiskTagger`.
    - _Requirements: 6.1 to 6.6_
  - [x]* 3.3 Tests: `ProcessInspectorTests`, `RiskTaggerTests`.
    - _Requirements: 13.1_

- [x] 4. HUD
  - [x] 4.1 Implement `HUDContent`, `SpiritIcon` and vault names.
    - _Requirements: 7.1 to 7.9_
  - [x] 4.2 Implement `CastlePalette`, `FlowLayout`, `FortressHUDView`.
    - _Requirements: 9.1 to 9.7_
  - [x] 4.3 Implement `FortressHUDWindow` (non-activating floating panel, auto-dismiss, Reduce Motion).
    - _Requirements: 8.1 to 8.7_
  - [x]* 4.4 Tests: `HUDContentTests`, `FlowLayoutTests`.
    - _Requirements: 13.1_

- [x] 5. Menu bar and lifecycle
  - [x] 5.1 Implement `GhostIcon` and `MenuBarController` (history, alert animation).
    - _Requirements: 10.1 to 10.6_
  - [x] 5.2 Implement `AppDelegate` and `GatekeepersWardApp.run()` (event loop, `msgID` dismissal, SIGTERM handling).
    - _Requirements: 11.1 to 11.5_

- [x] 6. Checkpoint: `swift build` succeeds and `swift test` passes (70 tests) on `origin/dev`.

- [x] 7. Manual verification with WardTrigger (Requirement 13.4)
  - [x] 7.1 Run `scripts/run_ward.sh`, then `scripts/reset_ward_trigger.sh`, then `scripts/run_ward_trigger.sh docs rg "AWS_SECRET" ~/Documents/prod.env`. Confirm the ghost alerts, the HUD appears beside Apple's dialog and the `AWS_SECRET` and `.env` arguments are crimson.
    - _Requirements: 7.7, 8.1 to 8.4, 9.4, 10.3_
  - [x] 7.2 Confirm Apple's Allow and Don't Allow buttons stay clickable with the HUD open (no focus steal).
    - _Requirements: 8.2, 12.2_
  - [x] 7.3 Answer the dialog and confirm the HUD dismisses and the ghost returns to idle.
    - _Requirements: 11.2, 10.4_
  - [x] 7.4 Repeat with `contacts` and `mic` and confirm the vault names.
    - _Requirements: 7.8_
  - [x] 7.5 Run `scripts/run_ward.sh --stop` and confirm no `log stream` process remains (`pgrep -fl "log stream"`).
    - _Requirements: 11.4, 11.5_
  - [x] 7.6 Record the macOS version used and the outcome in `docs/devlog.md`. Recorded in the Day 4 and Day 5 entries (macOS 27.0.1, verified live with WardTrigger).

- [ ] 8. Follow-ups from review
  - [x] 8.1 Call `endAlert()` when the HUD auto-dismisses, so the ghost cannot blink indefinitely. `FortressHUDWindow.onAutoDismiss` plus `PromptTracker.expire()`.
    - _Requirements: 10.4, 11.6_
  - [x] 8.2 Track pending prompts by `msgID` (or restore the previous prompt) so concurrent prompts dismiss correctly. `PromptTracker` with `PromptTrackerTests`.
    - _Requirements: 11.2 to 11.5_
  - [ ] 8.3 Give legacy-wording prompts (no `msgID`) a dismissal path other than the timer. Partly addressed: they are tracked separately and no longer interfere with other prompts, but only the timeout ends them. Needs a capture of the Ventura or Sonoma result wording, or a manual dismiss.
    - _Requirements: 4.2, 11.6_
  - [ ] 8.4 Handle `AUTHREQ_PROMPTING` arriving before its attribution. Deferred: no captured macOS 27 sequence shows this order. Revisit if a real capture does.
    - _Requirements: 3.3, 3.8_
  - [x] 8.5 Add backoff to the watcher restart loop and log `log stream` stderr. `TCCWatcher.restartDelay(afterFailures:)` with `TCCWatcherRestartTests`.
    - _Requirements: 1.6, 1.7_
  - [ ] 8.5b Show a visible state in the UI (for example the ghost tooltip) when `log stream` cannot start.
    - _Requirements: 1.6_
  - [x] 8.6 Replace the semaphore wait in `applicationWillTerminate` with a non-blocking shutdown (`applicationShouldTerminate` returning `.terminateLater`).
    - _Requirements: 11.7_
  - [ ] 8.7 Position the HUD on the screen that holds Apple's dialog instead of `NSScreen.main`. Needs a check on a multi-display Mac to see which screen Apple's dialog uses.
    - _Requirements: 8.4_
  - [x] 8.8 Make the Command Line Tools plugin path in `Package.swift` conditional on the file existing, and skip the root-owned process test when running as root.
    - _Requirements: 13.1_
  - [ ] 8.9 Decide on the Spectral Ectoplasm secondary tone (`#C7D2FE`) and the emoji header, then update `CastlePalette` or the steering file. Needs a design decision.
    - _Requirements: 9.1_
  - [ ] 8.10 Run the new behaviour on a real Mac: open two prompts at once (for example `docs` and `mic`) and answer them in both orders; let one time out; quit with `scripts/run_ward.sh --stop` and confirm no `log stream` is left.
    - _Requirements: 11.2 to 11.7_

- [x] 9. Documentation
  - [x] 9.1 Add the Phase 2 and 3 entry to `docs/devlog.md` and update the test count in the README. `docs/HACKATHON_REVIEW.md` is a dated snapshot of a review run, so it is refreshed by re-running the review, not edited by hand.
  - [x] 9.2 Update `docs/architecture.md` where the as-built layout differs from the plan: lineage is inside `ProcessInspector`, `ProcessLineageView` and `RiskTagView` live in `FortressHUDView.swift`, and the data flow, menu bar and Resources sections match the code.
