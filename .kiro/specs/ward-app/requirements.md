# Requirements Document

## Introduction

The Ward App is the menu bar application at the core of Gatekeeper's Ward. While an AI coding agent's child process is suspended by `tccd` behind a macOS TCC permission dialog, the Ward App detects the prompt from the Unified Log, inspects the suspended process through Darwin APIs, and shows a non-activating Fortress HUD beside Apple's dialog. The HUD shows PID, binary, command line, working directory, process lineage and risk-tagged arguments.

This spec was written retroactively for work delivered on the `dev` branch (Phase 2 and Phase 3 of the roadmap: `TCCWatcher`, `ProcessInspector`, Fortress HUD, menu bar ghost). It documents the behaviour as built and records the gaps found in review as open tasks.

The Ward App informs and never intercepts. Apple's TCC dialog keeps full control of Allow and Don't Allow.

## Glossary

- **Ward_App**: The `GatekeepersWardApp` executable (bundle ID `com.gatekeepersward.app`), an accessory menu bar app with no Dock icon.
- **TCC**: Transparency, Consent, and Control, the macOS privacy subsystem managed by `tccd`.
- **TCCWatcher**: The actor that runs `/usr/bin/log stream` and emits `TCCWatcherEvent` values (`.prompt` or `.resolved`).
- **TCCEventParser**: The component that decodes one NDJSON line into a `TCCEvent` using structured decoding first and regex patterns on `eventMessage` as fallback.
- **TCCRequestCorrelator**: The component that links an `AUTHREQ_ATTRIBUTION` line to the later `AUTHREQ_PROMPTING` line with the same `msgID`, so the prompt can carry the child process PID.
- **LineBuffer**: The component that reassembles complete lines from arbitrary stdout chunks.
- **ProcessInspector**: The actor that reads a PID's executable path, argv, working directory and parent chain via `sysctl` and `proc_pidinfo`.
- **ProcessSnapshot**: The value produced by ProcessInspector, including the `exitedBeforeInspection` and `inspectionDenied` flags.
- **Lineage**: The ancestor chain of a process, ordered from the oldest ancestor to the process itself, excluding `launchd`.
- **Spirit**: The inspected child process that is paused at the gate.
- **Master_App**: The responsible application (for example Cursor or Zed) that launched the Spirit.
- **RiskTagger**: The component that flags suspicious command-line arguments.
- **HUDContent**: The view-model that combines a prompt, a ProcessSnapshot, risk tags and a status.
- **Fortress_HUD**: The `NSPanel` window (`FortressHUDWindow`) and SwiftUI view (`FortressHUDView`) that present HUDContent.
- **Ghost**: The menu bar status item icon, with Idle and Alert poses.
- **Castle_Keep_Palette**: The colour tokens defined in `.kiro/steering/project.md`.
- **msgID**: The `msgID=<n>.<n>` token that ties together the log lines of one TCC authorization request.

## Requirements

### Requirement 1: TCC Event Stream

**User Story:** As a developer running AI coding agents, I want the Ward App to notice TCC prompts as they happen, so that I see forensics while the dialog is open.

#### Acceptance Criteria

1. THE TCCWatcher SHALL run `/usr/bin/log stream --style ndjson --level info --predicate 'subsystem == "com.apple.TCC"'` as a subprocess and SHALL read its standard output.
2. THE LineBuffer SHALL rebuild complete lines from stdout chunks of any size, including several lines in one chunk, one line split across chunks, and a UTF-8 character split across chunks.
3. WHEN the pending partial line exceeds 1 MiB, THE LineBuffer SHALL discard it.
4. THE TCCWatcher SHALL ignore the non-JSON header line that `log stream` prints at startup.
5. THE TCCWatcher SHALL publish events through an `AsyncStream` that keeps only the newest 64 events.
6. IF the `log stream` subprocess exits or fails to start while the watcher is running, THEN THE TCCWatcher SHALL start it again after 2 seconds, doubling the delay on each consecutive failure up to 60 seconds, and SHALL reset the delay after the subprocess ran for 30 seconds.
7. THE TCCWatcher SHALL write the subprocess's standard error output to the application log.
8. WHEN `stop()` is called, THE TCCWatcher SHALL stop the subprocess and cancel any pending restart.
9. WHEN the `log stream` subprocess could not be started, or has failed twice in a row, THE TCCWatcher SHALL publish a failing status through a second `AsyncStream` (newest value only), carrying the failure count and the seconds until the next try. WHEN a restarted subprocess has then run for 5 seconds, THE TCCWatcher SHALL publish the running status.
10. WHILE the watcher status is failing, THE Ward_App SHALL show a not-watching state: a crimson badge on the menu bar icon, a tooltip and accessibility label that say the Ward is not watching and when it will try again, and a disabled notice at the top of the menu. A prompt alert SHALL take precedence over the badge while it lasts. WHEN the status returns to running, THE Ward_App SHALL remove the badge, the notice and the extra text.

### Requirement 2: Event Parsing Across macOS Versions

**User Story:** As a developer, I want parsing to survive changes in TCC log wording, so that the Ward App keeps working across macOS releases.

#### Acceptance Criteria

1. THE TCCEventParser SHALL decode the NDJSON structure first and SHALL fall back to regex patterns on `eventMessage`.
2. THE TCCEventParser SHALL extract the service key and client PID from the wording `service kTCCServiceX for client <path> with PID n`.
3. THE TCCEventParser SHALL extract the service key and client PID from the wording `kTCCServiceX, client pid: n`.
4. THE TCCEventParser SHALL extract the service key and the responsible PID from the macOS 27 `AUTHREQ_PROMPTING` wording and SHALL leave the client PID empty.
5. WHEN a line contains a `kTCCService*` token and no PID pattern matches, THE TCCEventParser SHALL still return an event with the service and no PIDs.
6. WHEN a line is valid JSON with no TCC service token, THE TCCEventParser SHALL return an event with an `.unknown` service and SHALL NOT trap.
7. THE TCCEventParser SHALL return `nil` for input that cannot be decoded and SHALL NOT trap on arbitrary bytes.

### Requirement 3: Request Correlation (macOS 27)

**User Story:** As a developer, I want the prompt to name the child process that is actually asking, so that I see the spirit and not just its parent app.

#### Acceptance Criteria

1. WHEN an `AUTHREQ_ATTRIBUTION` line with a `msgID` is seen, THE TCCRequestCorrelator SHALL remember its accessing PID and responsible PID under that `msgID`.
2. WHEN the accessing block is absent, THE TCCRequestCorrelator SHALL use the requesting block PID as the client.
3. WHEN an `AUTHREQ_PROMPTING` line has no client PID and a remembered attribution has the same `msgID`, THE TCCRequestCorrelator SHALL set the client PID to the accessing PID and SHALL set the responsible PID from the prompt, or from the attribution when the prompt has none.
4. THE TCCRequestCorrelator SHALL use each remembered attribution at most once.
5. THE TCCRequestCorrelator SHALL NOT apply an attribution to a prompt with a different `msgID`.
6. THE TCCRequestCorrelator SHALL NOT consume an attribution on `AUTHREQ_SUBJECT` or `AUTHREQ_RESULT` lines.
7. WHEN more than 256 attributions are remembered, THE TCCRequestCorrelator SHALL evict the oldest first.
8. IF no attribution was seen for a prompt, THEN THE prompt SHALL keep an empty client PID.

### Requirement 4: Prompt and Resolution Events

**User Story:** As a developer, I want the HUD to appear when a prompt opens and go away when I answer, so that it never lingers on stale information.

#### Acceptance Criteria

1. WHEN an `AUTHREQ_PROMPTING` line is processed, THE TCCEventPipeline SHALL emit a `.prompt` event with the service, client PID, responsible PID, `msgID` and detection time.
2. WHEN a line that does not start with `AUTHREQ_` yields a client PID (older wording), THE TCCEventPipeline SHALL emit a `.prompt` event.
3. WHEN an `AUTHREQ_RESULT` line has a `msgID` and an `authValue`, THE TCCEventPipeline SHALL emit a `.resolved` event whose `isAllowed` is true only if `authValue` is `2`.
4. IF an `AUTHREQ_RESULT` line lacks the `msgID` or the `authValue`, THEN THE TCCEventPipeline SHALL emit nothing.
5. THE TCCEventPipeline SHALL emit nothing for every other line.

### Requirement 5: Process Inspection

**User Story:** As a developer, I want complete forensics on the suspended process, so that I can decide whether to trust it.

#### Acceptance Criteria

1. THE ProcessInspector SHALL obtain argv through `sysctl(KERN_PROCARGS2)` and SHALL parse it with `parseProcArgsBuffer`.
2. THE ProcessInspector SHALL obtain the executable path with `proc_pidpath` and the working directory with `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
3. THE ProcessInspector SHALL build the Lineage by following parent PIDs, stopping at PID 1, at a maximum depth of 32, or on a repeated PID, and SHALL omit `launchd`.
4. IF the PID is not positive or the process is gone, THEN THE ProcessInspector SHALL return a snapshot with `exitedBeforeInspection` set and SHALL NOT throw.
5. IF the process exists but its arguments cannot be read, THEN THE ProcessInspector SHALL return a snapshot with `inspectionDenied` set and the executable path when available.
6. THE ProcessInspector SHALL be read-only and SHALL NOT use `task_for_pid`, kernel extensions or restricted entitlements.
7. THE ProcessSnapshot command line SHALL quote only arguments that are empty or contain whitespace, quotes, backslash, `$` or a backtick.

### Requirement 6: Risk Tagging

**User Story:** As a developer, I want suspicious arguments highlighted, so that exfiltration patterns stand out at a glance.

#### Acceptance Criteria

1. THE RiskTagger SHALL flag an argument that contains, case-insensitively, a credential-file pattern (`.pem`, `.env`, `id_rsa`, `id_ed25519`, `.p12`, `.pfx`, `credentials`).
2. THE RiskTagger SHALL flag an argument that contains, case-insensitively, a secret-path pattern (`.aws`, `.ssh`, `keychain`, `secret`, `password`, `token`, `api_key`).
3. THE RiskTagger SHALL flag an argument in which a word (split on whitespace and `|;&()`) has a file name equal to `curl`, `wget`, `nc`, `ncat`, `netcat`, `base64` or `xxd`.
4. THE RiskTagger SHALL NOT flag tool names that appear only inside ordinary words.
5. THE RiskTagger SHALL produce at most one tag per argument.
6. THE RiskTagger SHALL return no tags for an ordinary search command.

### Requirement 7: HUD Content and Status

**User Story:** As a developer, I want the HUD to tell me honestly what it knows, including when it knows little.

#### Acceptance Criteria

1. THE HUDContent builder SHALL inspect the client PID, and SHALL fall back to the responsible PID when the client PID is empty.
2. IF neither PID is known, THEN THE HUDContent SHALL have no Spirit and the status "Spirit's Origins Are Veiled".
3. THE HUDContent SHALL set the Master_App only when the responsible PID differs from the inspected PID.
4. WHEN the snapshot is `exitedBeforeInspection`, THE HUDContent status SHALL be "Spirit Slipped Through Before Inspection".
5. WHEN the snapshot is `inspectionDenied`, THE HUDContent status SHALL be "Spirit's Origins Are Veiled".
6. WHEN inspection succeeded and there are no risk tags, THE HUDContent status SHALL be "Spirit Paused at the Gate" in Torchlight Amber.
7. WHEN inspection succeeded and there are risk tags, THE HUDContent status SHALL be "Suspicious Spirit at the Gate" in Mischief Crimson.
8. THE HUDContent SHALL name each TCC service with its vault copy (for example "Documents Vault", "Voice Chamber") and "Unknown Vault" for unknown services.
9. THE HUDContent SHALL map process names to spirit icons: magnifier for `rg`, `grep`, `find`, `fd`; key for shells; braces for interpreters; antenna for `curl`, `wget`, `nc`, `ncat`; branch for `git`; open lock for `ssh`, `scp`, `sftp`; sparkles for names beginning with `cursor`, `claude`, `kiro` or `copilot`; a dashed app for everything else.

### Requirement 8: Fortress HUD Window

**User Story:** As a developer, I want the HUD beside Apple's dialog without ever blocking it.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL be an `NSPanel` with style mask `.nonactivatingPanel`, `.borderless` and `.fullSizeContentView`, at `.floating` level.
2. THE Fortress_HUD SHALL return false from `canBecomeKey` and `canBecomeMain` and SHALL be shown with `orderFrontRegardless()`, never `makeKeyAndOrderFront`.
3. THE Fortress_HUD SHALL stay visible when the Ward App is not active and SHALL appear on all Spaces and over full-screen apps.
4. THE Fortress_HUD SHALL appear at the top-right of the main screen's visible frame with a 16 pt margin.
5. THE Fortress_HUD SHALL dismiss itself 30 seconds after it was presented.
6. WHEN a new prompt is presented while the HUD is visible, THE Fortress_HUD SHALL replace its content and restart the 30 second timer.
7. WHEN Reduce Motion is enabled, THE Fortress_HUD SHALL show and hide without fade animation.

### Requirement 9: Fortress HUD Content and Style

**User Story:** As a developer, I want the HUD to be readable at a glance and on-brand.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL use only Castle_Keep_Palette colours on an Obsidian Slate frosted background with a Wrought Iron border.
2. THE Fortress_HUD SHALL show a header, the vault name, the Master_App when present, the Lineage as wrapping chips with the Spirit highlighted, the executed command line, the working directory, the risk tags and the status badge.
3. THE Fortress_HUD SHALL show the executable path when the command line is empty.
4. THE Fortress_HUD SHALL show each risk tag as a Mischief Crimson capsule with the offending argument.
5. THE Fortress_HUD SHALL state in text that Apple's dialog decides, using the copy "Let Spirit Pass" for Allow and "Lower Portcullis" for Don't Allow, and SHALL NOT provide buttons that answer the prompt.
6. THE Fortress_HUD SHALL provide accessibility labels for the header, lineage and risk tags.
7. WHEN the lineage is wider than the card, THE Fortress_HUD SHALL wrap it onto further rows and SHALL NOT drop any process.

### Requirement 10: Menu Bar Ghost

**User Story:** As a developer, I want a quiet presence in the menu bar that reacts when a spirit appears.

#### Acceptance Criteria

1. THE Ward_App SHALL run as an accessory app with an `NSStatusItem` and no Dock icon.
2. WHILE idle, THE Ghost SHALL show the Idle pose, with half-closed eyes and no lantern.
3. WHEN a prompt is recorded, THE Ghost SHALL switch to the Alert pose, with wide eyes and a raised lantern, and SHALL alternate with a lowered-lantern pose every 0.8 seconds.
4. WHEN the matching prompt is resolved, THE Ghost SHALL return to Idle.
5. THE Ghost SHALL be a template image drawn in code.
6. THE menu SHALL list up to 10 recent spirits as `name → vault (relative time)`, or "No Spirits Detected" when empty, and SHALL offer Clear History, About and Quit (⌘Q).

### Requirement 11: Application Lifecycle

**User Story:** As a developer, I want to start and stop the Ward cleanly.

#### Acceptance Criteria

1. WHEN a `.prompt` event arrives, THE Ward_App SHALL present the HUD and record the spirit in the menu bar history.
2. THE Ward_App SHALL track every open prompt by `msgID` and SHALL show the newest one in the HUD.
3. WHEN a `.resolved` event arrives for the prompt shown, THE Ward_App SHALL show the previous open prompt, or, if none is open, dismiss the HUD and end the Ghost alert.
4. WHEN a `.resolved` event arrives for an open prompt that is not shown, THE Ward_App SHALL forget that prompt and leave the HUD unchanged.
5. WHEN a `.resolved` event arrives with an unknown `msgID`, including one that arrives after the HUD timed out, THE Ward_App SHALL ignore it.
6. WHEN the HUD hides itself after its 30 second timeout, THE Ward_App SHALL forget all open prompts and end the Ghost alert.
7. WHEN the app terminates, THE Ward_App SHALL stop the `log stream` subprocess so none is left behind, and SHALL do so without blocking the main thread.
8. WHEN the app receives SIGTERM, THE Ward_App SHALL terminate through `NSApp.terminate` so the subprocess is stopped.
9. THE `scripts/run_ward.sh` script SHALL build the app, wrap it in `.build/GatekeepersWard.app`, sign it ad hoc and launch it, and SHALL support `--stop`.

### Requirement 12: Security Boundaries and Standards

**User Story:** As a maintainer, I want the app to stay inside macOS's security model and our coding standards.

#### Acceptance Criteria

1. THE Ward_App SHALL NOT bypass SIP, load kernel extensions or require restricted entitlements.
2. THE Ward_App SHALL NOT control or answer Apple's TCC dialog.
3. EACH production source file SHALL stay at or under about 300 lines.
4. THE production code SHALL NOT use force-unwrap (`!`).
5. EACH public or internal type and function SHALL carry a `///` doc comment.

### Requirement 13: Test Coverage

**User Story:** As a judge or maintainer, I want evidence that the parsers and logic are tested.

#### Acceptance Criteria

1. THE project SHALL include unit tests for ProcessInspector, RiskTagger, HUDContent, FlowLayout, TCCRequestCorrelator, the TCCEventPipeline and the new parser patterns.
2. THE project SHALL include property-based tests for the `KERN_PROCARGS2` buffer parser and the NDJSON parser, and a property-style test that random chunking of a stream yields the same lines as one chunk.
3. THE tests SHALL use captured real macOS 27 log sequences as fixtures.
4. THE `FortressHUDWindow` configuration, auto-dismiss and Ghost animation SHALL be verified manually with WardTrigger, as recorded in `tasks.md`.
