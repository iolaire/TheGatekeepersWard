# Permission Capture Framework

`scripts/capture/capture.sh` records the macOS TCC permission prompt that an AI coding agent app raises, as screenshots and video, in two modes:

- **baseline**: Gatekeeper's Ward is not running, so the capture shows Apple's bare prompt.
- **ward**: Gatekeeper's Ward is running, so the capture shows the Fortress HUD beside the prompt.

The output feeds the README, the Devpost page, and the demo video. The framework drives each target app through System Events (Accessibility) and `osascript`, resets TCC decisions only for the target app through `tccutil`, saves the target app's existing TCC rows first and puts them back afterwards, and records with `screencapture`. Each target app is described by one profile file, so adding an app needs no framework code change. The framework adds no runtime code to Gatekeeper's Ward.

Requirements: macOS, bash 3.2 or later, and the stock tools `osascript`, `screencapture`, `tccutil`, `swift`, `sw_vers`, and `sqlite3` (all ship with macOS or Xcode tools). `ffmpeg` is optional and only used with `--video-backend ffmpeg`.

> **Privacy notice.** Screenshots and video can contain personal data that is visible on screen. They are written to `captures/`, which is excluded from version control. The tool prints this notice before every `prompt` or `run`. Use `--redact-notifications` to turn on Do Not Disturb while recording.

## Quick start

```sh
scripts/capture/capture.sh setup                 # grant the capture permissions once
scripts/capture/capture.sh doctor                # confirm permissions and tools
scripts/capture/capture.sh list                  # see the loaded profiles
scripts/capture/capture.sh run zcode desktop --dry-run   # preview every step, change nothing
scripts/capture/capture.sh run zcode desktop     # baseline, then ward
scripts/capture/capture.sh teardown              # undo anything left behind
scripts/capture/capture.sh restore               # put back saved TCC grants after a crash
```

## Command reference

```
capture.sh <subcommand> [options] [args]
```

| Subcommand | Purpose |
|---|---|
| `setup` | Check and request the capture-tool permissions |
| `doctor` | Read-only check of permissions and tools |
| `teardown` | Undo everything the framework started |
| `reset <profile>` | Scoped `tccutil reset` for one profile, after a TCC snapshot |
| `restore [<profile>]` | Restore pending TCC snapshots (see [Restore](#restore-tcc-grants)) |
| `prompt <profile> <scenario>` | Run one capture session (baseline unless `--mode` is given) |
| `run <profile> <scenario>` | Run baseline, then ward |
| `list` | List profiles and their scenarios |
| `export <dir>` | Copy screenshots and videos to `<dir>` |

`capture.sh help` (or `-h`, `--help`) prints the usage text.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | The operation ran and failed (for example a missing permission, a failed session, or no profiles found) |
| 2 | Usage error: unknown subcommand, option, profile, or scenario, an invalid option value, or an invalid profile file |
| 130 | Interrupted by `SIGINT` (cleanup ran first) |
| 143 | Terminated by `SIGTERM` (cleanup ran first) |

### Options

An option that is not valid for the subcommand is rejected with exit code 2.

| Option | Valid for | Meaning |
|---|---|---|
| `--dry-run` | `reset`, `restore`, `prompt`, `run` | Print each step and the full text of each external command, run none of them, and create no file. Snapshot, backup, and restore actions are printed as `would ...` lines, with no `sqlite3` call. |
| `--service <svc>` | `reset` | Reset only this TCC service. It must be one of the services the profile lists. |
| `--mode baseline\|ward` | `prompt`, `run` | Run one mode only. `prompt` defaults to `baseline`. `run` defaults to both, baseline first. |
| `--resolve allow\|deny\|none` | `prompt`, `run` | Button to click after capture. Default `deny`. `none` leaves the prompt on screen and prints a notice that it needs manual resolution. |
| `--no-reset` | `prompt`, `run` | Skip the reset at the start of the session. The reset at the end still runs. |
| `--no-video` | `prompt`, `run` | Capture images only. |
| `--no-images` | `prompt`, `run` | Record video only. The tool still polls for the Fortress HUD in ward mode. |
| `--video-backend screencapture\|ffmpeg` | `prompt`, `run` | Recorder. Default `screencapture` (writes `flow.mov`). `ffmpeg` writes `flow.mp4` and needs `ffmpeg` installed. |
| `--display <n>` | `prompt`, `run` | Capture display `n` (1 is the main display, which is the default). |
| `--no-restore` | `setup`, `doctor`, `reset`, `prompt`, `run` | Do not read or write the TCC database: no snapshot, no backup, no restore, and no Full Disk Access check. A notice says the grants will not be restored. `capture.sh restore` still restores snapshots that earlier runs left pending. |
| `--redact-notifications` | `prompt`, `run` | Turn on Do Not Disturb before the first session and restore the previous Focus state afterwards, including after an error or interrupt. |
| `--all-scenarios` | `run` | Run every scenario in the profile, in declared order. Omit the scenario argument. |
| `--all-profiles` | `run` | Run the given scenario for every loaded profile that declares it. Profiles without it are skipped and named on standard error. |
| `--keep-going` | `run` | After a failed session, run cleanup, write the `error` manifest, then continue with the next session. The exit code is still 1 at the end. |

`--all-profiles` takes only the scenario (`run --all-profiles desktop`). Combined with `--all-scenarios` it takes no positional argument.

`doctor` takes `--no-restore` only. To make `doctor` check for `ffmpeg`, set the environment variable `CAPTURE_VIDEO_BACKEND=ffmpeg`.

### Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `CAPTURE_PROFILES_DIR` | `scripts/capture/profiles` | Directory to load `*.profile` files from. Useful for experiments and tests. |
| `CAPTURE_ROOT` | repository root | Directory whose `captures/` subdirectory receives sessions and is read by `export`. |
| `CAPTURE_STATE_DIR` | `captures/.state` | Where runtime state is kept (see [State files](#state-files)). |
| `CAPTURE_PROMPT_OWNER` | `UserNotificationCenter` | Owner name of the TCC prompt window. |
| `CAPTURE_PROMPT_LAYER` | `8` | Window layer of the TCC prompt. |
| `CAPTURE_WARD_MENUBAR_MIN_LAYER` | `24` | Minimum layer of the Ward menu bar item. |
| `CAPTURE_ALLOW_LABELS` | `ok,allow` | Comma-separated, lower-case labels of the allow button. |
| `CAPTURE_DENY_LABELS` | `don't allow,deny` | Comma-separated, lower-case labels of the deny button. |
| `CAPTURE_VIDEO_BACKEND` | `screencapture` | Backend that `doctor` checks. |
| `CAPTURE_PBT_PROFILE` | `dev` | Selects the Hypothesis profile for the tests: `dev` runs 25 examples per property, `full` runs 100. See [Tests](#tests). |

The defaults live in `lib/defaults.sh`. Re-measure the prompt owner and layer with `swift scripts/dump_window_list.swift` while a prompt is on screen.

## Permissions each subcommand needs

The terminal app that runs `capture.sh` (the capture host, for example Terminal, iTerm, or the Kiro terminal) receives the grants. There are five:

| Permission | Where it is granted |
|---|---|
| Accessibility | System Settings > Privacy & Security > Accessibility |
| Screen Recording | System Settings > Privacy & Security > Screen & System Audio Recording |
| Automation for System Events | System Settings > Privacy & Security > Automation |
| Automation for Finder | System Settings > Privacy & Security > Automation |
| Full Disk Access | System Settings > Privacy & Security > Full Disk Access |

Full Disk Access is what lets the framework read the user-level TCC database to snapshot, back up, and restore the target app's grants. It is not needed with `--no-restore`. macOS may apply a new Full Disk Access grant only after the Capture_Host (the terminal app) is quit and reopened, so restart it if `doctor` still reports `full-disk-access: missing` after you grant it.

Some macOS versions have no per-user TCC database at all, so there is nothing to snapshot or restore even with Full Disk Access granted. `setup` and `doctor` then print `full-disk-access: unavailable (no user TCC database on this macOS; use --no-restore)`, `setup` does not open the Full Disk Access pane, and `reset`, `prompt` and `run` stop with the same message instead of running without a snapshot. Use `--no-restore` on such a machine.

| Subcommand | Needs |
|---|---|
| `setup` | None to start. It requests each missing permission and opens the matching System Settings pane. Full Disk Access has no request API, so `setup` only opens its pane. With `--no-restore`, Full Disk Access is skipped. |
| `doctor` | None. It reports status and never prompts or writes files. |
| `list` | None. |
| `reset` | Full Disk Access, to snapshot the TCC rows before `tccutil reset` runs. None with `--no-restore`. |
| `restore` | Full Disk Access, to read and write the TCC database. Nothing to restore needs none. |
| `export` | None. It copies files only. |
| `teardown` | Automation for System Events, only to quit an app the framework launched. Full Disk Access, only when a TCC snapshot is pending. Other cleanup needs no grant. |
| `prompt`, `run` | All five (four with `--no-restore`). The preflight check stops the session and names the missing ones if any is absent. |
| `reset`, `restore`, `prompt`, `run` with `--dry-run` | None. Nothing is executed. The commands are only printed. |

The framework never touches System Integrity Protection and never opens the system-level TCC database. The only file that names a TCC database is `lib/tccdb.sh`, and it opens only the user-level database for the target app's bundle ID and declared services. The reset itself still goes through `tccutil`. See [Security boundaries](#security-boundaries).

## Setup

```sh
scripts/capture/capture.sh setup
```

1. `setup` prints one line per permission: `accessibility`, `screen-recording`, `automation-system-events`, `automation-finder`, `full-disk-access`. Each says `granted` or `missing`. With `--no-restore` the last line reads `full-disk-access: skipped (--no-restore)`.
2. For each missing permission it opens the matching System Settings pane and triggers the system request. Full Disk Access has no request, so only its pane opens, and a message reminds you to restart the Capture_Host if needed.
3. Grant the permissions, then press Return in the terminal. `setup` checks again.
4. It writes `captures/.state/setup.json`, which records for each permission whether it was already granted before `setup`. Running `setup` again never overwrites an entry that is already recorded. With `--no-restore`, `full-disk-access` is left out unless an earlier run already recorded it.
5. Exit code 0 means every checked permission is granted (five, or four with `--no-restore`). Otherwise `setup` exits with 1 and names each permission that is still missing and the pane that grants it.

After granting Screen Recording, macOS may ask to quit and reopen the terminal. Full Disk Access can need the same restart before `full-disk-access` reports `granted`.

Run `doctor` at any time to check the state without changing anything:

```sh
scripts/capture/capture.sh doctor
```

It prints the five permission lines (the Full Disk Access line reads `skipped (--no-restore)` with that option), a `found` or `not found` line for `osascript`, `screencapture`, and `tccutil` (and `ffmpeg` when selected), a `pending tcc snapshot:` line that lists the bundle IDs with a pending snapshot or `none`, and a `macos:` line with the version, prompt owner, and prompt layer. It exits with 1 if a tool is missing. The Full Disk Access check is a read-only open of the user TCC database. It writes nothing.

## Teardown

```sh
scripts/capture/capture.sh teardown
```

`teardown` is safe to run at any time and works from a fresh shell, because it reads only `captures/.state`. It does these things in order:

1. Restores the clipboard if a snapshot is left over.
2. Stops the recorder with `SIGINT`, waits up to 10 seconds, and checks the video is playable. It reports the path and a warning if it is not.
3. Stops the Ward that the framework started (the process named in `ward.pid`): `SIGTERM`, a 5-second wait, then `SIGKILL`. It then deletes `ward.pid`. A Ward that was already running before the session is left alone.
4. Quits the apps the framework launched. An app that was already running is left running. An app that does not quit within 10 seconds is reported and left running, never force-killed.
5. Restores every pending TCC snapshot, the same restore as `capture.sh restore` (see [Restore](#restore-tcc-grants)). It runs after the apps quit. If it fails, the remaining steps still run and `teardown` exits with 1.
6. Restores the Focus state saved by `--redact-notifications`.
7. Prints one line per permission that `setup` found missing, with the System Settings pane where you can revoke it. The framework does not revoke anything itself.

If nothing needs tearing down (no pending snapshot either), it prints `teardown: nothing needed to be torn down` and exits with 0. Files already in `captures/` are not changed, apart from finalizing a partly recorded video.

An interrupted `prompt` or `run` (`Ctrl+C` or `SIGTERM`) runs the same cleanup, plus the end-of-session scoped reset and the TCC restore, and then exits with 130 or 143.

## Reset

```sh
scripts/capture/capture.sh reset <profile> [--service <svc>] [--dry-run] [--no-restore]
```

Before the first `tccutil reset` for a profile, `reset` takes a TCC snapshot and backup (see [TCC snapshot and backup](#tcc-snapshot-and-backup)). If that fails, no `tccutil` command runs and the exit code is 1. A standalone `reset` leaves the snapshot pending and prints `tcc-snapshot: <bundle_id> (left pending; run capture.sh restore to undo)`. Run `capture.sh restore` to put the grants back. Pass `--no-restore` to skip both.

Then it runs `tccutil reset <service> <bundle_id>` once for each service the profile lists, in the order listed, and prints each command with its exit code. A failed `tccutil` command prints its error output; the remaining services still run and the exit code is 1 at the end.

- `--service <svc>` resets one service. If `<svc>` is not in the profile, the tool names it, lists the valid services, runs nothing, and exits non-zero.
- `--dry-run` prints each `tccutil` command and runs none.
- Every command passes through a guard first. The bundle ID must come from a loaded profile, must not be empty, and must not be `All` in any letter case. If any command is refused, nothing runs.

`prompt` and `run` reset only the scenario's own service, once before the prompt is sent and once after the session ends (also after a failure), so an `allow` decision does not persist. If the first reset fails, the prompt is not sent. Use `--no-reset` to skip the first one. After the last session's end reset, `prompt` and `run` restore the saved grants (see [Restore](#restore-tcc-grants)).

If the reset at the end fails, the tool prints the manual command, for example:

```sh
tccutil reset SystemPolicyDesktopFolder dev.zcode.app
```

## TCC snapshot and backup

The scoped reset removes the target app's real grants. To avoid losing them, `reset`, `prompt`, and `run` save them first, unless `--no-restore` is given.

- **Scope.** Only rows whose `client` is the profile's bundle ID and whose `service` is one of the services the profile declares in its scenarios.
- **Service names.** Profiles use the `tccutil` short service names, for example `SystemPolicyDesktopFolder`. `lib/tccdb.sh` maps each one to `kTCCService<Name>` (for example `kTCCServiceSystemPolicyDesktopFolder`) only where it builds SQL for the database. A name that already starts with `kTCCService` is left as is.
- **Once per bundle per run.** The snapshot is taken before the first reset of the run. Later sessions of the same run reuse it. A snapshot that is still pending from an earlier run is reused, never overwritten. If the pending snapshot lacks a service that the profile now declares, or cannot be read, the command stops and asks you to run `capture.sh restore` first.
- **Backup.** The whole user TCC database is also copied, with its `-wal` and `-shm` files when present, to `captures/.state/TCC.db.backup-<run timestamp>`. The copy is checked for size and readability. Earlier backups are never overwritten or deleted.
- **Notice.** The run prints which bundle ID it may write and where the backup goes.
- **Session copy.** Each session directory receives `tcc-snapshot.json`, and the manifest lists it.
- **No rows.** A scope with no rows still yields a snapshot (zero rows plus the list of services without a row). Restore then deletes any row that appeared during the run.
- **Failure.** If the database cannot be read (Full Disk Access missing, `sqlite3` missing, the file absent), the command prints the cause and the Full Disk Access pane, runs no `tccutil reset`, and exits with 1.
- **`--no-restore`.** No snapshot, no backup, no Full Disk Access check, and a one-time notice that the grants will not be restored.
- **`--dry-run`.** Prints `would snapshot ...` and `would back up ...` lines and calls no `sqlite3`.

Files in `captures/.state/`:

| File | Meaning |
|---|---|
| `tcc-snapshot-<bundle_id>.json` | A pending snapshot. It records the bundle ID, the run, the backup path, the declared services, the services without a row, the column names, and every row. Values are stored as tagged hex cells so they come back byte for byte, including `csreq`. |
| `tcc-snapshot-<bundle_id>.restored.json` | A snapshot that was restored and verified. The next run takes a new one. |
| `TCC.db.backup-<run timestamp>` (and `-wal`, `-shm`) | A copy of the whole user TCC database from the start of a run. |

Delete old `.restored.json` files and backups yourself when you no longer need them. The tool never removes them.

## Restore TCC grants

```sh
scripts/capture/capture.sh restore [<profile>] [--dry-run]
```

`restore` puts back the grants saved by a snapshot. It uses only the stored snapshot, so it works from a fresh shell after a crash.

- With a profile ID it restores that profile's pending snapshot. With none it restores every pending snapshot and keeps going after a failure.
- A pending snapshot whose bundle ID is in no loaded profile is refused.
- The restore runs in one SQLite transaction. It deletes the scope rows for the bundle ID and services, then inserts the snapshot rows, so rows created during the run are removed and a failure leaves no partial result.
- It then re-reads the scope rows and compares them with the snapshot in every column. Only an exact match counts as verified.
- After a verified restore it restarts the user's `tccd` (the line `tccd restart: done` or `tccd restart: failed`), prints `restored TCC rows for bundle id <id>`, and renames the snapshot to `.restored.json`.
- Running it again is safe. With nothing pending it prints `nothing to restore` and exits with 0.
- Exit code 1 if any restore fails. The snapshot then stays pending.
- `--dry-run` prints `would restore TCC rows for bundle id <id> from <file>` and writes nothing.

When it runs automatically: at the end of `prompt` and `run` after the last end-of-session reset (the line `tcc-restore: verified`, `nothing pending`, or `skipped (--no-restore)`), on failure and on `SIGINT` or `SIGTERM` cleanup, and in `teardown`. A standalone `reset` does not restore. `--no-restore` skips the automatic restore only. `capture.sh restore` still restores whatever an earlier run left pending.

### When macOS rejects the write

If macOS refuses the write (for example through System Integrity Protection or database protection), the database is left as it was and the snapshot stays pending. The command prints the error that `sqlite3` reported, then the manual fallback: re-enable the permission for the app in System Settings under Privacy & Security. It also prints the path of the backup of the whole database. If verification finds a difference instead, it lists the `service` of each differing row and the backup path. Either way, fix the cause and run `capture.sh restore` again, or re-enable the grant by hand.

## Profile authoring

A profile is one file, `scripts/capture/profiles/<profile_id>.profile`. The file is parsed as data and never executed. Files whose names do not end in `.profile` are ignored, which is why `_template.profile.example` is never loaded.

Format: blank lines, `# comment` lines, and `key = value` lines. Duplicate keys are an error. A trailing ` # comment` is stripped only on the numeric and enum fields (`launch_timeout`, `send_method`, `prompt_timeout`, `dwell`). Every other value is kept as written, so a prompt may contain ` #`.

### Top-level fields

| Field | Required | Meaning |
|---|---|---|
| `profile_id` | yes | Lowercase kebab-case name. It must equal the file name without `.profile`. |
| `display_name` | yes | Name shown in logs. |
| `bundle_id` | yes | App bundle ID. Find it with `mdls -name kMDItemCFBundleIdentifier /Applications/My.app`. This is the only ID ever passed to `tccutil reset`. |
| `launch` | yes | Command that starts the app. The first word must be `open`, `osascript`, or an absolute path under `/Applications`. |
| `input_locator` | yes | Where to type. `ax:` followed by a System Events element path (see [Re-deriving input locators](#re-deriving-input-locators-with-accessibility-inspector)). Or `find:<class>` (for example `find:text area`) to use the first element of that class in the front window, for apps whose layout changes between screens. |
| `send_action` | yes | How to submit: `key:return`, `key:cmd+return`, or `ax:<element path to click>`. Key combos accept `return`, `enter`, `tab`, `space`, `escape`, or one character, with optional `cmd+`, `shift+`, `opt+`, `ctrl+` prefixes. |
| `send_method` | no | `clipboard` (default) or `keystroke`. The clipboard method restores your clipboard afterwards, even when the paste fails. |
| `launch_timeout` | no | Seconds to wait for the app window, 1 to 300, default 20. |
| `approve_tool_call` | no | Element to click after sending, for example `ax:button "Allow"`, so the agent's own tool-use confirmation does not block the TCC prompt. It waits up to `approve_timeout` seconds (default 30). `find:button "Allow once"` matches a button by its label. |
| `approve_timeout` | no | Seconds to wait for `approve_tool_call`, 1–300, default 30. Raise it for agents that think before asking (DeepSeek Harness uses 120). |
| `ax_manual_accessibility` | no | `true` for Electron apps (DeepSeek Harness, VS Code forks). After the window appears, `app.sh` sets the `AXManualAccessibility` attribute through `lib/axmanual.swift`, so the page and its input reach System Events. Electron forgets it when the app quits, so it runs after every launch. Default `false`. If `input_locator` matches nothing and Accessibility Inspector shows only empty groups, try this. |
| `prepare_action` | no | Element to click after launch and before typing, so each session starts from a clean view, for example `find:button "New Session"`. `ax:` or `find:` only. It waits up to 10 seconds, then 1.5 seconds for the view to settle. |

### Scenario fields

Each profile declares 1 to 20 scenarios as `scenario.<name>.<field>`. Names use letters, digits, `-`, and `_`.

| Field | Required | Meaning |
|---|---|---|
| `scenario.<name>.prompt` | yes | The message typed into the app, 1 to 2000 characters. Keep it read-only (list a directory). Do not ask the agent to create, change, move, or delete anything. |
| `scenario.<name>.service` | yes | TCC service the prompt should raise, written as the `tccutil` short name, for example `SystemPolicyDesktopFolder`, `SystemPolicyDocumentsFolder`, `SystemPolicyDownloadsFolder`, `SystemPolicyRemovableVolumes`. Do not write the `kTCCService` prefix. It selects the scoped reset and the snapshot scope, and `lib/tccdb.sh` adds the prefix for the database. |
| `scenario.<name>.prompt_timeout` | no | Seconds to wait for the prompt window, 1 to 300, default 45. |
| `scenario.<name>.dwell` | no | Seconds to keep recording with the prompt on screen, 1 to 60, default 4. |

If the prompt text names a path under `/Volumes/<name>`, the volume must exist and Finder must list it. Otherwise the session stops before sending any text.

Shipped profiles are `zcode` and `deepseek-harness`. Each has at least the scenarios `desktop` and `removable-volume`. Edit the `/Volumes/...` path in `removable-volume` to a volume that is mounted on your Mac.

### Validation errors

A profile with a problem is reported by path and field, for example:

```
.../bad.profile: missing field display_name
.../bad.profile: profile_id 'x' does not match file name 'bad'
.../bad.profile: scenario.desktop.dwell '99' out of range 1..60
```

An invalid profile makes `list`, `reset`, `prompt`, and `run` exit with 2 and run no scenario.

## Worked example: add a new profile and run `run --dry-run`

This example adds an app called Notes Agent (`com.example.notesagent`). The app does not have to be installed for a dry run, because a dry run executes nothing. The commands below use a temporary profile directory so the shipped profiles stay untouched. To add a real profile, leave out step 1 and copy into `scripts/capture/profiles/` instead.

1. Use a scratch profile directory (optional, for experiments):

   ```sh
   export CAPTURE_PROFILES_DIR="$(mktemp -d)"
   ```

2. Copy the template to a file named after the new profile ID:

   ```sh
   cp scripts/capture/profiles/_template.profile.example \
      "$CAPTURE_PROFILES_DIR/notes-agent.profile"
   ```

3. Edit the four fields that identify the app. `profile_id` must match the file name.

   ```sh
   sed -i '' \
     -e 's/^profile_id .*/profile_id     = notes-agent/' \
     -e 's/^display_name .*/display_name   = Notes Agent/' \
     -e 's/^bundle_id .*/bundle_id      = com.example.notesagent/' \
     -e 's/^launch  .*/launch         = open -b com.example.notesagent/' \
     "$CAPTURE_PROFILES_DIR/notes-agent.profile"
   ```

   Then check `input_locator` and `send_action` against the real app (see the next section). The template values are placeholders that work for a dry run. The template already declares the `desktop` scenario.

4. Confirm the profile loads:

   ```sh
   scripts/capture/capture.sh list
   ```

   Output (fields are tab-separated: profile ID, bundle ID, scenarios):

   ```
   notes-agent	com.example.notesagent	desktop
   ```

   A validation error here names the file and the field to fix.

5. Preview the reset:

   ```sh
   scripts/capture/capture.sh reset notes-agent --dry-run
   ```

   ```
   + tccutil reset SystemPolicyDesktopFolder com.example.notesagent
   ```

   Before the `tccutil` line, the dry run also prints the snapshot lines (`would snapshot TCC rows for bundle id com.example.notesagent, services: SystemPolicyDesktopFolder` and `would back up the TCC database to ...`). It prints them without a `sqlite3` call.

6. Preview the full run:

   ```sh
   scripts/capture/capture.sh run notes-agent desktop --dry-run
   echo "exit: $?"
   ```

   The command prints the privacy notice, then for the `baseline` session and the `ward` session each step name with a timestamp, followed by the exact commands that a real run would execute, each prefixed with `+`. The `reset` step also prints the `would snapshot` and `would back up` lines, and the run ends with `tcc-restore: would verify (dry-run)`. The steps appear in this order: `preflight`, `reset`, `video-start`, `app-launch`, `prompt-send`, `prompt-detection`, `screenshots`, `dwell`, `resolve`, `video-stop`, `reset-after`, `manifest-write`. An excerpt:

   ```
   session: notes-agent desktop baseline -> .../captures/<timestamp>/notes-agent/desktop/baseline
   2026-11-22T15:25:25Z step: preflight
   + swift .../lib/permcheck.swift status accessibility
   ...
   2026-11-22T15:25:25Z step: reset
   + tccutil reset SystemPolicyDesktopFolder com.example.notesagent
   2026-11-22T15:25:26Z step: video-start
   + screencapture -v -x .../baseline/flow.mov
   2026-11-22T15:25:26Z step: app-launch
   + open -b com.example.notesagent
   ...
   exit: 0
   ```

   Placeholders such as `<prompt window id>` and `<recorder pid>` stand for values that exist only during a real run. The dry run creates no file or directory (no `captures/` appears), runs no external command, reads no TCC database, and exits with 0.

7. When the preview looks right, run it for real with `scripts/capture/capture.sh run notes-agent desktop`. Without `--dry-run` this needs the five permissions from `setup` (four with `--no-restore`). The run snapshots the app's TCC rows, resets, records, and restores the rows at the end. To confirm, run `scripts/capture/capture.sh doctor` and check that `pending tcc snapshot: none`.

8. Unset the scratch directory when finished: `unset CAPTURE_PROFILES_DIR`.

## Published assets

A session that ends with outcome `ok` is published to `docs/demo/assets/<profile>/`, and its working folder under `captures/` is deleted. Each file is named `<mode>_<profile>_<scenario>_<file>`, with `-` turned into `_`:

```text
docs/demo/assets/deepseek-harness/
  baseline_deepseek_harness_desktop_prompt.png
  baseline_deepseek_harness_desktop_screen.png
  baseline_deepseek_harness_desktop_flow.mov
  baseline_deepseek_harness_desktop_manifest.json
  ward_deepseek_harness_desktop_hud.png
  ward_deepseek_harness_desktop_pair.png
  deepseek_harness_desktop_summary.md
```

- **One version:** a new session replaces every earlier file of the same mode, profile and scenario. Other modes and scenarios are left alone.
- **What is published:** `*.png`, `*.mov`, `*.mp4` and `manifest.json`. `capture.log` and `tcc-snapshot.json` are not, because they hold local paths and TCC rows.
- **Summary:** after `run`, `summary.md` is published as `<profile>_<scenario>_summary.md`, with its links rewritten to the published names.
- **Git:** the prompt, HUD and pair images, manifests and summaries are committed. Videos (`*.mov`, 90–100 MB each) and full-screen shots (`*_screen.png`, about 20 MB each at 5K) are git-ignored and stay in the folder for local use.
- **Failures:** a failed session is not published and keeps its folder under `captures/<ts>/` for debugging.
- **Another location:** set `CAPTURE_PUBLISH_DIR`.

## Re-deriving input locators with Accessibility Inspector

When an app update changes its window layout, the `input_locator` (and sometimes `send_action` or `approve_tool_call`) stops matching. The symptom is `input locator matched no element within 5s: <locator>` plus a screenshot saved as `input-locator-failed.png` in the session directory. No text is sent when this happens. To find the new locator:

1. Open **Accessibility Inspector**: in Xcode choose **Xcode > Open Developer Tool > Accessibility Inspector**. (It ships with Xcode, not with macOS.)
2. In the target selector at the top left, choose the running target app's process.
3. Click the **Point Inspection** button (the crosshair), then move the pointer over the app's text input. Inspector shows the element under the pointer.
4. Read the element's **Role** (for example `AXTextArea`, `AXTextField`, `AXButton`). Map it to the System Events class name: `AXTextArea` is `text area`, `AXTextField` is `text field`, `AXScrollArea` is `scroll area`, `AXGroup` is `group`, `AXButton` is `button`, and `AXWindow` is `window`.
5. Open the **Hierarchy** section (or use **Window > Show Hierarchy** in the Inspector) and walk up from the element to the window. For each level, count the element's position among its siblings **of the same role**, starting at 1.
6. Write the path from the innermost element out to the window, joined with ` of `:

   ```
   input_locator = ax:text area 1 of scroll area 1 of group 1 of window 1
   ```

   A step is `<class> <index>`, or `<class> "<name>"` when the element has a stable title or description, for example `button "Send"`. Names must not contain the text ` of `. If the outermost step is not a window, `window 1` is added for you.
7. Test the locator before a full run. With the app open and its input visible:

   ```sh
   osascript scripts/capture/lib/ui.applescript focus com.example.notesagent \
     'ax:text area 1 of scroll area 1 of group 1 of window 1' 5
   ```

   Success prints nothing and leaves the cursor in the input. A locator that matches nothing fails with `locator not found` after 5 seconds. This test needs Accessibility and Automation for System Events.
8. Use the same method for `send_action` when it is `ax:...` and for `approve_tool_call`.

Prefer a locator that depends on roles and indexes you can see in the hierarchy over one that depends on a title, because titles change with the app's language.

## Subcommand details

### `setup`

See [Setup](#setup). Needs no grants to start. Exit 0 when every checked permission is granted, 1 otherwise.

### `doctor`

See [Setup](#setup). Read-only: no permission request, no state file write.

### `teardown`

See [Teardown](#teardown).

### `reset <profile>`

See [Reset](#reset). Options: `--service`, `--dry-run`, `--no-restore`. Exit 2 for an unknown profile or invalid service.

### `restore [<profile>]`

See [Restore TCC grants](#restore-tcc-grants). Options: `--dry-run`. Exit 0 when restored or nothing is pending, 1 when a restore fails, 2 for an unknown profile.

### `list`

```sh
scripts/capture/capture.sh list
```

Prints one tab-separated line per loaded profile: profile ID, bundle ID, comma-separated scenario names. If the profile directory holds no loadable profile it prints `no profiles found in <dir>` and exits with 1. An invalid profile makes it exit with 2.

### `prompt <profile> <scenario>`

Runs one capture session. The default mode is `baseline`; pass `--mode ward` for a ward session. It accepts every option marked `prompt` in the [options table](#options).

### `run <profile> <scenario>`

Runs the baseline session, then the ward session, each with a fresh scoped reset. The TCC snapshot is taken once before the first reset, and the restore runs once after the last session. If the baseline session fails, the ward session does not start and the exit code is 1 (unless `--keep-going`). It accepts every option in the options table.

Unknown profiles, scenarios, and invalid option values exit with 2 before any step runs, and no session directory is created.

When both modes finish, `run` writes `summary.md` next to the two mode directories. If only one mode completed, it writes no summary and reports the incomplete mode on standard error.

The twelve steps of each session, in order:

| # | Step | What happens |
|---|---|---|
| 1 | `preflight` | Checks, always all three: permissions present, target app installed, display awake and unlocked. Every failure is named. Then, in baseline mode, refuses to continue if a Ward process is running. In ward mode it reuses a running Ward or starts one through `scripts/run_ward.sh` and waits up to 10 seconds for its menu bar item. |
| 2 | `reset` | Takes the TCC snapshot and backup once per run (and copies `tcc-snapshot.json` into the session), then does the scoped reset of the scenario's service. |
| 3 | `video-start` | Starts the recorder and checks it is still alive after 1 second. |
| 4 | `app-launch` | Launches the app if needed and waits for its window. |
| 5 | `prompt-send` | Checks `/Volumes/...` paths, focuses the input, sends the prompt, runs `approve_tool_call` if declared. |
| 6 | `prompt-detection` | Polls every 250 ms for the TCC prompt window until `prompt_timeout`. Records the time, bounds, and whether the prompt text matches the expected service. |
| 7 | `screenshots` | `screen.png` and `prompt.png`. In ward mode it also waits up to 10 seconds for the HUD, then saves `hud.png` and `pair.png` (prompt and HUD plus a 24 px margin). A failed image is skipped and named on standard error. |
| 8 | `dwell` | Keeps recording for the dwell time. |
| 9 | `resolve` | Clicks the `--resolve` button, then checks the prompt is gone within 5 seconds. |
| 10 | `video-stop` | Sends `SIGINT` to the recorder and checks the file. |
| 11 | `reset-after` | Scoped reset again. In ward mode it stops the Ward only if the framework started it. The TCC restore runs after the last session's reset-after. |
| 12 | `manifest-write` | Writes `manifest.json`. |

If a step fails, the tool runs the teardown cleanup, writes a manifest with outcome `error` that names the failed step, and stops (or continues with `--keep-going`).

### `export <dir>`

```sh
scripts/capture/capture.sh export ~/Desktop/ward-assets
```

Copies every `*.png` and `flow.*` file under `captures/<timestamp>/<profile>/<scenario>/<mode>/` into `<dir>` (created if needed) with the name `<timestamp>__<profile>__<scenario>__<mode>__<file>`. Source files are not changed. It exits with 1 and says `nothing to export` when no file matches, or `destination not writable` when `<dir>` cannot be written.

## Output layout

```
captures/
  <timestamp>/                      e.g. 20261122T152525Z
    <profile_id>/
      <scenario>/
        summary.md                  only when both modes finished
        baseline/                   and ward/, with the same file names
          capture.log               one line per step, same as standard output
          flow.mov                  or flow.mp4 with --video-backend ffmpeg
          screen.png  prompt.png    ward only: hud.png  pair.png
          manifest.json
          tcc-snapshot.json         copy of the run's TCC snapshot (not with --no-restore)
  .state/                           runtime state (see below)
```

A session directory that already exists is never reused: the session aborts with a path-conflict error and leaves the files untouched.

`manifest.json` records the profile ID, bundle ID, scenario, mode, UTC start and end times, macOS version, artifact file names, and the outcome: `ok`, `no_prompt`, `no_hud`, or `error`. A failed session also records the failing step and a message. A ward manifest records the 40-character commit hash of the checkout, or `unknown`. When the framework reuses a Ward that was already running, this is the commit of the current checkout (`git rev-parse HEAD`), which can differ from the build that is actually running. Restart the Ward from the checkout you mean to record if the commit matters. Failure screenshots (`no-prompt.png`, `no-hud.png`, `input-locator-failed.png`) stay in the directory.

### State files

`captures/.state/` holds the TCC snapshot and backup files (see [TCC snapshot and backup](#tcc-snapshot-and-backup)), `setup.json`, `ward.pid` (only when the framework started the Ward), `recorder.pid`, `launched.txt` (apps the framework launched), `clipboard.snap`, and `focus-state`. `teardown` reads and cleans these.

## Tests

```sh
.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests -n auto --dist worksteal
```

This takes about 45 seconds on a 10-core Mac. `-n auto` comes from `pytest-xdist` (pinned in `.kiro/tools/requirements.txt`) and runs one worker per core. Most tests start `bash`, `sqlite3` or `osascript` processes, so the suite is bound by process start-up, and without `-n` it takes several minutes.

The tests call every external binary through stubs, so they need no macOS permission. A test that would need one is skipped with the missing permission named. The TCC tests run against a temporary SQLite file with the same `access` schema, never against the real user database.

`CAPTURE_PBT_PROFILE` chooses how many examples each property-based test tries:

```sh
# dev (default): 10 examples, 2 for the end-to-end properties. Pre-commit uses this.
.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests -n auto --dist worksteal
# full: 100 examples for every property. Run before a release or the submission (several minutes).
CAPTURE_PBT_PROFILE=full .kiro/tools/.venv/bin/python -m pytest scripts/capture/tests -n auto --dist worksteal
```

The end-to-end properties run a whole `capture.sh` session, or real `sqlite3` and `osascript` calls, per example. They take their count from `E2E_EXAMPLES` in `tests/conftest.py`.

## Security boundaries

- `lib/tccdb.sh` is the only file that names a TCC database. It opens only the user-level database, refuses any other path (a temporary file is allowed only for tests), and never opens the system-level database.
- The framework reads and writes only rows for the profile's bundle ID and declared services. It writes only during a restore, in one transaction. Resets still use `tccutil`.
- Every value that reaches `sqlite3` is validated and quoted, and snapshot cells are rebuilt from a strict hex grammar. A refused value stops the command before `sqlite3` runs.
- `tccutil reset` runs only for bundle IDs declared in a loaded profile, and never for `All`.
- No script makes a network connection during a capture session.
- Every value passed to `osascript` or a shell command (prompt text, bundle IDs, paths) is passed as a single literal argument. Quotes, `$`, backticks, semicolons, and newlines run nothing.
- Shipped scenario prompts only list directories.
