# Design Document

## Overview

The Permission Capture Framework is a set of shell scripts under `scripts/capture/` that records macOS TCC permission prompts raised by AI coding agent apps, once without Gatekeeper's Ward (`baseline`) and once with it (`ward`). It produces screenshots, a video, and a JSON manifest for each Capture_Session. It adds no runtime code to the Ward app.

The framework has one entry script, `capture.sh`, with the subcommands `setup`, `teardown`, `reset`, `prompt`, `run`, `list`, `doctor`, and `export`. Everything it needs comes from macOS: `osascript`, `screencapture`, `tccutil`, `mdls`, `pgrep`, and an optional `ffmpeg`. A small Swift script is used only to ask macOS whether a permission is granted without prompting.

### Design decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Implement the CLI in **bash**. Scripts start with `#!/usr/bin/env bash` and use only features present in both bash 3.2 (the macOS system bash) and bash 5.x: no associative arrays, no `mapfile`. | Requirement 14.8 allows `zsh` or `bash`. The other scripts in `scripts/` are bash. Avoiding bash 4 features keeps the scripts working on a stock Mac. |
| D2 | Every value passes to `osascript`, `tccutil`, `screencapture`, and `pgrep` as a separate **argv element**. AppleScript and JXA sources are fixed files that read `argv`. No value is ever spliced into script source or into a string given to `eval`. | Requirement 13.10. Passing argv removes the need to escape for AppleScript at all. The only quoting code is the `%q` renderer used for dry-run output and logs. |
| D3 | Profiles are **parsed, never sourced**. The format is `key = value` lines read by a restricted parser. | A sourced profile could run arbitrary code. A parser also lets the validator name the exact missing field (4.6). |
| D4 | All side effects go through one function, `ext`, which prints the quoted command in dry-run mode and runs it otherwise. | Requirement 14.5 needs the full text of every external command and no execution. One choke point makes that testable. |
| D5 | Pure decision logic (profile validation, bundle-ID guard, reset plan, session paths, crop rectangle, window matching, session planning, manifest checks) lives in `lib/*.sh` functions with no I/O. | These functions are the ones property-based tests can drive. |
| D6 | JSON is produced and parsed with **`osascript -l JavaScript`** (`lib/json.js`), not `jq` or Python. | Requirement 14.8 forbids extra dependencies. `osascript` is already required. |
| D7 | Window discovery uses `CGWindowListCopyWindowInfo` through JXA (`lib/windows.js`). It never reads `kCGWindowName`. | Verified on this Mac: JXA reads owner, number, layer, and alpha with no Screen Recording grant. Matches `AlertLocator` in the app. |
| D8 | Permission status checks use `scripts/capture/lib/permcheck.swift`, run with `swift`. | Only `AEDeterminePermissionToAutomateTarget(askUserIfNeeded: false)` checks Automation without prompting, and JXA cannot build the `AEDesc` it needs. Accessibility (`AXIsProcessTrusted`) and Screen Recording (`CGPreflightScreenCaptureAccess`) use the same helper for consistency. |
| D9 | Automated tests are **pytest + Hypothesis**, reusing the virtualenv at `.kiro/tools/.venv` (Hypothesis 6.170.15 is already pinned in `.kiro/tools/requirements.txt`). Tests call the bash functions through subprocesses, with stub binaries for `tccutil`, `osascript`, `screencapture`, and `pgrep` placed first on `PATH`. | Requirement 14.3 needs tests that pass with no macOS permissions. The project's own steering requires a real PBT library rather than hand-rolled generators. Swift Testing is not used because the code under test is bash. |
| D10 | One run timestamp is chosen per `capture.sh run` invocation and shared by every Capture_Session of that run. | Requirement 9.10 needs `baseline` and `ward` to be siblings. `--all-scenarios` and `--all-profiles` then land under one timestamp directory. |

### Findings from inspecting the repo and this Mac

These resolve the assumptions that were open when the requirements were written.

1. **TCC prompt window owner.** `GatekeepersWard/HUD/AlertLocator.swift` and `docs/devlog.md` record the owner `UserNotificationCenter`, window layer `8`, and a size of about 260 x 282 pt. That was measured on macOS 27.0.1 (build 26A434). This Mac runs **macOS 27.2.1 (build 26B131)** and has not been re-measured. The framework therefore uses the same two values as defaults, makes them overridable (`CAPTURE_PROMPT_OWNER`, `CAPTURE_PROMPT_LAYER`), and `doctor` prints the macOS version next to them so a mismatch is visible. `scripts/dump_window_list.swift` is the documented way to re-measure.
2. **Ward HUD window.** `FortressHUDWindow` is an `NSPanel` with `styleMask [.nonactivatingPanel, .borderless, .fullSizeContentView]`, `level = .floating`, and a fixed width of `HUDMetrics.width = 400` pt. Its title is not set. The window server reports the owner as the executable name, `GatekeepersWardApp` (from `CFBundleExecutable` in `GatekeepersWardApp/Info.plist`), not "Gatekeeper's Ward". `NSWindow.Level.floating` is layer `3`. The panel starts at alpha `0` and fades in after the placement lookup, so the matcher requires alpha above 0.9 and a width within 2 pt of 400. That excludes the menu bar status item, which is also owned by `GatekeepersWardApp`.
3. **Ward menu bar item.** The status item is an on-screen window owned by `GatekeepersWardApp` at status-bar level. The existing window dump shows the menu bar `Window Server` at layer 24, so the item is expected at layer 25 (`kCGStatusWindowLevel`). This has not been observed because Ward is not running now. The matcher accepts any on-screen `GatekeepersWardApp` window with layer 24 or higher, and the first implementation task records the measured value.
4. **Target apps.** `/Applications/ZCode.app` has bundle ID `dev.zcode.app`. `/Applications/DeepSeek Harness.app` has bundle ID `com.deepseek.dsh`. Both profiles use these.
5. **Ward launch.** `scripts/run_ward.sh` builds with `swift build`, wraps the binary in `.build/GatekeepersWard.app`, signs ad hoc, and runs `open -n`. It returns after launching and does not print a PID. It also runs `pkill` on any running copy, so the framework calls it only when no Ward process exists. The framework finds the PID afterwards with `pgrep -n -f GatekeepersWard.app/Contents/MacOS/GatekeepersWardApp`, the same pattern `run_ward.sh --stop` uses. The 10 second menu bar timeout (9.5) starts when `run_ward.sh` returns, so build time is not counted.
6. **Tool availability.** `ffmpeg` is at `/opt/homebrew/bin/ffmpeg`. `screencapture` supports `-v` (video), `-l<windowid>`, `-R<x,y,w,h>`, `-D<display>`, `-o` (no shadow), and `-x` (no sound). `osascript -l JavaScript` can call `CGWindowListCopyWindowInfo` with `ObjC.castRefToObject` and returns owner, number, layer, and alpha.
7. **Existing conventions.** `scripts/reset_ward_trigger.sh` already resets TCC with `tccutil reset <service> <bundle>`. `scripts/hooks/*.sh` are bash. `captures/` is not yet in `.gitignore`, and the only Python tests are in `.kiro/tools/tests/`.
8. **Guarded by project hooks.** `scripts/hooks/guard-security-boundaries.py` and `docs/` steering forbid TCC database access. The framework never touches `TCC.db`, which matches Requirement 13.1.

## Architecture

### File layout

```
scripts/capture/
├── capture.sh                  # entry point: parses options, dispatches subcommands
├── README.md
├── lib/
│   ├── common.sh               # ext(), log_step(), die(), quoting, exit codes, UTC time
│   ├── profile.sh              # load, parse, validate App_Profiles (pure parts + file I/O)
│   ├── validate.sh             # pure option validators (resolve, display, timeouts, dwell)
│   ├── reset.sh                # bundle-ID guard, reset plan, reset execution
│   ├── plan.sh                 # session planning and failure policy (pure)
│   ├── session.sh              # Session_Directory naming, creation, step runner, summary.md
│   ├── manifest.sh             # accumulate manifest fields, write/validate manifest.json
│   ├── windows.sh              # window matching (pure) + window list polling
│   ├── shots.sh                # screenshots, crop rectangle (pure), display lookup
│   ├── video.sh                # recorder start/stop, playable check
│   ├── ward.sh                 # start/stop Ward, Marker_File, menu bar detection
│   ├── app.sh                  # launch target app, focus input, send prompt, approve step
│   ├── resolve.sh              # button lookup and click, dismissal check
│   ├── cleanup.sh              # teardown actions, signal traps
│   ├── setup.sh                # setup, doctor, Setup_State_File merge
│   ├── focus.sh                # --redact-notifications state save/restore
│   ├── export.sh               # export subcommand
│   ├── services.tbl            # TCC service key -> prompt keywords, button labels
│   ├── json.js                 # JXA: build and re-serialize JSON
│   ├── windows.js              # JXA: window list and display list as TSV
│   ├── ui.applescript          # System Events: focus, type, click, read prompt text
│   ├── clipboard.js            # JXA: snapshot/restore all pasteboard types
│   ├── focus.applescript       # Control Center Focus toggle (see Open items)
│   └── permcheck.swift         # permission status/request without side effects
├── profiles/
│   ├── zcode.profile
│   ├── deepseek-harness.profile
│   └── _template.profile.example
└── tests/
    ├── conftest.py             # bash harness, stub-bin builder, Hypothesis strategies
    ├── test_profile.py  test_reset_guard.py  test_quoting.py  test_paths_manifest.py
    ├── test_windows_crop.py  test_plan.py  test_validate.py  test_dryrun.py
    ├── test_setup_state.py  test_export_summary.py  test_cleanup.py
    └── stubs/                  # tccutil, osascript, screencapture, pgrep, open
```

`captures/` is added to `.gitignore`. Runtime state lives in `captures/.state/` (`setup.json`, `ward.pid`, `recorder.pid`, `launched.txt`, `focus-state`, `clipboard.snap`).

### Run flow

```mermaid
flowchart TD
    A[capture.sh run profile scenario] --> B[parse options, load profiles, validate names]
    B -->|unknown profile or scenario| X[exit 2, no directory]
    B --> C[plan sessions: scenarios x profiles x modes]
    C --> D{next session}
    D --> E[1 preflight]
    E --> F[2 scoped reset before]
    F --> G[3 video start]
    G --> H[4 app launch]
    H --> I[5 prompt send]
    I --> J[6 prompt detection]
    J --> K[7 screenshots + HUD detection]
    K --> L[8 dwell]
    L --> M[9 resolve]
    M --> N[10 video stop]
    N --> O[11 scoped reset after]
    O --> P[12 manifest write]
    P --> D
    E -.fail.-> Q
    F -.fail.-> Q
    G -.fail.-> Q
    H -.fail.-> Q
    I -.fail.-> Q
    J -.fail.-> Q
    K -.fail.-> Q
    M -.fail.-> Q
    Q[cleanup, scoped reset, error manifest] --> R{keep-going?}
    R -->|yes| D
    R -->|no| Z[exit non-zero]
    D -->|none left| S[summary.md when both modes completed]
```

The twelve step names, in order, are `preflight`, `reset`, `video-start`, `app-launch`, `prompt-send`, `prompt-detection`, `screenshots`, `dwell`, `resolve`, `video-stop`, `reset-after`, `manifest-write`. These are the names printed (12.9), recorded as the failing step in the manifest (11.5), and listed by `--dry-run`.

### Ordering inside `screenshots`

Requirement 7.1 needs `screen.png` and `prompt.png` within 2 seconds of prompt detection, but the HUD can take up to 10 seconds to appear. The `screenshots` step therefore does the following in order:

1. Capture `screen.png` and `prompt.png` at once.
2. In `ward` mode, poll for the HUD every 250 ms for up to 10 seconds, record it in the manifest, then capture `hud.png` and `pair.png` within 2 seconds of the HUD appearing.

With `--no-images`, step 1 and the capture calls in step 2 are skipped, but HUD polling still happens so the manifest and the `no_hud` outcome stay accurate (6.4 to 6.6).

### Cleanup model

One idempotent function, `cleanup_all`, performs every teardown action. It is called by the `teardown` subcommand, by the step runner on a failed step, and by the `INT`/`TERM` trap. It reads only `captures/.state/`, so it also works from a fresh shell after a crash. The `EXIT` trap calls it only when a session started and has not finished normally. Actions, in order:

1. Restore the clipboard from `clipboard.snap` if present.
2. Send `SIGINT` to the PID in `recorder.pid`, wait up to 10 s, check playability (2.5).
3. Send `SIGTERM` to the PID in `ward.pid`, wait up to 5 s, send `SIGKILL` if needed, delete the Marker_File (2.1 to 2.3).
4. Quit each bundle ID in `launched.txt` that the framework launched, wait up to 10 s each, never force-kill (2.6, 2.7).
5. Restore the Focus state from `focus-state` if present.
6. Print the revoke guidance for each permission `setup.json` records as originally missing (2.4).

The signal trap then exits with 130 (`SIGINT`) or 143 (`SIGTERM`).

## Components and Interfaces

### Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | A step failed, a check failed, or a tool is missing |
| 2 | Usage error or validation error detected before any step ran |
| 130, 143 | Interrupted by `SIGINT`, `SIGTERM` |

### `capture.sh` subcommands and options

| Subcommand | Options | Notes |
|---|---|---|
| `setup` | none | 4 status lines, requests missing permissions, opens Settings panes, writes Setup_State_File |
| `doctor` | none | Read-only. Never calls a request function and never writes state |
| `teardown` | none | Runs `cleanup_all`. Exit 0 and a message when nothing exists |
| `reset <profile>` | `--service <svc>`, `--dry-run` | Scoped `tccutil reset` |
| `prompt <profile> <scenario>` | `--mode`, `--resolve`, `--no-reset`, `--no-video`, `--no-images`, `--video-backend`, `--display`, `--dry-run`, `--redact-notifications` | One Capture_Session |
| `run <profile> <scenario>` | all `prompt` options plus `--all-scenarios`, `--all-profiles`, `--keep-going` | Baseline then ward, each with a fresh reset |
| `list` | none | One line per profile |
| `export <dir>` | none | Copies `*.png` and `flow.*` |

`prompt` and `run` share one session runner. `prompt` with no `--mode` runs `baseline`. `run` with no `--mode` runs `baseline` and then `ward`.

### `lib/common.sh`

| Function | Contract |
|---|---|
| `ext cmd args...` | In dry-run: print `+ ` followed by the `%q`-quoted command and return 0. Otherwise run the command with each argument as one argv element |
| `quote_cmd args...` | Pure. Prints `printf '%q '` of each argument. Evaluating the output in bash yields the original argv |
| `log_step name` | Prints `<UTC ISO-8601 seconds> step: <name>` to stdout and appends the same line to `$SESSION_DIR/capture.log` (skipped in dry-run, where no file may be written) |
| `die code msg` | Writes `msg` to stderr, exits with `code` |
| `utc_now_ms` | UTC ISO-8601 with milliseconds |

macOS `date` has no `%N`, so `utc_now_ms` calls `osascript -l JavaScript -e 'new Date().toISOString()'`. That always yields millisecond precision in UTC and needs no extra dependency.

### `lib/profile.sh`

Profile file format (3 forms of line, `#` starts a comment, blank lines ignored):

```
# scalar fields
profile_id     = zcode
display_name   = ZCode
bundle_id      = dev.zcode.app
launch         = open -b dev.zcode.app
input_locator  = ax:text area 1 of scroll area 1 of group 1 of window 1
send_action    = key:return
send_method    = clipboard            # optional: clipboard (default) | keystroke
launch_timeout = 20                   # optional, 1..300, default 20
approve_tool_call = ax:button "Allow"  # optional

# scenarios: scenario.<name>.<field>
scenario.desktop.prompt         = List the files on my Desktop. Only read names, change nothing.
scenario.desktop.service        = SystemPolicyDesktopFolder
scenario.desktop.prompt_timeout = 45  # optional, 1..300, default 45
scenario.desktop.dwell          = 4   # optional, 1..60, default 4
```

| Function | Pure? | Contract |
|---|---|---|
| `profile_parse path` | no | Reads the file, prints `key<TAB>value` lines. Rejects a line that is not blank, a comment, or `key = value`. Never executes content |
| `profile_validate path` | yes (given parsed text) | Checks required fields (`profile_id`, `display_name`, `bundle_id`, `launch`, `input_locator`, `send_action`), 1 to 20 scenarios, prompt length 1 to 2,000 characters, non-empty service, numeric ranges, and that `profile_id` equals the file name without `.profile`. Prints `path: missing field <name>` or `path: profile_id '<x>' does not match file name '<y>'` |
| `profile_load_all dir` | no | Loads every `*.profile` in `dir`, skips everything else (including `_template.profile.example`). A profile with errors makes the whole command exit 2 before any step |
| `profile_services id` | yes | Distinct scenario service keys in declaration order. This is the list `reset` walks (3.1) |
| `profile_scenarios id` | yes | Scenario names in declaration order |

The `list` command prints `profile_id<TAB>bundle_id<TAB>scenario,scenario,...`. With no loadable profile it prints `no profiles found` and exits 1 (4.4).

The template's `launch` and `input_locator` forms:

- `launch`: any command whose words are split once and run through `ext`, for example `open -b <bundle>`. The first word must be `open`, `osascript`, or an absolute path under `/Applications`.
- `input_locator`: `ax:<System Events element path>`. The path is passed to `ui.applescript` as one argv value and resolved against the app's front window. Using argv means the locator text cannot inject script source.
- `send_action`: `key:return`, `key:cmd+return`, or `ax:<element path to click>`.

### `lib/validate.sh` (pure)

| Function | Accepts |
|---|---|
| `valid_resolve v` | exactly `allow`, `deny`, `none` |
| `valid_display idx count` | decimal integer with `1 <= idx <= count` |
| `valid_range v lo hi` | decimal integer in `[lo, hi]`, no sign, no leading `+`, no spaces |
| `with_default v dflt` | `v` when non-empty, else `dflt` |

Defaults: launch timeout 20 s (1 to 300), prompt timeout 45 s (1 to 300), HUD timeout 10 s (fixed), dwell 4 s (1 to 60).

### `lib/reset.sh`

| Function | Pure? | Contract |
|---|---|---|
| `guard_bundle_id id known_ids...` | yes | Returns 0 only when `id` is non-empty, is not `All` in any letter case, and is exactly one of the loaded profiles' bundle IDs. Otherwise prints `refusing tccutil reset for bundle id '<id>'` to stderr and returns 1 |
| `reset_plan profile [--service s]` | yes | Prints one line per `tccutil reset <service> <bundle>` command. All services in order, or only `s`. Returns 2 with a message naming `s` and the valid services when `s` is not listed |
| `reset_run profile [--service s] [--dry-run]` | no | Calls `guard_bundle_id` for every planned command before running any. Runs each command through `ext`, prints `<command> -> exit <n>`, continues after a failure, exits non-zero at the end if any failed. In dry-run prints the plan and exits 0 |

Session-start reset (3.8, 3.9) and session-end reset (10.7, 10.8) call `reset_run` with `--service <scenario service>`. A failure at session start stops the session before `prompt-send`. A failure at session end sets a warning, a manifest field, and a non-zero exit but does not skip the remaining cleanup.

### `lib/plan.sh` (pure)

`plan_sessions` turns the command line into an ordered list of `profile<TAB>scenario<TAB>mode` rows:

| Inputs | Result |
|---|---|
| Single profile, single scenario, `--mode m` | one row, mode `m` |
| Same, no `--mode` and subcommand `run` | `baseline` row then `ward` row |
| `--all-scenarios` | the above for each scenario, in declared order |
| `--all-profiles` | for each loaded profile in name order that declares the scenario, the above. Profiles that do not declare it are listed on stderr as `skipping <id>: no scenario <name>` |

`plan_continue rows_so_far next_row keep_going` is the failure policy. It receives the outcomes so far (`ok` or `error`) and the next row, and decides whether that row starts. Requirements 9.8 and 12.6 interact here: a failed `baseline` must stop the `ward` half of the same pair, while `--keep-going` must still start the next Capture_Session. The policy is:

- A row may start when every earlier outcome is `ok`.
- With `--keep-going`, a row may also start after a failure, except that a `ward` row is skipped when the `baseline` row of its own pair failed.

Each row carries a `pair` id (the profile and scenario) so the policy can tell which `baseline` belongs to which `ward`.

`plan_exit_code outcomes` is 0 when every outcome is `ok`, else 1.

### `lib/session.sh`

| Function | Contract |
|---|---|
| `run_timestamp` | `date -u +%Y%m%dT%H%M%SZ`, called once per `run` |
| `session_path root ts profile scenario mode` | Pure. Prints `root/captures/<ts>/<profile>/<scenario>/<mode>` |
| `session_create path` | `mkdir -p` on the parent, then plain `mkdir` on the last segment. A failure of the last `mkdir` means the directory existed, and the command exits 1 with `session directory already exists: <path>` without touching it (11.4) |
| `run_step name fn args...` | Prints the step line, runs `fn`, on failure records the step name and message in the manifest and triggers `cleanup_all` |
| `write_summary root ts profile scenario` | Writes `summary.md` only when both `baseline` and `ward` manifests exist and have been written. Two-column table of relative links, one per artifact in each manifest (11.6, 11.7) |

Session directories under `captures/<ts>/...` are created only for a real run. `--dry-run` creates nothing.

### `lib/manifest.sh`

The manifest is built from a scratch directory `captures/.state/tmp.<pid>/` of `key<TAB>value` files, merged into JSON by one `osascript -l JavaScript lib/json.js build` call at the end of a session. The scratch directory is deleted afterwards, so a Session_Directory holds exactly one `manifest.json` (11.1).

| Function | Contract |
|---|---|
| `manifest_set key value` | Adds a scalar field |
| `manifest_add_artifact name` | Appends to the artifact list (0 to 50 entries, relative names only) |
| `manifest_write dir` | Builds and writes `manifest.json` within 2 s, then checks it with `manifest_check` |
| `manifest_check file` | Pure on the file text. Verifies required keys, the outcome enum, ISO-8601 timestamps, artifact count, failure fields, ward commit format. Returns non-zero with a reason |
| `manifest_roundtrip file` | Runs `json.js reserialize` and compares parsed values; used by tests |

### `lib/windows.sh` and `windows.js`

`windows.js list` prints one line per on-screen window, front to back, with tab-separated fields:

```
<windowNumber>  <owner>  <layer>  <alpha>  <x>  <y>  <w>  <h>
```

`windows.js displays` prints `<index> <x> <y> <w> <h>` per active display, main display first, in the same top-left-origin point coordinates. Index is 1-based, matching `screencapture -D`.

| Function | Pure? | Contract |
|---|---|---|
| `match_prompt owner layer < list` | yes | First row whose owner equals `owner`, layer equals `layer`, and w and h are both positive. Prints the row, or nothing. Same rule as `AlertMatcher.match` |
| `match_hud < list` | yes | First row with owner `GatekeepersWardApp`, layer 3, alpha above 0.9, and width within 2 of 400 |
| `match_ward_item < list` | yes | First row with owner `GatekeepersWardApp` and layer 24 or higher |
| `poll_window matcher timeout` | no | Calls `windows.js list` every 250 ms (sleep adjusted for the call duration, so the average period stays 250 ms), returns the first match or fails at the timeout |

The prompt owner and layer default to `UserNotificationCenter` and `8` and can be overridden with `CAPTURE_PROMPT_OWNER` and `CAPTURE_PROMPT_LAYER`.

### `lib/shots.sh`

| Function | Pure? | Contract |
|---|---|---|
| `crop_rect prompt hud margin display` | yes | Inputs are `x y w h` rectangles in points. Output is the smallest rectangle containing both windows grown by `margin` on every side, then intersected with `display` |
| `shot_screen dir display` | no | `screencapture -x -D<display> dir/screen.png` (main display when none given) |
| `shot_window dir id file` | no | `screencapture -x -o -l<id> dir/<file>` |
| `shot_pair dir rect` | no | `screencapture -x -R<x,y,w,h> dir/pair.png` |

Each capture writes to `<name>.tmp.png` and renames to the final name only when `screencapture` exits 0 and the file is non-empty. A failed capture removes the temp file, prints `skipped <name>` to stderr, and the step continues (7.8). The four file names are literals, never taken from the manifest or any option (7.9).

### `lib/video.sh`

| Function | Contract |
|---|---|
| `video_start dir backend display` | Starts `screencapture -v -x [-D<n>] dir/flow.mov` or `ffmpeg -f avfoundation -framerate 30 -i "<screen>:none" dir/flow.mp4 </dev/null` in the background, writes its PID to `recorder.pid`, sleeps 1 s, and fails the session if the PID is gone (8.6) |
| `video_stop` | `kill -INT`, wait up to 10 s, check file exists and size > 0, record size and duration in the manifest, mark `failed` otherwise (8.3, 8.7, 8.8) |
| `video_duration file` | `osascript -l JavaScript` with `AVFoundation` `AVURLAsset.duration`. Used instead of `mdls` because Spotlight does not index `/Volumes/Gold` |
| `video_playable file` | Exit 0 when `video_duration` returns a value above 0 |

For ffmpeg, the screen device index comes from `ffmpeg -f avfoundation -list_devices true -i ""` by taking the device named `Capture screen <display-1>`. A missing `ffmpeg` is detected by `command -v` before anything else starts (8.5).

### `lib/ward.sh`

| Function | Contract |
|---|---|
| `ward_pids` | `pgrep -f GatekeepersWard.app/Contents/MacOS/GatekeepersWardApp` |
| `ward_ensure` | Baseline: fail with the PID if any exists (9.2). Ward: if running, reuse and write no Marker_File (9.6). Otherwise run `scripts/run_ward.sh`, take `pgrep -n`, write the Marker_File, poll `match_ward_item` every 500 ms for 10 s (9.4, 9.5), and on timeout stop the process it started, delete the Marker_File, and exit 1 |
| `ward_stop_if_marked` | Used at the end of a ward session (9.9) and by teardown |

The Ward commit recorded in the manifest is `git -C <repo> rev-parse HEAD`, accepted only when it matches `^[0-9a-f]{40}$`; otherwise `unknown` (11.2). When the framework reuses an already running Ward, the value is the checkout's HEAD and may differ from the running build, and the README says so.

### `lib/app.sh` and `ui.applescript`

Every call is `osascript lib/ui.applescript <verb> <args...>` with the values in argv. Verbs: `launch`, `frontmost`, `focus`, `paste`, `type`, `send`, `approve`, `read-prompt`, `buttons`, `click`.

| Function | Contract |
|---|---|
| `app_launch profile` | Records whether the app was running (`pgrep` by bundle ID through `System Events`). Runs the profile `launch` command if not, adds the bundle ID to `launched.txt` only if it was not already running (2.6), waits for the front window up to `launch_timeout` (5.3) |
| `app_focus_input` | Resolves the locator for up to 5 s. On failure saves a screenshot to the Session_Directory, sends no text, exits 1 naming the locator and the file (5.4) |
| `app_check_paths prompt` | Extracts each `/Volumes/<name>` token from the Prompt_Message and requires `[ -d ]` plus a Finder check that the disk exists, before any text is sent (5.5, 5.6) |
| `app_send prompt method` | `clipboard`: snapshot the pasteboard, set it to the prompt, `cmd+v`, restore within 2 s, and restore in the failure path as well (5.9). `keystroke`: `keystroke (item 1 of argv)` |
| `app_approve spec` | Optional `approve_tool_call` step, 30 s limit (5.7, 5.8) |

Clipboard snapshot: `clipboard.js snapshot <file>` writes every pasteboard item and type (`NSPasteboard.pasteboardItems`, `dataForType`) as a keyed archive, and `restore <file>` writes them back. A plain-text copy through `pbcopy` would lose images and rich text. The snapshot file lets `cleanup_all` restore the clipboard even after a crash.

### `lib/resolve.sh`

| Function | Contract |
|---|---|
| `resolve_prompt choice` | `none` prints a notice and returns. For `allow` or `deny`, lists the buttons of the prompt window through `ui.applescript buttons`, picks the first button whose normalized label (lower case, curly apostrophe turned into a straight one) is in the label list for that choice, clicks it, then polls `windows.js list` every 500 ms for 5 s for the prompt to disappear. Records `dismissed` or `still present` |

Label lists live in `services.tbl` and are overridable with `CAPTURE_ALLOW_LABELS` and `CAPTURE_DENY_LABELS`. Defaults: allow = `ok,allow`, deny = `don't allow,deny`. These are the labels known for folder and removable-volume prompts. They have not been verified on 27.2.1, so a lookup miss saves a screenshot of the prompt, reports every button found, records the failure in the manifest, and exits 1 (10.4).

### `services.tbl`

One row per TCC service key the profiles use: `service<TAB>keyword1,keyword2`. Examples: `SystemPolicyDesktopFolder<TAB>desktop`, `SystemPolicyDocumentsFolder<TAB>documents`, `SystemPolicyDownloadsFolder<TAB>downloads`, `SystemPolicyRemovableVolumes<TAB>removable volume`. `classify_prompt text service` is pure: it returns `unknown` when the text is empty or the service is not in the table, `true` when the lowercased text contains any keyword, and `false` otherwise (6.7). The text itself comes from the static text elements of the prompt window through System Events, which works because the Capture_Host holds Accessibility.

### `lib/setup.sh`

| Function | Contract |
|---|---|
| `perm_status name` | Runs `swift permcheck.swift status <name>` and prints `granted` or `missing`. Names: `accessibility`, `screen-recording`, `automation-system-events`, `automation-finder`. Never prompts |
| `perm_request name` | Runs `permcheck.swift request <name>` and opens the matching Settings pane with `open "x-apple.systempreferences:com.apple.preference.security?Privacy_<Pane>"` within 5 s of detection (1.2) |
| `setup_state_merge old new` | Pure. For each permission keeps the old `already_granted` value when the old file has it, otherwise takes the new one (1.3) |
| `cmd_setup` | Prints exactly four lines (`<name>: granted\|missing`), requests what is missing, re-checks after the user confirms, writes the state file, exits 0 only when all four are granted |
| `cmd_doctor` | Four permission lines, one each for `osascript`, `screencapture`, `tccutil`, `ffmpeg` (only when `--video-backend ffmpeg` is selected), and the macOS version line. Calls only `perm_status` and `command -v`. Exits 1 if a required tool is missing, after printing every line |

The Settings pane names are `Privacy_Accessibility`, `Privacy_ScreenCapture`, and `Privacy_Automation`. The Setup_State_File is removed only by the user.

### `lib/focus.sh` (`--redact-notifications`)

`focus_enable` reads the current Focus state, saves it to `captures/.state/focus-state`, and turns Do Not Disturb on. `focus_restore` puts the saved state back. Both run through `focus.applescript`, which drives the Control Center Focus control with System Events. There is no public API for Focus, and reading `~/Library/DoNotDisturb` needs Full Disk Access. The script is therefore fragile across macOS releases. If the state cannot be read or set, the command fails before the first Scenario with a message (fail closed), since the user explicitly asked for redaction. Restore runs from the normal end path, the error path, and `cleanup_all` (13.8, 13.9).

### `lib/export.sh`

`export <dir>` finds `captures/**/*.png` and `captures/**/flow.*`, creates `<dir>` if needed, and copies each file with `cp -p`. The destination name is `<ts>__<profile>__<scenario>__<mode>__<file>` so files from different sessions do not collide. It exits 1 with a distinct message for "nothing to copy" and for "destination not writable" (11.10, 11.11).

## Data Models

### Profile (parsed)

```
Profile {
  profile_id: kebab-case string, equals file name stem
  display_name, bundle_id, launch, input_locator, send_action: non-empty strings
  send_method: "clipboard" | "keystroke"      (default clipboard)
  launch_timeout: int 1..300                  (default 20)
  approve_tool_call: string | absent
  scenarios: [Scenario]  (1..20, declared order)
}
Scenario {
  name: [a-z0-9-]+
  prompt: string, 1..2000 chars
  service: non-empty TCC service key
  prompt_timeout: int 1..300  (default 45)
  dwell: int 1..60            (default 4)
}
```

### Manifest (`manifest.json`)

```json
{
  "profile_id": "zcode",
  "bundle_id": "dev.zcode.app",
  "scenario": "desktop",
  "mode": "ward",
  "started_at": "2026-11-20T15:30:45Z",
  "ended_at": "2026-11-20T15:31:40Z",
  "macos_version": "27.2.1",
  "artifacts": ["screen.png", "prompt.png", "hud.png", "pair.png", "flow.mov", "capture.log"],
  "outcome": "ok",
  "ward_commit": "0123456789abcdef0123456789abcdef01234567",
  "prompt": {
    "detected_at": "2026-11-20T15:30:58.412Z",
    "bounds": {"x": 640, "y": 220, "w": 260, "h": 282},
    "service_match": true,
    "resolution": "dismissed"
  },
  "hud": {"detected_at": "2026-11-20T15:30:58.901Z", "bounds": {"x": 910, "y": 220, "w": 400, "h": 410}},
  "video": {"status": "ok", "bytes": 1843201, "duration_s": 12.4},
  "reset_failed": false,
  "failed_step": null,
  "error": null
}
```

Rules enforced by `manifest_check`:

- `outcome` is exactly one of `ok`, `no_prompt`, `no_hud`, `error`.
- `artifacts` has 0 to 50 entries, each a plain relative file name with no `/`.
- `ward_commit` appears only when `mode` is `ward`, and is 40 lowercase hex characters or `unknown`.
- `failed_step` and `error` are set exactly when `outcome != ok`, and `error` is 1 to 1,000 characters.
- `service_match` is `true`, `false`, or the string `"unknown"`.
- Timestamps are UTC ISO-8601 (`...Z`). Detection times carry milliseconds.
- `resolution` is `dismissed`, `still present`, `skipped` (`--resolve none`), or `failed`.

### Setup_State_File (`captures/.state/setup.json`)

```json
{"accessibility": {"already_granted": true}, "screen-recording": {"already_granted": false},
 "automation-system-events": {"already_granted": true}, "automation-finder": {"already_granted": true}}
```

### Other state files

| File | Content |
|---|---|
| `ward.pid` | PID of the Ward the framework started (the Marker_File). Absent when Ward was already running |
| `recorder.pid` | PID of the running `screencapture` or `ffmpeg` |
| `launched.txt` | Bundle IDs the framework launched, one per line |
| `focus-state` | `on` or `off`, the Focus state before the session |
| `clipboard.snap` | Keyed archive of the clipboard before a paste |

### Session artifacts

```
captures/<ts>/<profile>/<scenario>/baseline/{capture.log, manifest.json, screen.png, prompt.png, flow.mov}
captures/<ts>/<profile>/<scenario>/ward/{capture.log, manifest.json, screen.png, prompt.png, hud.png, pair.png, flow.mov}
captures/<ts>/<profile>/<scenario>/summary.md
```

### Permissions per subcommand

| Subcommand | Accessibility | Screen Recording | Automation (System Events) | Automation (Finder) |
|---|---|---|---|---|
| `setup`, `doctor` | checks | checks | checks | checks |
| `reset`, `list`, `teardown`, `export` | no | no | no | no |
| `prompt`, `run` | yes (typing, clicking, reading the prompt) | yes (`screencapture`) | yes | yes (disk check) |
| window list polling | no | no | no | no |

### Open items carried into implementation

- The prompt owner and layer, and the Allow/Deny button labels, are verified only on macOS 27.0.1 (owner, layer) or not at all (labels). The first implementation task runs `dump_window_list.swift` with a live WardTrigger prompt on 27.2.1 and updates the defaults and `services.tbl`.
- The Ward menu bar item layer (24 or higher) is inferred. The same task records the measured value.
- The Focus toggle depends on Control Center UI structure and is the least reliable component. It is isolated in `focus.applescript` so a macOS change touches one file.
- ZCode and DeepSeek Harness input locators and send actions cannot be known without inspecting each app's accessibility tree with Accessibility Inspector. The shipped profiles carry best-effort values and the README documents how to re-derive them.


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Profile round trip

*For any* valid App_Profile (1 to 20 scenarios, prompts of 1 to 2,000 characters including punctuation, quotes, backslashes, `$`, and backticks, optional fields present or absent), writing it in profile format and parsing it with `profile_parse` yields the same fields and the same scenario order. `capture.sh list` then prints that profile's ID, its bundle ID, and exactly its scenario names.

**Validates: Requirements 4.2, 4.3**

### Property 2: Profile loading ignores non-profile files

*For any* directory containing files with arbitrary names, `profile_load_all` loads exactly the files whose names end in `.profile`, and the set of loaded profile IDs equals the set of those file-name stems. Adding one more valid `*.profile` file adds exactly one entry to `capture.sh list` and changes no other output.

**Validates: Requirements 4.1, 4.5, 4.9**

### Property 3: Incomplete profiles are rejected by field name

*For any* valid App_Profile and any required field, removing that field or setting it to the empty string makes `profile_validate` fail, and the message contains both the profile file path and the field name. No Scenario of that profile is runnable.

**Validates: Requirements 4.6**

### Property 4: Profile ID must match file name

*For any* valid App_Profile written to a file whose name stem differs from its declared `profile_id`, validation fails and the message contains both the declared ID and the file name. When the two are equal, validation does not fail for that reason.

**Validates: Requirements 4.7**

### Property 5: Bundle-ID guard

*For any* string `id` and any set of loaded bundle IDs, `guard_bundle_id` accepts `id` if and only if `id` is non-empty, is not `All` in any combination of letter case, and is a member of the loaded set. On rejection the message contains `id`, and no `tccutil` command is run.

**Validates: Requirements 3.2, 13.2, 13.3**

### Property 6: Reset plan is scoped to one bundle and the profile's services

*For any* App_Profile and any `--service` argument: when no service is given, `reset_plan` returns one `tccutil reset <service> <bundle_id>` command per distinct profile service, in declaration order, each with the profile's own bundle ID. When a service in the profile is given, it returns exactly one command for that service. When the service is not in the profile, it returns an error naming the service and the valid services, and zero commands. The same function supplies the session-start and session-end resets, so those resets cover only the Scenario's service and no other service or bundle.

**Validates: Requirements 3.1, 3.3, 3.4, 3.8, 10.7**

### Property 7: Argument quoting is lossless

*For any* string made of arbitrary characters (quotes, backslashes, spaces, `$`, backticks, semicolons, newlines, Unicode, but not NUL), `quote_cmd` of a command that includes the string, evaluated by bash, yields an argv whose corresponding element equals the original string, and no extra command runs. When the same string is the Prompt_Message sent through the `prompt-send` step with a stub `osascript`, the stub records it as exactly one argv element equal to the original.

**Validates: Requirements 13.10**

### Property 8: Session path structure

*For any* run timestamp, profile ID, and scenario name, `session_path` returns `captures/<timestamp>/<profile>/<scenario>/<mode>`. For the same inputs, the `baseline` path and the `ward` path are identical except for the final segment, which is `baseline` for one and `ward` for the other.

**Validates: Requirements 11.3, 9.10**

### Property 9: Existing Session_Directory is never modified

*For any* existing directory at the target Session_Directory path, with any content, `session_create` fails with a message naming the path, and the directory's file list, contents, and modification times are the same afterward.

**Validates: Requirements 11.4**

### Property 10: Manifest validity

*For any* generated manifest, `manifest_check` accepts it if and only if: `outcome` is one of `ok`, `no_prompt`, `no_hud`, `error`; the artifact list has 0 to 50 relative names; timestamps are UTC ISO-8601; `ward_commit` is present only in `ward` mode and is 40 lowercase hex characters or `unknown`; and `failed_step` and `error` are set exactly when `outcome` is not `ok`, with `error` 1 to 1,000 characters. Truncating a longer error text to 1,000 characters produces a text that passes.

**Validates: Requirements 11.1, 11.2, 11.5**

### Property 11: Manifest JSON round trip

*For any* manifest written by `manifest_write` (including strings with quotes, backslashes, control characters, and Unicode in `error`), parsing `manifest.json` and re-serializing it with `json.js reserialize` yields a document with equal keys and values.

**Validates: Requirements 11.8**

### Property 12: Option validators

*For any* string `v`: `valid_resolve` accepts `v` if and only if `v` is `allow`, `deny`, or `none`. `valid_range v lo hi` accepts `v` if and only if `v` is an unsigned decimal integer in `[lo, hi]`, for the ranges launch timeout 1 to 300, prompt timeout 1 to 300, and dwell 1 to 60. For any integer `idx` and display count `n`, `valid_display` accepts if and only if `1 <= idx <= n`. When an option is absent, `with_default` returns the documented default (launch 20, prompt 45, dwell 4, resolve `deny`, display main). A rejected value produces an error naming the value and leaves no image file and no clicked button.

**Validates: Requirements 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3**

### Property 13: Prompt window matching

*For any* ordered list of window rows, `match_prompt` returns the first row whose owner equals the configured owner, whose layer equals the configured layer, and whose width and height are both positive, and returns nothing if no row qualifies. Rows that differ in owner, layer, or size never match. Adding non-matching rows before or after a match does not change the result.

**Validates: Requirements 6.1**

### Property 14: HUD and menu bar item matching

*For any* ordered list of window rows, `match_hud` returns the first row with owner `GatekeepersWardApp`, layer 3, alpha above 0.9, and width within 2 points of 400. `match_ward_item` returns the first row with owner `GatekeepersWardApp` and layer at or above 24. A HUD-shaped row with alpha 0.9 or less, or with a different width, is never returned by `match_hud`.

**Validates: Requirements 6.4, 9.4**

### Property 15: Prompt text classification

*For any* prompt text and TCC service key, `classify_prompt` returns `unknown` when the text is empty or the service is not in `services.tbl`, `true` when the lower-cased text contains one of the service's keywords, and `false` otherwise. The result does not depend on letter case of the text.

**Validates: Requirements 6.7**

### Property 16: Pair crop rectangle

*For any* two window rectangles and any display rectangle that contains at least part of each, `crop_rect` with margin 24 returns a rectangle that lies inside the display, contains the part of each window that lies inside the display, and, whenever the 24-point expansion of the windows' union lies inside the display, equals that expanded union exactly (the smallest rectangle). Swapping the two windows gives the same result.

**Validates: Requirements 7.4**

### Property 17: Removable-volume path extraction

*For any* Prompt_Message built from arbitrary text and zero or more `/Volumes/<name>` paths (names with spaces and punctuation), the path extractor returns exactly the embedded volume paths in order. When the list is non-empty and any path is missing, the pre-send check fails and the stub `osascript` records no send. When the list is empty, the check passes.

**Validates: Requirements 5.5, 5.6**

### Property 18: Button selection

*For any* list of button labels and a resolve choice, `pick_button` returns the first label whose normalized form (lower case, curly apostrophe replaced by a straight one) is in the label list for that choice, or reports not-found together with the full list of labels it saw. The choice `allow` never returns a label from the deny list, and `deny` never returns one from the allow list.

**Validates: Requirements 10.1, 10.4**

### Property 19: Session planning order

*For any* set of loaded profiles, scenario names, and options, `plan_sessions` returns the rows in this order: profiles in name order, scenarios in declared order (when `--all-scenarios` is set, otherwise the single named scenario), and within a pair `baseline` before `ward` when no `--mode` is given, or only the given mode. With `--all-profiles`, every profile that declares the scenario appears, and every profile that does not is named on stderr as skipped and appears in no row.

**Validates: Requirements 9.7, 12.3, 12.4**

### Property 20: Failure policy

*For any* sequence of session outcomes and any `--keep-going` setting: without `--keep-going`, no row starts after an `error` outcome. With `--keep-going`, rows keep starting after an error, except that the `ward` row of a pair never starts when the `baseline` row of the same pair failed. The final exit code is 0 if and only if every executed row ended `ok`, and every planned row not skipped by these rules is executed.

**Validates: Requirements 9.8, 12.6**

### Property 21: Unknown profile or scenario creates nothing

*For any* profile name or scenario name that is not declared in the loaded profiles, `capture.sh run` exits non-zero before any step, prints a message naming the unknown value, and the `captures/` tree is unchanged.

**Validates: Requirements 12.2**

### Property 22: Preflight reports every failure

*For any* subset of the three preflight conditions (permissions present, target app installed, display awake and unlocked) set to fail by stubs, the preflight step runs all three checks, prints a message naming exactly the failed ones, exits non-zero when the subset is non-empty, and runs no later step. For the empty subset it passes.

**Validates: Requirements 12.7, 12.8**

### Property 23: Step log line

*For any* step name, `log_step` prints a line that contains the step name and a UTC timestamp with at least one-second resolution, and the line appended to `capture.log` is identical to the printed line.

**Validates: Requirements 12.9**

### Property 24: Dry-run has no effects

*For any* valid profile, scenario, mode, and option combination, `run --dry-run` (and `reset --dry-run`) exits 0, prints the twelve step names in the fixed order together with the quoted text of each external command, calls no stub binary (the stub call log is empty), and leaves the file tree and file contents of the working directory exactly as they were, including `captures/`.

**Validates: Requirements 3.7, 12.1, 14.5, 14.6**

### Property 25: Setup state is never overwritten

*For any* previously recorded Setup_State_File and any newly observed set of permission states, `setup_state_merge` keeps every previously recorded `already_granted` value unchanged, and fills in only the permissions that were not recorded. Merging the same observation twice gives the same result as merging it once.

**Validates: Requirements 1.3**

### Property 26: Teardown revoke guidance

*For any* Setup_State_File, `teardown` prints one line for each permission recorded with `already_granted: false`, each line containing the permission name and its System Settings pane, and prints no line for a permission recorded as already granted.

**Validates: Requirements 2.4**

### Property 27: Summary links match manifests

*For any* pair of manifests (`baseline` and `ward`) with artifact lists of 0 to 50 names, `write_summary` produces a `summary.md` that contains exactly one link per artifact name in each manifest, each pointing to the relative path `baseline/<name>` or `ward/<name>`. When only one manifest exists, no `summary.md` is written.

**Validates: Requirements 11.6, 11.7**

### Property 28: Export copies the selected files and nothing else

*For any* set of files under `captures/` with arbitrary names and contents, `export <dir>` copies exactly the files that match `*.png` or `flow.*`, each with identical bytes, creates `<dir>` when it is absent, and leaves every source file unchanged. When no file matches, it exits non-zero and creates no files.

**Validates: Requirements 11.10, 11.11**

## Error Handling

| Condition | Behavior | Requirement |
|---|---|---|
| Profile file malformed, field missing, ID mismatch | Print path and field or both names, exit 2, run nothing | 4.6, 4.7 |
| Unknown profile, scenario, `--resolve`, `--display`, `--service`, `--video-backend` | Print the value and the accepted values, exit 2 before any step | 3.4, 7.6, 10.3, 12.2 |
| `tccutil` target not in loaded profiles, empty, or `All` | Skip, print the rejected value, exit non-zero before running any `tccutil` | 3.2, 13.3 |
| Preflight failure | Run all three checks, name every failure, no later step | 12.8 |
| Existing Session_Directory | Abort, leave it untouched | 11.4 |
| Baseline with Ward running | Stop before any artifact is written, print the PID | 9.2 |
| Ward menu bar item missing after 10 s | Stop the Ward the framework started, delete the Marker_File, exit 1 | 9.5 |
| Video backend missing or exits within 1 s | Exit 1 before any prompt text is sent | 8.5, 8.6 |
| Launch timeout, locator not found, path missing, approve timeout | Exit 1 with the named reason. A locator failure saves a screenshot and sends no text | 5.3 to 5.8 |
| No prompt, no HUD | Save a full-screen screenshot, mark the manifest `no_prompt` or `no_hud`, keep earlier files, exit 1 | 6.3, 6.6 |
| One image fails | Skip that image, print its name, remove any partial file, continue | 7.8 |
| Button not found | Screenshot, list the buttons found, manifest failure, exit 1 | 10.4 |
| Prompt not dismissed in 5 s | Exit 1, still run the end-of-session reset | 10.6 |
| End-of-session reset fails | Warning naming the service and the manual command, manifest field, exit non-zero | 10.8 |
| Any step fails | `cleanup_all`, write an `error` manifest naming the step, stop (or continue with `--keep-going`) | 12.5, 12.6 |
| `SIGINT` / `SIGTERM` | Same cleanup as `teardown`, exit 130 or 143 | 2.10 |
| Stale Marker_File (process gone) | Skip termination, delete the file, continue | 2.3 |
| Target app ignores quit for 10 s | Report the app name, continue, never force-kill | 2.7 |
| Partial video on teardown | Verify it plays, otherwise print the path and a warning | 2.5 |
| Focus state cannot be read or set with `--redact-notifications` | Fail before the first Scenario | 13.7 |

Cleanup is written to be idempotent and to continue after an individual action fails, so one broken step cannot leave the Ward running or the clipboard changed.

## Testing Strategy

### Dual approach

- **Property tests** cover the 28 properties above. Each runs the function under test through a bash subprocess, with generated inputs.
- **Example tests** cover specific scenarios and error cases: setup and doctor output, teardown actions with a dummy process, the ordering of steps with stub binaries, a failing image capture, clipboard restore on failure, `--no-video` and `--no-images`, ffmpeg errors, Ward reuse, shipped profile contents, README headings, and static scans for `TCC.db`, `curl`, `nc`, and non-bash/osascript tooling.
- **Manual integration run** (not automated): `capture.sh setup`, then `run zcode desktop` and `run deepseek-harness removable-volume` on a Mac with the apps installed, checking the artifacts. It covers the UI-driving, screen capture, resolve click, and Focus behavior that no stub can cover. This is also where the open items in the Data Models section are settled.

### Property-based testing setup

- **Library:** Hypothesis 6.170.15 with pytest 8.4.2, both already pinned in `.kiro/tools/requirements.txt`. Tests run as `.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests`. No property-based testing code is written from scratch.
- **Iterations:** each property test uses `@settings(max_examples=100)` or more. Properties that spawn a subprocess per example (7, 9, 21, 22, 24, 28) use 100, with `deadline=None`. Pure-function properties through one batched subprocess use 200 or more.
- **Tagging:** each property test carries a comment in this form, and implements one property in one test:

  `# Feature: permission-capture-framework, Property 5: Bundle-ID guard`

- **Harness (`conftest.py`):**
  - Runs bash functions with `bash -c 'source lib/<file>.sh; <function> "$@"' _ args...`, so every generated value is passed as an argument, never interpolated.
  - Builds a temporary copy of the repo's `scripts/capture/` and a scratch `captures/` root for each test, and puts `tests/stubs/` first on `PATH`. Each stub appends its argv to a call log and returns canned output.
  - Provides Hypothesis strategies: kebab-case IDs, bundle IDs, prompt text (printable plus the special characters in Property 1 and 7), window rows, rectangles, button label lists, manifests, and file name sets.
- **Permissions:** no test needs Accessibility, Screen Recording, or Automation, because every external call is a stub. A test that would need a real permission is marked `@pytest.mark.skipif` with a reason such as `requires Screen Recording grant`, so it is reported as skipped and never as failed.
- **Pre-commit:** `scripts/git-hooks/pre-commit` runs `swift build` and `swift test --skip integration`. The capture tests are fast and have no Swift dependency, so a second line there runs them when `.kiro/tools/.venv` exists. That edit is part of the implementation tasks, not this design.

### Scope and reflection

Testing with generated inputs applies to the pure functions in `lib/` (parsing, validation, planning, path building, geometry, window matching, JSON checks) and to a few stub-driven command runs. It does not apply to screen capture, UI scripting, permission prompts, Focus toggling, or timing limits. Those are covered by example tests and the manual run described in the Testing Strategy.

**Reflection.** The prework produced about 60 testable criteria. These were merged where one property implies the others:

- 3.1, 3.3, 3.4, 3.8, and 10.7 all describe which `tccutil` commands may be planned, so they become one reset-plan property.
- 3.2, 13.2, and 13.3 all describe the bundle-ID guard, so they become one property.
- 9.10 is implied by 11.3 (the path function builds both modes), so they become one property.
- 11.1, 11.2, and 11.5 describe what a valid manifest looks like and become the manifest-validity property. 11.8 is a different claim (round trip) and stays separate.
- 3.7 and 14.5 and 14.6 all say that dry-run has no side effects, so they become one dry-run property.
- 7.5, 7.6, 8.2, 10.1, 10.3, 5.3, and 6.3 all validate option values and become one validator property.
- 4.2, 4.3, and 4.6 are covered by a profile round trip plus a rejection property. 4.7 stays separate because the failure condition differs.

### Property-based testing exclusions

Property tests are not used for screen capture, video recording, UI scripting, permission prompts, Focus toggling, window-server timing, or the `tccutil` command itself. These depend on external services and on timing, so repeated runs would not find more bugs than a few examples. The pure logic around them (matching, planning, geometry, validation) is covered by properties instead.
