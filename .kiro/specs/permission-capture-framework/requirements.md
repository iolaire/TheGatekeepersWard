# Requirements Document

## Introduction

The Permission Capture Framework is a set of developer scripts under `scripts/capture/` that automates recording macOS TCC permission prompts triggered by AI coding agent apps, as screenshots and video, in two modes: **baseline** (Gatekeeper's Ward not running, showing Apple's bare prompt) and **ward** (Gatekeeper's Ward running, showing the Fortress HUD with process forensics beside the prompt). The output feeds the README, the Devpost page, the pitch, and the three-minute submission demo video, and shows the need for the tool and its benefit side by side.

The framework drives target apps through macOS Accessibility (System Events UI scripting) and `osascript`, resets TCC decisions only for the target apps through `tccutil`, and records with `screencapture`. Each target app (initially ZCode and the DeepSeek harness) is described by a per-app profile file, so a new app is added by writing one profile and no framework code changes. The framework also sets up and tears down the capture-tool permissions (Accessibility, Screen Recording, Automation) and restores the machine to its prior state.

Because a scoped reset deletes the user's real grants for the target app, the framework also saves the affected rows of the user-level TCC database before the first reset of a run and restores them when the run ends, so the developer does not lose grants. This is the one place the framework touches the TCC database, and it does so only through one dedicated file, `scripts/capture/lib/tccdb.sh` (Requirements 15 to 17).

The framework adds no runtime code to the Gatekeeper's Ward app. It respects the project's macOS security boundaries: no SIP bypass, no access to the system-level TCC database, no TCC database access outside `lib/tccdb.sh`, and no resets or row changes for bundle IDs outside the selected profiles. The project steering file `macos-security-boundaries` currently forbids TCC database access and needs a matching, narrowly worded exception for `lib/tccdb.sh` before implementation.

## Glossary

- **Capture_Framework**: The scripts and profiles under `scripts/capture/` that together implement this feature.
- **Capture_CLI**: The entry script `scripts/capture/capture.sh`, which exposes the subcommands `setup`, `teardown`, `reset`, `restore`, `prompt`, `run`, `list`, `doctor`, and `export`.
- **App_Profile**: A per-app configuration file at `scripts/capture/profiles/<profile_id>.profile` that declares the bundle ID, launch method, the UI-automation steps that deliver a prompt to the app, and the supported scenarios.
- **Profile_ID**: The lowercase kebab-case name of an App_Profile (for example `zcode`, `deepseek-harness`).
- **Scenario**: A named permission trigger, such as `desktop`, `documents`, `downloads`, or `removable-volume`, that an App_Profile maps to a prompt text and the TCC service key it is expected to raise.
- **Capture_Mode**: Either `baseline` (Ward not running) or `ward` (Ward running).
- **Ward_App**: The Gatekeeper's Ward menu bar app, launched by `scripts/run_ward.sh`.
- **Capture_Session**: One execution of a Scenario for one App_Profile in one Capture_Mode.
- **Session_Directory**: The directory `captures/<timestamp>/<profile_id>/<scenario>/<capture_mode>/` that holds all artifacts of a Capture_Session.
- **Manifest**: The file `manifest.json` in a Session_Directory that records the metadata of a Capture_Session.
- **Capture_Host**: The terminal or app that runs the Capture_CLI and therefore receives the Accessibility, Screen Recording, and Automation grants.
- **Setup_State_File**: The file `captures/.state/setup.json` that records which capture-tool permissions the Capture_CLI requested and which were already present before `setup`.
- **TCC**: Transparency, Consent, and Control, the macOS privacy subsystem managed by `tccd`.
- **TCC_Prompt**: The system dialog that `tccd` displays to request user permission for a protected resource.
- **Prompt_Message**: The text the Capture_CLI types into a target app to ask the app's agent to perform an action that triggers a TCC_Prompt.
- **Marker_File**: The file `captures/.state/ward.pid` that records the process ID of a Ward_App started by the Capture_CLI.
- **User_TCC_DB**: The user-level TCC database file at `~/Library/Application Support/com.apple.TCC/TCC.db`. The system-level database at `/Library/Application Support/com.apple.TCC/TCC.db` is out of scope.
- **TCC_Access_Module**: The single file `scripts/capture/lib/tccdb.sh`, the only file in the Capture_Framework that may reference or open a TCC database file.
- **Full_Disk_Access**: The macOS privacy permission that lets the Capture_Host read the User_TCC_DB.
- **Snapshot_Scope**: The set of rows in the `access` table of the User_TCC_DB whose `client` equals the App_Profile's bundle ID and whose `service` is one of the App_Profile's declared services. Rows for the client `All` or for any other bundle ID are never in scope.
- **TCC_Snapshot**: The file `captures/.state/tcc-snapshot-<bundle_id>.json` holding every column of every row in the Snapshot_Scope exactly as stored, with binary columns (including `csreq`) encoded losslessly as hexadecimal text, plus a record of which Snapshot_Scope services had no row.
- **TCC_Backup**: A byte-for-byte copy of the whole User_TCC_DB, saved as `captures/.state/TCC.db.backup-<timestamp>` before the first write of a run.
- **Restore**: The operation that returns the Snapshot_Scope rows of the User_TCC_DB to their TCC_Snapshot state and then restarts the user's `tccd`.

## Requirements

### Requirement 1: Capture-Tool Setup

**User Story:** As a developer, I want a single command that prepares the machine for UI-automated capture, so that I can record without hunting through System Settings.

#### Acceptance Criteria

1. WHEN `capture.sh setup` is run, THE Capture_CLI SHALL check whether the Capture_Host holds each of the five permissions (Accessibility, Screen Recording, Automation for System Events, Automation for Finder, and Full_Disk_Access) and print exactly one status line per permission, five lines in total, each line naming the permission and stating either "granted" or "missing".
2. WHEN a required permission is found missing during `setup`, THE Capture_CLI SHALL trigger the system request for that permission and open the matching System Settings pane through the `x-apple.systempreferences:` URL scheme within 5 seconds of detecting the missing permission.
3. WHEN `setup` finishes, THE Capture_CLI SHALL write the Setup_State_File recording, for each of the five permissions, whether it was already granted before `setup` ran, and SHALL leave any existing Setup_State_File entries unchanged if `setup` is run again and a permission was already recorded.
4. WHEN `setup` finds all five permissions granted, THE Capture_CLI SHALL exit with code 0.
5. IF a required permission remains missing after the user confirms the setup prompts, THEN THE Capture_CLI SHALL exit with a non-zero code, print the name of each missing permission and the System Settings pane that grants it, and still write the Setup_State_File for all five permissions.
6. WHEN `capture.sh doctor` is run, THE Capture_CLI SHALL print one status line for each of the five setup permissions, one line for each of `osascript`, `screencapture`, and `tccutil` stating "found" or "not found", one line for `ffmpeg` stating "found" or "not found" only when `ffmpeg` is the selected video backend, and one line stating the macOS version, without changing any system state, without triggering any permission request, and without writing the Setup_State_File.
7. IF a required external tool (`osascript`, `screencapture`, `tccutil`, or `ffmpeg` when selected as the video backend) is not found during `doctor`, THEN THE Capture_CLI SHALL exit with a non-zero code after printing all status lines.
8. THE Capture_CLI SHALL perform `setup` without writing to any TCC database file and without disabling System Integrity Protection.
9. WHERE the `--no-restore` option is not given, WHEN `capture.sh setup` or `capture.sh doctor` is run, THE Capture_CLI SHALL determine Full_Disk_Access status through the TCC_Access_Module with a read-only probe of the User_TCC_DB, and SHALL print the System Settings pane that grants Full_Disk_Access when the status is "missing".

### Requirement 2: Capture-Tool Teardown

**User Story:** As a developer, I want a teardown command that undoes what setup and capture changed, so that my machine returns to its prior state when recording ends.

#### Acceptance Criteria

1. WHEN `capture.sh teardown` is run, THE Capture_CLI SHALL send a termination signal to each Ward_App process identified by the Marker_File, wait up to 5 seconds for it to exit, and send a forced-kill signal to any such process still running after 5 seconds.
2. WHEN `capture.sh teardown` is run and the Marker_File exists, THE Capture_CLI SHALL delete the Marker_File after the Ward_App process termination in criterion 1 has completed.
3. IF the Marker_File identifies a process that no longer exists, THEN THE Capture_CLI SHALL skip the termination step for that process, delete the Marker_File, and continue the remaining teardown actions.
4. WHEN `teardown` is run and the Setup_State_File exists, THE Capture_CLI SHALL print one line for each permission that `setup` found missing, and each line SHALL contain the permission name and the System Settings pane where the user can revoke it.
5. WHEN `teardown` is run, THE Capture_CLI SHALL send an interrupt signal to each `screencapture` process the Capture_CLI started, wait up to 10 seconds for it to exit, and then verify that the partially recorded video file is playable, or report the file path and a warning that the file is unplayable.
6. WHEN `teardown` is run, THE Capture_CLI SHALL quit each target app that the Capture_CLI launched and that was not running before the Capture_Session began, and SHALL leave running any target app that was already running before the Capture_Session began.
7. IF a target app does not quit within 10 seconds of the quit request, THEN THE Capture_CLI SHALL report the app name and continue the remaining teardown actions without force-killing the app.
8. WHEN `teardown` completes, THE Capture_CLI SHALL leave every file in `captures/` that holds a recorded artifact with the same content and modification time it had before `teardown` started, except for finalizing the partially recorded video file described in criterion 5.
9. IF `teardown` is run when no Setup_State_File, Ward_App process, Marker_File, or `screencapture` process started by the Capture_CLI exists, THEN THE Capture_CLI SHALL exit with code `0` and print a message indicating that nothing needed to be torn down.
10. WHEN a Capture_Session is interrupted by `SIGINT` or `SIGTERM`, THE Capture_CLI SHALL run the same cleanup actions as `teardown` and then exit with a non-zero exit code.
11. WHEN `capture.sh teardown` is run, THE Capture_CLI SHALL run the Restore described in Requirement 16 for every TCC_Snapshot present in `captures/.state/`, after the actions in criteria 1 to 7 and before reporting completion.

### Requirement 3: Scoped Permission Reset

**User Story:** As a developer, I want to reset TCC permissions for a specific app only, so that the prompt appears again without disturbing the other apps on my machine.

#### Acceptance Criteria

1. WHEN `capture.sh reset <profile_id>` is run, THE Capture_CLI SHALL run `tccutil reset <service> <bundle_id>` once for each service listed in the App_Profile, in the order the services are listed, using only the bundle ID declared in that App_Profile.
2. IF a `tccutil` invocation would use a bundle ID that is `All` (case-insensitive), empty, or absent from the selected App_Profile, THEN THE Capture_CLI SHALL refuse to run that invocation, print an error message naming the rejected bundle ID value, and exit with a non-zero code before running any `tccutil` command.
3. WHEN `reset` is run with the option `--service <service>`, THE Capture_CLI SHALL run `tccutil reset` once, for that service only and the selected App_Profile's bundle ID.
4. IF the value given to `--service` is not listed in the selected App_Profile, THEN THE Capture_CLI SHALL print an error message naming the invalid service and the services the App_Profile lists, run no `tccutil` command, and exit with a non-zero code.
5. WHEN `reset` completes, THE Capture_CLI SHALL print each `tccutil` command that was executed, in execution order, together with its exit code.
6. IF `tccutil` returns a non-zero exit code, THEN THE Capture_CLI SHALL print the `tccutil` error output, continue with the remaining services, and exit with a non-zero code after the last service has been attempted.
7. WHEN `reset` is run with the option `--dry-run`, THE Capture_CLI SHALL print each `tccutil` command that would run, execute no `tccutil` command, leave all TCC permissions unchanged, and exit with code 0.
8. WHEN a Capture_Session starts without the option `--no-reset`, THE Capture_CLI SHALL complete the scoped reset for the Scenario's TCC service, and only that service, before the Prompt_Message is sent.
9. IF the scoped reset run at Capture_Session start returns a non-zero exit code, THEN THE Capture_CLI SHALL not send the Prompt_Message, print the `tccutil` error output, and exit with a non-zero code.

### Requirement 4: App Profile Mechanism

**User Story:** As a developer, I want each target app described in its own profile file, so that I can add another coding agent app by writing one file.

#### Acceptance Criteria

1. WHEN the Capture_CLI starts any command, THE Capture_Framework SHALL load every file in `scripts/capture/profiles/` whose name ends in `.profile` as an App_Profile, and SHALL skip every file whose name does not end in `.profile`.
2. THE App_Profile SHALL declare the Profile_ID, the display name, the bundle ID, the app launch command, the input-field locator, the send action, and a list of one to 20 Scenarios, where each Scenario declares a Scenario name, a Prompt_Message of 1 to 2,000 characters, and a TCC service key.
3. WHEN `capture.sh list` is run, THE Capture_CLI SHALL print one entry per loaded App_Profile containing the Profile_ID, the bundle ID, and the names of all its Scenarios, and SHALL exit with code 0.
4. WHEN `capture.sh list` is run and `scripts/capture/profiles/` contains no loadable `*.profile` file, THE Capture_CLI SHALL print a message stating that no profiles were found and SHALL exit with a non-zero code.
5. WHEN a new valid `*.profile` file is added to `scripts/capture/profiles/`, THE Capture_CLI SHALL list the new Profile_ID in `capture.sh list` and SHALL run its Scenarios, without any modification to Capture_Framework scripts.
6. IF an App_Profile omits a required field or declares a required field with an empty value, THEN THE Capture_CLI SHALL exit with a non-zero code, SHALL print the profile file path and the name of the missing field, and SHALL run no Scenario from that App_Profile.
7. IF an App_Profile declares a Profile_ID that differs from its file name without the `.profile` extension, THEN THE Capture_CLI SHALL reject that App_Profile, SHALL print both the declared Profile_ID and the file name, SHALL exit with a non-zero code, and SHALL run no Scenario from that App_Profile.
8. THE Capture_Framework SHALL ship App_Profiles for `zcode` and `deepseek-harness`.
9. THE Capture_Framework SHALL ship a template profile at `scripts/capture/profiles/_template.profile.example` that contains a comment describing each required field, and THE Capture_CLI SHALL NOT load it as an App_Profile.
10. THE App_Profile for each shipped app SHALL declare at least the Scenarios named `desktop` and `removable-volume`.

### Requirement 5: Target App Interaction

**User Story:** As a developer, I want the framework to open a target app and send it a prompt, so that the app's agent performs the action that raises the permission dialog.

#### Acceptance Criteria

1. WHEN `capture.sh prompt <profile_id> <scenario>` is run, THE Capture_CLI SHALL launch the target app if the app is not running and bring the app's window to the foreground through `osascript`.
2. WHEN the target app window is frontmost, THE Capture_CLI SHALL focus the input field using the locator in the App_Profile, type the Scenario's Prompt_Message through System Events, and perform the profile's send action.
3. IF the target app window does not appear within the App_Profile's launch timeout (default 20 seconds, allowed range 1 to 300 seconds), THEN THE Capture_CLI SHALL exit with a non-zero code, print a message to standard error naming the timeout duration and the app's bundle ID, and leave the app running.
4. IF the input-field locator matches no element within 5 seconds of the target app window becoming frontmost, THEN THE Capture_CLI SHALL exit with a non-zero code, save a screenshot of the current screen into the Session_Directory, send no Prompt_Message text, and print a message to standard error naming the locator that failed and the screenshot's location.
5. WHEN the Scenario's Prompt_Message contains a path to a removable volume, THE Capture_CLI SHALL verify that the path exists before typing any text.
6. IF a path to a removable volume in the Prompt_Message does not exist, THEN THE Capture_CLI SHALL exit with a non-zero code, send no Prompt_Message text, and print a message to standard error naming the missing path.
7. WHERE an App_Profile declares an `approve_tool_call` step, THE Capture_CLI SHALL perform that step after the send action so that an agent's own tool-use confirmation does not block the TCC_Prompt.
8. IF the `approve_tool_call` step cannot be performed within 30 seconds of the send action, THEN THE Capture_CLI SHALL exit with a non-zero code and print a message to standard error naming the step that failed.
9. WHEN the clipboard method is used to send Prompt_Message text, THE Capture_CLI SHALL restore the clipboard contents held before the paste within 2 seconds after the paste completes, including when the paste or send action fails.
10. THE Capture_CLI SHALL send Prompt_Message text to System Events as either a clipboard paste or a keystroke sequence.

### Requirement 6: Prompt Detection

**User Story:** As a developer, I want the framework to detect that a permission dialog is on screen, so that captures begin at the right moment and failures are caught.

#### Acceptance Criteria

1. WHEN the send action completes, THE Capture_CLI SHALL poll the window list every 250 ms, with a tolerance of ±50 ms, for a TCC_Prompt window owned by `UserNotificationCenter` or the process the macOS version uses for TCC dialogs, until a TCC_Prompt window is detected or the Scenario's prompt timeout elapses.
2. WHEN a TCC_Prompt window is detected, THE Capture_CLI SHALL record the detection time (UTC, millisecond precision) and the window bounds (origin and size in screen points) in the Manifest.
3. IF no TCC_Prompt window is detected within the Scenario's prompt timeout (default 45 seconds, configurable from 1 to 300 seconds), THEN THE Capture_CLI SHALL save a full-screen screenshot to the Session_Directory, mark the Capture_Session `no_prompt` in the Manifest, retain all files already written to the Session_Directory, and exit with a non-zero code.
4. WHEN a TCC_Prompt window is detected in `ward` Capture_Mode, THE Capture_CLI SHALL poll every 250 ms for a Fortress HUD window owned by the Ward_App until a HUD window is found or a HUD timeout of 10 seconds elapses.
5. WHEN a Fortress HUD window is detected in `ward` Capture_Mode, THE Capture_CLI SHALL record the HUD detection time and the HUD window bounds in the Manifest.
6. IF the Fortress HUD does not appear within the HUD timeout in `ward` Capture_Mode, THEN THE Capture_CLI SHALL save a full-screen screenshot to the Session_Directory, mark the Capture_Session `no_hud` in the Manifest, retain all files already written to the Session_Directory, and exit with a non-zero code.
7. WHEN the Scenario declares a TCC service key and a TCC_Prompt window is detected, THE Capture_CLI SHALL record in the Manifest a boolean value indicating whether the observed prompt text matches the expected service, and SHALL record the value `unknown` if the prompt text cannot be read.

### Requirement 7: Screenshot Capture

**User Story:** As a developer, I want still images of the prompt with and without the Ward, so that I can use them in the README and Devpost gallery.

#### Acceptance Criteria

1. WHEN a TCC_Prompt is detected, THE Capture_CLI SHALL save a full-display PNG named `screen.png` into the Session_Directory using `screencapture`, within 2 seconds of detection.
2. WHEN a TCC_Prompt is detected, THE Capture_CLI SHALL save a PNG containing only the TCC_Prompt window, named `prompt.png`, into the Session_Directory using the window ID obtained from the window list, within 2 seconds of detection.
3. WHEN the Capture_Mode is `ward` and the Fortress HUD window is present in the window list as on screen, THE Capture_CLI SHALL save a PNG containing only the HUD window, named `hud.png`, into the Session_Directory within 2 seconds of the HUD appearing.
4. WHEN `hud.png` and `prompt.png` have both been saved in `ward` Capture_Mode, THE Capture_CLI SHALL save `pair.png` into the Session_Directory, cropped from the display to the smallest rectangle containing both the TCC_Prompt and Fortress HUD window bounds plus a 24 px margin on each side, clamped to the display bounds.
5. WHEN the `--display <index>` option is given with an index of an attached display, THE Capture_CLI SHALL capture from that display.
6. IF the `--display <index>` option is given with an index that does not match an attached display, THEN THE Capture_CLI SHALL exit with a non-zero status, write an error message to standard error that names the invalid index, and save no image files.
7. WHERE the `--display` option is not given, THE Capture_CLI SHALL capture from the main display.
8. IF a capture step fails (the `screencapture` process exits non-zero, the window ID is not found, or the HUD window is absent in `ward` Capture_Mode), THEN THE Capture_CLI SHALL skip only that image, write an error message to standard error naming the skipped file, continue with the remaining images, and leave no zero-byte or partial file at the skipped file's name.
9. THE Capture_CLI SHALL use exactly the file names `screen.png`, `prompt.png`, `hud.png`, and `pair.png` for these images, in every session and independent of the Manifest contents, so that other tools can locate them without reading the Manifest.

### Requirement 8: Video Capture

**User Story:** As a developer, I want a video of the full prompt flow, so that I can cut clips for the submission demo.

#### Acceptance Criteria

1. WHEN a Capture_Session starts and `--no-video` is not given, THE Capture_CLI SHALL start recording a video named `flow.mov` with `screencapture -v` into the Session_Directory, and SHALL confirm that the `screencapture` process is running at least 1 second after launch, before the Prompt_Message is sent.
2. WHEN a TCC_Prompt is detected while recording is active, THE Capture_CLI SHALL keep recording for the Scenario's dwell time (default 4 seconds, accepted range 1 to 60 seconds) before the interaction step runs.
3. WHEN the interaction step completes, THE Capture_CLI SHALL send `SIGINT` to the `screencapture` process within 2 seconds, and SHALL wait up to 10 seconds for the process to exit and the file to finalize.
4. WHERE the option `--video-backend ffmpeg` is given and `ffmpeg` is installed, THE Capture_CLI SHALL record with `ffmpeg` using AVFoundation and write `flow.mp4` instead of `flow.mov`.
5. IF the option `--video-backend ffmpeg` is given and `ffmpeg` is not installed, THEN THE Capture_CLI SHALL exit with a non-zero code before sending the Prompt_Message, and SHALL print an error message indicating that `ffmpeg` was not found.
6. IF the video backend cannot start or exits within 1 second of launch, THEN THE Capture_CLI SHALL exit with a non-zero code before sending the Prompt_Message, SHALL print an error message indicating the backend failure, and SHALL leave any files already written to the Session_Directory in place.
7. WHEN recording stops, THE Capture_CLI SHALL verify that the video file exists and has a size greater than zero bytes, and SHALL record the file size in bytes and the duration in seconds in the Manifest.
8. IF the video file is missing or has a size of zero bytes after recording stops, or the recording process does not exit within 10 seconds of `SIGINT`, THEN THE Capture_CLI SHALL mark the video as failed in the Manifest, SHALL print an error message indicating the video failure, and SHALL exit with a non-zero code.
9. WHERE the option `--no-video` is given, THE Capture_CLI SHALL skip video recording, SHALL capture images only, and SHALL record no video entry as successful in the Manifest.
10. WHERE the option `--no-images` is given, THE Capture_CLI SHALL skip screenshots and record video only.

### Requirement 9: Capture Mode Control

**User Story:** As a developer, I want to capture the same Scenario with and without Gatekeeper's Ward, so that the before and after comparison is faithful.

#### Acceptance Criteria

1. WHEN a Capture_Session starts in `baseline` Capture_Mode, THE Capture_CLI SHALL check for running Ward_App processes before the Scenario begins.
2. IF a Ward_App process is running when a `baseline` Capture_Session starts, THEN THE Capture_CLI SHALL stop the Capture_Session before the Scenario begins, exit with a non-zero code, print an error message to stderr stating that a Ward_App process was found and giving its process ID, and write no Scenario artifacts to the Session_Directory.
3. WHEN a `ward` Capture_Session starts and no Ward_App process is running, THE Capture_CLI SHALL start the Ward_App through `scripts/run_ward.sh` and write the Ward_App process ID to the Marker_File.
4. WHEN the Capture_CLI has started the Ward_App, THE Capture_CLI SHALL poll for the Ward_App menu bar item at intervals of 500 milliseconds or less and begin the Scenario within 500 milliseconds after the item is detected.
5. IF the Ward_App menu bar item is not present 10 seconds after the Ward_App was started, THEN THE Capture_CLI SHALL stop the Ward_App process that it started, remove the Marker_File, exit with a non-zero code, and print an error message to stderr stating that the menu bar item timed out.
6. IF the Ward_App is already running before a `ward` Capture_Session starts, THEN THE Capture_CLI SHALL reuse that process, SHALL NOT write the Marker_File, and SHALL NOT stop that process during `teardown`.
7. WHEN `capture.sh run <profile_id> <scenario>` is run without `--mode`, THE Capture_CLI SHALL execute the `baseline` Capture_Session first and the `ward` Capture_Session second, each with a fresh scoped reset.
8. IF the `baseline` Capture_Session exits with a non-zero code when `--mode` is omitted, THEN THE Capture_CLI SHALL NOT start the `ward` Capture_Session and SHALL exit with a non-zero code.
9. WHEN a `ward` Capture_Session ends, THE Capture_CLI SHALL stop the Ward_App if the Marker_File exists and records its process ID, and SHALL leave the Ward_App running if the Marker_File does not exist.
10. THE Capture_CLI SHALL store the artifacts of the two Capture_Modes in sibling directories whose Session_Directory paths are identical except for the final path segment, which is `baseline` for one and `ward` for the other.

### Requirement 10: Prompt Resolution and Safe Cleanup

**User Story:** As a developer, I want the framework to dismiss the permission dialog after capture, so that the next Capture_Session begins from a clean state.

#### Acceptance Criteria

1. WHEN artifacts for a Capture_Session are saved, THE Capture_CLI SHALL resolve the TCC_Prompt by clicking the button named by the `--resolve` option (`allow` or `deny`), with `deny` as the default when the option is omitted.
2. WHERE the option `--resolve none` is given, THE Capture_CLI SHALL leave the TCC_Prompt on screen, print a notice that manual resolution is needed, and skip the 5-second dismissal check in criterion 5.
3. IF the `--resolve` option is given a value other than `allow`, `deny`, or `none`, THEN THE Capture_CLI SHALL exit with a non-zero code before clicking any button, print an error naming the accepted values, and leave the TCC_Prompt unchanged.
4. IF the button for the chosen resolution is not found in the TCC_Prompt window, THEN THE Capture_CLI SHALL save a screenshot of the TCC_Prompt window, exit with a non-zero code, report the names of all buttons that were found, and record the failure in the Manifest.
5. WHEN the TCC_Prompt is resolved, THE Capture_CLI SHALL check, polling at intervals of 500 milliseconds or less, that the TCC_Prompt window no longer exists within 5 seconds of the click, and record the result (`dismissed` or `still present`) in the Manifest.
6. IF the TCC_Prompt window still exists 5 seconds after the click, THEN THE Capture_CLI SHALL exit with a non-zero code, print an error stating the prompt was not dismissed, and still run the scoped reset in criterion 7.
7. WHEN a Capture_Session ends, whether it succeeded, failed, or was interrupted, THE Capture_CLI SHALL run the scoped reset for only the Scenario's service and test bundle ID, so that a granted `allow` decision does not persist and permissions for other services and applications are unchanged.
8. IF the scoped reset exits with a non-zero code, THEN THE Capture_CLI SHALL print a warning naming the service and the manual reset needed, record the reset failure in the Manifest, and exit with a non-zero code.

### Requirement 11: Session Manifest and Artifact Layout

**User Story:** As a developer, I want every capture recorded with its metadata, so that I can reproduce a capture and select assets for the submission.

#### Acceptance Criteria

1. WHEN a Capture_Session ends, THE Capture_CLI SHALL write exactly one Manifest in JSON inside the Session_Directory within 2 seconds of the session ending, recording the Profile_ID, bundle ID, Scenario, Capture_Mode, start and end timestamps in UTC ISO 8601, macOS version, artifact file names (relative to the Session_Directory, 0 to 50 entries), and outcome (exactly one of `ok`, `no_prompt`, `no_hud`, or `error`).
2. WHERE the Capture_Mode is `ward`, WHEN a Capture_Session ends, THE Capture_CLI SHALL record in the Manifest the Ward_App git commit hash as a 40-character hexadecimal string, or the value `unknown` if the hash cannot be determined.
3. THE Capture_CLI SHALL create each Session_Directory with the path structure defined in the Glossary.
4. IF a Session_Directory already exists at the target path, THEN THE Capture_CLI SHALL abort the session with a non-zero exit code, report an error indicating the path conflict, and leave every file in the existing Session_Directory unchanged.
5. IF a Capture_Session ends with an outcome other than `ok`, THEN THE Capture_CLI SHALL record in the Manifest the name of the failing step and an error message of 1 to 1,000 characters describing the failure, and SHALL retain all artifacts captured before the failure.
6. WHEN `capture.sh run` completes both Capture_Modes, THE Capture_CLI SHALL write a `summary.md` file in `captures/<timestamp>/<profile_id>/<scenario>/` that links the baseline and ward artifacts side by side, with one link per artifact file name listed in each Manifest.
7. IF `capture.sh run` ends with only one Capture_Mode completed, THEN THE Capture_CLI SHALL NOT write `summary.md` and SHALL report the incomplete mode in its exit output.
8. FOR ALL Manifest files written by the Capture_CLI, parsing the file as JSON and writing it back SHALL produce a document equal to the original in all keys and values (round-trip property).
9. THE Capture_Framework SHALL list `captures/` in `.gitignore`.
10. WHEN `capture.sh export <dir>` is run, THE Capture_CLI SHALL copy the selected `*.png` and `flow.*` files to `<dir>`, creating `<dir>` if absent, and SHALL leave the source files unchanged.
11. IF `capture.sh export <dir>` finds no `*.png` or `flow.*` files to copy, or `<dir>` cannot be written, THEN THE Capture_CLI SHALL exit with a non-zero code and report an error indicating which condition occurred.

### Requirement 12: Capture Command Orchestration

**User Story:** As a developer, I want one command that runs the full capture for an app and scenario, so that producing the submission assets is repeatable.

#### Acceptance Criteria

1. WHEN `capture.sh run <profile_id> <scenario>` is run with a `profile_id` that matches a loaded App_Profile and a `scenario` that the App_Profile declares, THE Capture_CLI SHALL execute these steps one at a time in this order: preflight check, scoped reset, video start, app launch, Prompt_Message send, prompt detection, screenshots, dwell, resolve, video stop, scoped reset, and Manifest write.
2. IF `capture.sh run` is given a `profile_id` that matches no loaded App_Profile, or a `scenario` that the App_Profile does not declare, THEN THE Capture_CLI SHALL exit with a non-zero code before running any step, print a message that names the unknown value, and create no Session_Directory.
3. WHEN the option `--all-scenarios` is given, THE Capture_CLI SHALL run every Scenario declared in the App_Profile as its own Capture_Session, one after another, in the order the App_Profile declares them.
4. WHEN the option `--all-profiles` is given, THE Capture_CLI SHALL run the selected Scenario as its own Capture_Session for each loaded App_Profile that declares it, one after another, and SHALL skip each App_Profile that does not declare it and print a message that names the skipped App_Profile.
5. IF any step in a Capture_Session fails, THEN THE Capture_CLI SHALL run the cleanup actions of Requirement 2, write a Manifest with outcome `error` that names the failed step, and stop with a non-zero code.
6. WHERE the option `--keep-going` is given, IF any step in a Capture_Session fails, THEN THE Capture_CLI SHALL, after the cleanup and the `error` Manifest, start the next Capture_Session, and SHALL exit with a non-zero code after the last Capture_Session if at least one Capture_Session ended with outcome `error`.
7. WHEN the preflight check runs, THE Capture_CLI SHALL check each of these three conditions: the setup permissions are present (including Full_Disk_Access unless `--no-restore` is given), the target app is installed, and the display is awake and unlocked.
8. IF one or more preflight checks fail, THEN THE Capture_CLI SHALL run all three checks to completion, exit with a non-zero code, print a message that names every failed check, and run no later step of the Capture_Session.
9. WHEN each step starts, THE Capture_CLI SHALL print one line to standard output that contains the step name and a timestamp with at least one-second resolution, and SHALL append the same line to `capture.log` in the Session_Directory within 1 second of printing it.

### Requirement 13: Security and Privacy Boundaries

**User Story:** As a developer, I want the framework to stay inside macOS security boundaries, so that the capture tooling cannot damage the machine or leak personal data.

#### Acceptance Criteria

1. THE Capture_Framework SHALL read and write TCC state only through `tccutil`, the System Settings user interface, and the TCC_Access_Module, and SHALL reference, open, read, or modify a TCC database file only from the TCC_Access_Module, using `sqlite3` with parameterized or escaped values, and only on the User_TCC_DB.
2. WHEN the Capture_CLI is about to execute `tccutil reset`, THE Capture_CLI SHALL execute it only for a bundle ID declared in a loaded App_Profile.
3. IF a `tccutil reset` target bundle ID is not declared in any loaded App_Profile, THEN THE Capture_CLI SHALL skip the command, leave all TCC state unchanged, print an error naming the rejected bundle ID, and exit with a non-zero status.
4. THE Capture_Framework SHALL make zero outbound network connections during a Capture_Session.
5. WHEN a Scenario targets a user data location such as Desktop, THE App_Profile SHALL direct the Prompt_Message to a read-only operation (list directory contents) that does not create, modify, copy, move, or delete any file.
6. WHEN the Capture_CLI starts, THE Capture_CLI SHALL print, before any Scenario runs, a notice stating that screenshots and video may include personal data visible on screen and that `captures/` is excluded from version control.
7. WHERE the option `--redact-notifications` is given, THE Capture_CLI SHALL enable Do Not Disturb through Focus before the first Scenario starts during the Capture_Session.
8. WHERE the option `--redact-notifications` is given, WHEN the Capture_Session ends, THE Capture_CLI SHALL restore the Focus state that was active before the Capture_Session started.
9. IF the Capture_Session is interrupted or terminates with an error while `--redact-notifications` is active, THEN THE Capture_CLI SHALL restore the prior Focus state before exiting.
10. THE Capture_CLI SHALL quote and escape every value interpolated into `osascript` source and shell commands, including Prompt_Message text, bundle IDs, and paths, so that a value containing quotes, backslashes, spaces, `$`, backticks, semicolons, or newlines is passed as a single literal argument and executes no additional command.
11. THE Capture_Framework SHALL contain no reference to the string `TCC.db` or to `com.apple.TCC` in any file under `scripts/capture/` other than the TCC_Access_Module, its tests, and documentation.
12. THE Capture_Framework SHALL pass every value that enters a `sqlite3` statement (bundle ID, service key, row column values) through parameter binding or, where binding is unavailable, through escaping that doubles each single quote, and SHALL pass binary column values as hexadecimal blob literals.

### Requirement 14: Documentation and Project Integration

**User Story:** As a developer, I want clear documentation and tests for the framework, so that teammates can use it and judges can see it as a documented part of the project.

#### Acceptance Criteria

1. THE Capture_Framework SHALL include a `scripts/capture/README.md` that contains a separate section for each of the following: setup, teardown, reset, profile authoring, every Capture_CLI subcommand, every option of every subcommand, and the macOS permissions required by each subcommand.
2. THE `scripts/capture/README.md` SHALL include a worked example that adds a new app profile, listing each step in order from creating the profile to a successful `run --dry-run` of that profile.
3. THE Capture_Framework SHALL include automated tests that run to completion with exit code 0 on a Mac where no macOS permission (Accessibility, Screen Recording, Automation) has been granted to the test runner, and that cover profile parsing, profile validation errors, the `tccutil` bundle-ID guard, Session_Directory naming, and Manifest round-trip.
4. IF an automated test requires a macOS permission grant to execute, THEN THE Capture_Framework SHALL mark that test as skipped with a reason indicating the missing permission, and SHALL NOT report the test as failed.
5. WHEN the user runs `run --dry-run`, THE Capture_CLI SHALL print each step name and the full text of each external command to standard output in execution order, SHALL execute none of those external commands, and SHALL exit with code 0.
6. WHEN `run --dry-run` completes, THE Capture_CLI SHALL leave the filesystem unchanged, with no files created, modified, or deleted, and the TCC permission database unchanged.
7. WHEN the first successful capture completes, THE Capture_Framework SHALL have a `docs/devlog.md` entry that states the feature's purpose and lists the file name of each asset produced by that capture.
8. THE Capture_Framework SHALL implement the Capture_CLI in `zsh` or `bash`, SHALL implement UI automation with `osascript` (AppleScript or JXA), and SHALL NOT require any third-party package other than the optional `ffmpeg`. The macOS system `sqlite3` is permitted for the TCC_Access_Module.
9. THE Capture_Framework SHALL include automated tests for the TCC_Access_Module that run against a temporary SQLite database file with the same `access` table schema, never against the User_TCC_DB, and that cover snapshot content, restore, idempotence, created-row removal, scope limits, and the file-reference scan in Requirement 13.11.

### Requirement 15: TCC Grant Snapshot Before Reset

**User Story:** As a developer, I want my existing permission grants for the target app saved before the framework resets them, so that recording does not cost me my real settings.

#### Acceptance Criteria

1. WHEN a command is about to run the first `tccutil reset` for an App_Profile in a run, and the `--no-restore` option is not given, THE Capture_CLI SHALL take a TCC_Snapshot for that App_Profile through the TCC_Access_Module before running that `tccutil reset`. This applies to `capture.sh reset`, `prompt`, and `run`.
2. THE TCC_Access_Module SHALL take the TCC_Snapshot with a read-only `sqlite3` query on the User_TCC_DB that selects every column of each row in the Snapshot_Scope, and SHALL write the rows to `captures/.state/tcc-snapshot-<bundle_id>.json` with each value byte-for-byte identical to the stored value, including the `csreq` column.
3. WHEN the TCC_Snapshot is written, THE Capture_CLI SHALL copy it into the Session_Directory of each Capture_Session of that run as `tcc-snapshot.json` and list it in that Session_Directory's Manifest.
4. WHEN a run covers several Capture_Sessions for the same App_Profile, THE Capture_CLI SHALL take the TCC_Snapshot once, before the first reset of that App_Profile, and SHALL NOT overwrite an existing TCC_Snapshot for that bundle ID with a later one while a Restore for it is pending.
5. WHEN the Snapshot_Scope contains no rows for the App_Profile, THE Capture_CLI SHALL write a TCC_Snapshot that records zero rows and the services that had no row, and SHALL continue the run.
6. THE TCC_Access_Module SHALL select only rows whose `client` equals the App_Profile's bundle ID and whose `service` is one of the App_Profile's declared services.
7. IF the TCC_Snapshot cannot be taken or cannot be written (Full_Disk_Access missing, the User_TCC_DB unreadable, `sqlite3` missing, the query failing, or the snapshot file not written completely), THEN THE Capture_CLI SHALL run no `tccutil reset`, print the reason and the System Settings pane that grants Full_Disk_Access where relevant, and exit with a non-zero code.
8. WHEN the TCC_Snapshot has been written, THE Capture_CLI SHALL verify the file by re-reading it and comparing its row count with the row count of the query, and IF the counts differ, THEN THE Capture_CLI SHALL treat the snapshot as not taken under criterion 7.
9. WHEN the TCC_Snapshot is taken for a run and no TCC_Backup exists for that run, THE TCC_Access_Module SHALL copy the whole User_TCC_DB to a new TCC_Backup file, and SHALL NOT overwrite or delete any earlier TCC_Backup file.
10. WHERE the `--no-restore` option is given, THE Capture_CLI SHALL take no TCC_Snapshot, SHALL make no TCC_Backup, SHALL skip every action of Requirement 16, SHALL NOT check Full_Disk_Access, and SHALL print a notice that the grants of the App_Profile will not be restored.
11. WHEN `--dry-run` is given, THE Capture_CLI SHALL print each snapshot, backup, and restore action it would take, and SHALL read, write, copy, or create nothing, including no `sqlite3` invocation.

### Requirement 16: TCC Grant Restore

**User Story:** As a developer, I want the framework to put my permission grants back automatically when a run ends or crashes, so that I can keep working with my apps unchanged.

#### Acceptance Criteria

1. WHEN a run ends by success, by failure of any step, or by `SIGINT` or `SIGTERM`, and a TCC_Snapshot exists for an App_Profile of that run, THE Capture_CLI SHALL Restore that App_Profile's Snapshot_Scope after the end-of-session scoped reset of Requirement 10.
2. THE Capture_CLI SHALL provide the subcommand `capture.sh restore [<profile_id>]` that performs the Restore for the named App_Profile, or for every TCC_Snapshot in `captures/.state/` when no App_Profile is named, using only the stored TCC_Snapshot, so that a crashed run can be undone from a fresh shell.
3. THE `capture.sh teardown` subcommand SHALL perform the same Restore as `capture.sh restore` (Requirement 2.11).
4. WHEN the TCC_Access_Module restores a Snapshot_Scope, THE TCC_Access_Module SHALL write each TCC_Snapshot row back into the User_TCC_DB with `INSERT OR REPLACE`, with every column value equal to the TCC_Snapshot value.
5. WHEN the TCC_Access_Module restores a Snapshot_Scope, THE TCC_Access_Module SHALL delete each row in the Snapshot_Scope that is present in the User_TCC_DB and has no counterpart in the TCC_Snapshot, matched by `service` and `client`.
6. WHEN the TCC_Snapshot records zero rows, THE TCC_Access_Module SHALL restore by deleting every Snapshot_Scope row present in the User_TCC_DB and SHALL write no row.
7. THE TCC_Access_Module SHALL perform the writes of one Restore inside a single SQLite transaction, so that a failure leaves the User_TCC_DB without a partial Restore.
8. WHEN the writes of a Restore have completed, THE TCC_Access_Module SHALL re-read the Snapshot_Scope rows and compare them with the TCC_Snapshot, and SHALL report the Restore as verified only when every row matches in every column and no extra Snapshot_Scope row exists.
9. WHEN a Restore is verified, THE Capture_CLI SHALL restart the user's `tccd` process so that it reloads the User_TCC_DB, and SHALL print a line stating that the restart was done or failed.
10. THE Restore SHALL be idempotent: running it again after a verified Restore, with the same TCC_Snapshot, SHALL leave the Snapshot_Scope rows unchanged and report the Restore as verified.
11. WHEN a Restore is verified, THE Capture_CLI SHALL mark the TCC_Snapshot as restored, by renaming it to `tcc-snapshot-<bundle_id>.restored.json` in `captures/.state/`, so that a later run takes a new TCC_Snapshot.
12. IF the verification in criterion 8 finds a difference, THEN THE Capture_CLI SHALL keep the TCC_Snapshot as pending, print the differing rows' `service` values and the path of the TCC_Backup, and exit with a non-zero code.
13. IF macOS rejects a write to the User_TCC_DB (for example because of System Integrity Protection or database protection), THEN THE Capture_CLI SHALL leave the User_TCC_DB unchanged by the failed write, keep the TCC_Snapshot as pending, print a message that names the cause reported by `sqlite3`, and print the manual fallback: re-enable the permission for the app in System Settings under Privacy & Security, with the path of the TCC_Backup.
14. IF a Restore finds no pending TCC_Snapshot, THEN THE Capture_CLI SHALL print that there is nothing to restore and exit with code 0.
15. WHEN a Restore step fails during `teardown` or signal cleanup, THE Capture_CLI SHALL run the remaining cleanup actions of Requirement 2 and then exit with a non-zero code.
16. WHERE the `--no-restore` option is given to `run`, `prompt`, or `reset`, THE Capture_CLI SHALL skip the Restore for that command, and `capture.sh restore` SHALL still restore any TCC_Snapshot that earlier runs left pending.
17. WHEN `--dry-run` is given to `restore`, THE Capture_CLI SHALL print each action the Restore would take and write nothing.

### Requirement 17: TCC Database Access Boundaries

**User Story:** As a developer, I want the database access limited to one small, auditable place with strict scope, so that a mistake in the framework cannot damage the system's permissions.

#### Acceptance Criteria

1. THE TCC_Access_Module SHALL open only the User_TCC_DB at `~/Library/Application Support/com.apple.TCC/TCC.db` and SHALL NOT open the system-level TCC database at any time.
2. IF a path given to the TCC_Access_Module, after resolving symbolic links, differs from the User_TCC_DB path of the current user, THEN THE TCC_Access_Module SHALL refuse to open it and exit with a non-zero code, except for a temporary database path that automated tests pass through the environment variable `CAPTURE_TCC_DB_TEST`, which THE TCC_Access_Module SHALL accept only when that variable is set and the path is under the system temporary directory.
3. THE TCC_Access_Module SHALL read or write only rows of the `access` table in the Snapshot_Scope.
4. IF the bundle ID is empty, is `All` in any letter case, or is not declared in a loaded App_Profile, THEN THE TCC_Access_Module SHALL refuse the operation, print the rejected value, and change nothing.
5. IF a service key is empty or is not declared by the selected App_Profile, THEN THE TCC_Access_Module SHALL refuse the operation, print the rejected value, and change nothing.
6. WHEN the TCC_Access_Module takes a snapshot, THE TCC_Access_Module SHALL open the User_TCC_DB in read-only mode.
7. THE TCC_Access_Module SHALL make the TCC_Backup before its first write in a run and SHALL verify that the TCC_Backup is a readable SQLite file of the same size as the User_TCC_DB before it writes.
8. IF the TCC_Backup cannot be made or verified, THEN THE TCC_Access_Module SHALL write nothing to the User_TCC_DB and THE Capture_CLI SHALL run no `tccutil reset` and exit with a non-zero code.
9. THE Capture_Framework SHALL NOT disable System Integrity Protection, SHALL NOT grant any permission by editing a database row that was not in the TCC_Snapshot, and SHALL NOT add rows other than those restored from a TCC_Snapshot.
10. THE Capture_CLI SHALL print, before the first snapshot of a run, a notice stating that the framework reads and may write the user's TCC database for the selected bundle ID only, and the path of the TCC_Backup.
11. WHEN `capture.sh doctor` is run, THE Capture_CLI SHALL print whether a pending TCC_Snapshot exists in `captures/.state/` and the bundle ID it belongs to, without opening the User_TCC_DB for writing.
