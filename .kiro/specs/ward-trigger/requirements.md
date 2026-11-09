# Requirements Document

## Introduction

WardTrigger is a standalone Swift CLI executable bundled as `com.gatekeepersward.ward-trigger`. Its purpose is to deterministically trigger macOS TCC permission dialogs on demand — without disrupting the developer's daily environment — for use during `TCCWatcher` and `ProcessInspector` development iteration and during demo video recording for the Gatekeeper's Ward hackathon project.

Because macOS TCC tracks permission grants per bundle identity, WardTrigger's isolated bundle ID allows the companion reset script to clear only its permissions, leaving all other tools (IDEs, terminals, coding agents) untouched. During a triggered TCC prompt, `tccd` suspends the requesting thread; Gatekeeper's Ward reads the resulting `com.apple.TCC` unified log event and resolves the suspended PID via `sysctl(KERN_PROCARGS2)` before the user clicks any button — making WardTrigger the ground-truth stimulus for the entire detection pipeline.

## Glossary

- **WardTrigger**: The standalone Swift CLI executable with bundle ID `com.gatekeepersward.ward-trigger`.
- **TCC**: Transparency, Consent, and Control — the macOS privacy subsystem managed by `tccd`.
- **TCC Dialog**: The native macOS modal presented by `tccd` requesting user permission for a protected resource.
- **Bundle_ID**: The unique reverse-DNS identifier `com.gatekeepersward.ward-trigger` that scopes TCC decisions to WardTrigger exclusively.
- **Canary_File**: The file `~/Documents/.ward_canary` used as the read target for the Documents TCC trigger.
- **Launcher_Script**: The shell script at `scripts/run_ward_trigger.sh` that launches WardTrigger through LaunchServices.
- **Reset_Script**: The shell script at `scripts/reset_ward_trigger.sh` that calls `tccutil reset` for each protected service scoped to Bundle_ID.
- **TCCWatcher**: The Gatekeeper's Ward component that streams `com.apple.TCC` unified log events and parses them for PID extraction.
- **ProcessInspector**: The Gatekeeper's Ward component that calls `sysctl(KERN_PROCARGS2)` to extract argv, working directory, and process lineage for a given PID.
- **KERN_PROCARGS2**: The Darwin sysctl key used to read the full argument vector and environment of a running process.
- **NDJSON**: Newline-delimited JSON — the output format of `/usr/bin/log stream`.
- **Suspended_State**: The condition in which `tccd` halts the requesting thread while the TCC Dialog is displayed; the process remains in the Darwin process table and is inspectable via sysctl.
- **Service_Key**: A TCC service identifier string (e.g., `kTCCServiceSystemPolicyDocumentsFolder`) that classifies the protected resource.
- **subcommand**: A positional CLI argument that selects which TCC trigger WardTrigger executes. The valid set is `{ docs, contacts, mic }` (Requirements 3–5) plus the expansion set `{ desktop, downloads, calendar, reminders, camera, photos, events, screen }` (Requirement 13).
- **Trigger_Catalog**: The single list (`wardTriggerCatalog`) of subcommand name, Service_Key, usage summary, and trigger function from which dispatch, usage text, and tests are all derived.

## Requirements

### Requirement 1: CLI Entry Point and Subcommand Dispatch

**User Story:** As a developer, I want to invoke WardTrigger with a single subcommand argument, so that I can select which TCC service to trigger without editing code or consulting documentation.

#### Acceptance Criteria

1. THE WardTrigger SHALL accept exactly one positional subcommand argument from the names in the Trigger_Catalog (`docs`, `contacts`, `mic` and the Requirement 13 expansion set) as its first argument, ignoring case normalization (the match is case-sensitive and lowercase only).
2. WHEN WardTrigger is invoked with the subcommand `docs`, THE WardTrigger SHALL execute the Documents TCC trigger and only the Documents TCC trigger.
3. WHEN WardTrigger is invoked with the subcommand `contacts`, THE WardTrigger SHALL execute the Contacts TCC trigger and only the Contacts TCC trigger.
4. WHEN WardTrigger is invoked with the subcommand `mic`, THE WardTrigger SHALL execute the Microphone TCC trigger and only the Microphone TCC trigger.
5. WHEN WardTrigger is invoked with no arguments, THE WardTrigger SHALL print a usage summary to standard output that lists every Trigger_Catalog subcommand with a one-line description of each, and SHALL exit with code `1`.
6. WHEN WardTrigger is invoked with an unrecognized first argument, THE WardTrigger SHALL print an error message to standard output that identifies the unrecognized argument by value, followed by the same usage summary as criterion 5, and SHALL exit with code `1`.
7. THE WardTrigger SHALL exit with code `0` after a trigger function completes without a fatal system error, regardless of whether the TCC permission was granted or denied by the user.

### Requirement 2: Bundle Identity Isolation

**User Story:** As a developer, I want WardTrigger to carry a dedicated bundle ID, so that I can reset only its TCC permissions without affecting any other tool in my environment.

#### Acceptance Criteria

1. THE WardTrigger SHALL be compiled and signed with the bundle identifier `com.gatekeepersward.ward-trigger`.
2. THE WardTrigger SHALL NOT share the bundle identifier of any system tool, IDE, terminal, or coding agent present on the development machine.
3. WHEN `tccutil reset All com.gatekeepersward.ward-trigger` is executed, THE Reset_Script SHALL clear TCC decisions for WardTrigger without modifying TCC decisions for any other bundle identifier.

### Requirement 3: Documents TCC Trigger

**User Story:** As a developer, I want WardTrigger to attempt reading a canary file in `~/Documents`, so that macOS presents the `kTCCServiceSystemPolicyDocumentsFolder` TCC Dialog when Documents access has not yet been granted.

#### Acceptance Criteria

1. WHEN the `docs` subcommand is invoked and Documents access has not been granted to Bundle_ID, THE WardTrigger SHALL perform a read-only enumeration (directory listing) of `~/Documents` using `FileManager`, causing `tccd` to display the TCC Dialog. A plain stat of the Canary_File path is not intercepted by `tccd` and SHALL NOT be relied upon as the probe; Canary_File remains a never-modified marker file.
2. WHEN the `docs` subcommand is invoked and the read attempt throws a file-system error unrelated to TCC denial, THE WardTrigger SHALL print a diagnostic message identifying the error to standard output and exit with code `0`.
3. WHEN the `docs` subcommand is invoked and Documents access has already been granted, THE WardTrigger SHALL print a message indicating access was previously granted and no prompt will appear, then exit with code `0`.
4. THE WardTrigger SHALL NOT create or modify Canary_File; the trigger is read-only.

### Requirement 4: Contacts TCC Trigger

**User Story:** As a developer, I want WardTrigger to request Contacts access via the native framework API, so that macOS presents the `kTCCServiceAddressBook` TCC Dialog when Contacts access has not yet been granted.

#### Acceptance Criteria

1. WHEN the `contacts` subcommand is invoked and Contacts access has not been granted to Bundle_ID, THE WardTrigger SHALL call `CNContactStore().requestAccess(for: .contacts)`, causing `tccd` to display the TCC Dialog.
2. WHEN the `contacts` subcommand is invoked and the `CNContactStore` callback is invoked with `granted == true`, THE WardTrigger SHALL print a confirmation message and exit with code `0`.
3. WHEN the `contacts` subcommand is invoked and the `CNContactStore` callback is invoked with `granted == false`, THE WardTrigger SHALL print a denial message and exit with code `0`.
4. IF the `CNContactStore` callback is invoked with a non-nil error, THEN THE WardTrigger SHALL print the error's localized description to standard output.
5. THE WardTrigger SHALL keep the process alive until the `CNContactStore` callback completes before exiting.

### Requirement 5: Microphone TCC Trigger

**User Story:** As a developer, I want WardTrigger to request Microphone access via AVFoundation, so that macOS presents the `kTCCServiceMicrophone` TCC Dialog when Microphone access has not yet been granted.

#### Acceptance Criteria

1. WHEN the `mic` subcommand is invoked and Microphone access has not been granted to Bundle_ID, THE WardTrigger SHALL call `AVCaptureDevice.requestAccess(for: .audio)`, causing `tccd` to display the TCC Dialog.
2. WHEN the `mic` subcommand is invoked and the AVFoundation callback is invoked with `granted == true`, THE WardTrigger SHALL print a confirmation message and exit with code `0`.
3. WHEN the `mic` subcommand is invoked and the AVFoundation callback is invoked with `granted == false`, THE WardTrigger SHALL print a denial message and exit with code `0`.
4. THE WardTrigger SHALL keep the process alive until the AVFoundation callback completes before exiting.

### Requirement 6: Process Suspension and Inspectability During TCC Dialog

**User Story:** As a developer, I want the triggering process to remain alive and inspectable in the Darwin process table while the TCC Dialog is displayed, so that ProcessInspector can extract full forensic data via `sysctl(KERN_PROCARGS2)` before any button is clicked.

#### Acceptance Criteria

1. WHILE a TCC Dialog is displayed on screen, THE WardTrigger process SHALL remain present in the Darwin process table in Suspended_State.
2. WHILE a TCC Dialog is displayed on screen, THE ProcessInspector SHALL be able to call `sysctl(KERN_PROCARGS2, pid)` with WardTrigger's PID and receive the full argument vector including the subcommand used.
3. WHILE a TCC Dialog is displayed on screen, THE TCCWatcher SHALL be able to read at least one `com.apple.TCC` unified log event that includes WardTrigger's PID or bundle identifier.

### Requirement 7: Reset Helper Script

**User Story:** As a developer, I want a companion shell script to clear WardTrigger's TCC permissions with one command, so that I can reliably reproduce a first-prompt condition for repeated testing and demo video staging.

#### Acceptance Criteria

1. THE Reset_Script SHALL call `tccutil reset` for each Service_Key in `{ SystemPolicyDocumentsFolder, SystemPolicyDesktopFolder, SystemPolicyDownloadsFolder, AddressBook, Calendar, Reminders, Photos, Camera, Microphone, AppleEvents, ScreenCapture }` scoped to Bundle_ID.
2. THE Reset_Script SHALL be located at `scripts/reset_ward_trigger.sh` relative to the repository root.
3. THE Reset_Script SHALL use `set -euo pipefail` to abort on unexpected errors while tolerating individual `tccutil` failures gracefully via `|| true`.
4. WHEN the Reset_Script completes successfully, THE Reset_Script SHALL print a confirmation message indicating permissions have been cleared and the next invocation will prompt.
5. THE Reset_Script SHALL exit with code `0` when all `tccutil` calls have been attempted, regardless of whether any individual call returned a non-zero status.

### Requirement 8: Demo Staging Authenticity

**User Story:** As a developer, I want WardTrigger to accept and display additional positional arguments after the subcommand, so that demo video recordings show realistic-looking command-line invocations (e.g., file paths or search terms that a real AI agent might use).

#### Acceptance Criteria

1. THE WardTrigger SHALL accept zero or more additional positional arguments after the subcommand.
2. WHEN additional arguments are present, THE WardTrigger SHALL print those arguments to standard output before executing the trigger, formatted as a simulated command line.
3. THE WardTrigger SHALL NOT alter trigger behavior based on the content of additional arguments.
4. THE WardTrigger SHALL include the additional arguments in the argv vector visible to ProcessInspector via `sysctl(KERN_PROCARGS2)`.

### Requirement 9: No Privileged Entitlements

**User Story:** As a developer, I want WardTrigger to operate without special entitlements or SIP modifications, so that it can be built and run on any standard macOS Ventura machine without additional setup.

#### Acceptance Criteria

1. THE WardTrigger SHALL NOT require any Apple-restricted entitlements to build or run.
2. THE WardTrigger SHALL NOT require System Integrity Protection to be disabled or modified.
3. THE WardTrigger SHALL NOT require kernel extensions to be loaded.
4. THE WardTrigger SHALL be buildable on macOS 13 (Ventura) or later using the standard Swift toolchain without code signing by a paid Apple Developer account.

### Requirement 10: KERN_PROCARGS2 Buffer Parser Round-Trip Property

**User Story:** As a developer, I want the `KERN_PROCARGS2` buffer parser used by ProcessInspector to be verified with property-based tests, so that edge cases in argument encoding are caught before they produce silent failures during a live TCC prompt.

#### Acceptance Criteria

1. THE KERN_PROCARGS2_Parser SHALL parse a raw buffer into a structured representation containing the executable path and a sequence of argument strings.
2. WHEN a valid `KERN_PROCARGS2` buffer is provided, THE KERN_PROCARGS2_Parser SHALL extract the argv vector with the same argument count and string values that were used to construct the buffer.
3. FOR ALL valid argv vectors with printable ASCII argument strings, encoding then parsing SHALL produce an argv vector equal to the original (round-trip property).
4. WHEN a buffer shorter than the minimum valid header size is provided, THE KERN_PROCARGS2_Parser SHALL return a descriptive error rather than crashing or returning a partial result.
5. WHEN a buffer contains a null-byte sequence that does not terminate within the declared bounds, THE KERN_PROCARGS2_Parser SHALL return a descriptive error.

### Requirement 11: NDJSON Log Stream Parser Round-Trip Property

**User Story:** As a developer, I want the NDJSON parser used by TCCWatcher to be verified with property-based tests, so that variations in `tccd` log wording across macOS versions do not cause silent event drops.

#### Acceptance Criteria

1. THE NDJSON_Parser SHALL parse each newline-delimited line from `/usr/bin/log stream` output into a structured log event containing at minimum a subsystem field, a timestamp field, and an eventMessage field.
2. WHEN a well-formed NDJSON line is provided, THE NDJSON_Parser SHALL produce a log event whose fields match the source JSON values exactly.
3. FOR ALL well-formed NDJSON objects with string-valued fields, serializing a parsed log event back to JSON and re-parsing SHALL produce a log event equal to the original (round-trip property).
4. WHEN a malformed or incomplete NDJSON line is provided, THE NDJSON_Parser SHALL return a descriptive error and SHALL NOT crash.
5. WHEN the `eventMessage` field does not match the primary TCC detection regex, THE NDJSON_Parser SHALL apply the regex fallback pattern and return a partial event rather than discarding the line entirely.

### Requirement 12: Prompt Attribution Launcher

**User Story:** As a developer, I want WardTrigger launched through LaunchServices, so that TCC prompts are attributed to WardTrigger's bundle ID rather than the invoking terminal.

#### Acceptance Criteria

1. WHEN `scripts/run_ward_trigger.sh <subcommand> [args...]` is executed, THE Launcher_Script SHALL wrap the built binary in `.build/WardTrigger.app` whose CFBundleIdentifier is `com.gatekeepersward.ward-trigger` and launch the bundle via LaunchServices (`open`).
2. WHEN WardTrigger produces standard output under the Launcher_Script, THE Launcher_Script SHALL append a timestamped run header and the captured output (via `open --stdout`) to `$TMPDIR/ward-trigger.out`.
3. WHEN the Reset_Script runs, THE Reset_Script SHALL remove `$TMPDIR/ward-trigger.out`.

### Requirement 13: Expanded TCC Trigger Set

**User Story:** As a developer, I want WardTrigger to cover the TCC services AI coding agents most often trip (folders, personal data, automation, capture), so that TCCWatcher, the risk tagging, and the demo are exercised against realistic services and not only Documents, Contacts, and Microphone.

#### Acceptance Criteria

1. THE WardTrigger SHALL provide the subcommands `desktop`, `downloads`, `calendar`, `reminders`, `camera`, `photos`, `events`, and `screen` in addition to `docs`, `contacts`, and `mic`.
2. WHEN `desktop` or `downloads` is invoked, THE WardTrigger SHALL perform a read-only `FileManager` directory listing of `~/Desktop` or `~/Downloads` respectively, using the same outcome handling as Requirement 3 (`kTCCServiceSystemPolicyDesktopFolder`, `kTCCServiceSystemPolicyDownloadsFolder`).
3. WHEN `calendar` or `reminders` is invoked, THE WardTrigger SHALL request access through EventKit (`requestFullAccessTo…` on macOS 14+, `requestAccess(to:)` on earlier systems), keep the process alive until the callback completes, and print a grant or denial message (`kTCCServiceCalendar`, `kTCCServiceReminders`).
4. WHEN `camera` is invoked, THE WardTrigger SHALL call `AVCaptureDevice.requestAccess(for: .video)` (`kTCCServiceCamera`); WHEN `photos` is invoked, THE WardTrigger SHALL call `PHPhotoLibrary.requestAuthorization(for: .readWrite)` (`kTCCServicePhotos`); each SHALL keep the process alive until its callback completes.
5. WHEN `events` is invoked, THE WardTrigger SHALL send Finder a read-only Apple event via `NSAppleScript` (`kTCCServiceAppleEvents`) and print a grant, TCC-denial (error `-1743`), or other-error message.
6. WHEN `screen` is invoked, THE WardTrigger SHALL call `CGRequestScreenCaptureAccess()` (`kTCCServiceScreenCapture`) and poll `CGPreflightScreenCaptureAccess()` for at most 60 seconds so the process stays inspectable while the dialog is displayed; a timeout is not an error.
7. THE WardTrigger SHALL exit with code `0` after each new trigger completes, regardless of the user's choice, and SHALL NOT modify any file or user data.
8. THE WardTrigger Info.plist, and the plist written by the Launcher_Script, SHALL contain the usage-description keys each new trigger requires.
