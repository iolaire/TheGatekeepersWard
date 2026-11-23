# Implementation Plan: Permission Capture Framework

## Overview

The framework is implemented in bash (bash 3.2 compatible) under `scripts/capture/`, with small JXA, AppleScript, and Swift helpers. Pure decision logic goes into `lib/*.sh` first, together with its property tests (pytest + Hypothesis, run from `.kiro/tools/.venv`), then the side-effecting drivers (video, Ward, target app, resolve, Focus), then the `run` orchestration that wires every step together. All external calls in tests go through stub binaries, so no test needs Accessibility, Screen Recording, or Automation grants.

Test files are named per task so tasks in the same wave never write the same file.

## Tasks

- [x] 1. Re-measure the TCC dialog window owner and layer on this macOS
  - Run `scripts/dump_window_list.swift` on this Mac (macOS 27.2.1, build 26B131) while a real TCC prompt is showing, for example one raised by WardTrigger
  - Record the measured window owner, layer, and size of the TCC prompt, and the Ward menu bar item layer if Ward is running
  - Record the Allow and Deny button labels seen on the prompt for folder and removable-volume services
  - Create `scripts/capture/lib/defaults.sh` that defines `CAPTURE_PROMPT_OWNER`, `CAPTURE_PROMPT_LAYER`, the Ward menu bar minimum layer, and the allow and deny label lists, each overridable by an environment variable of the same name
  - Add a short entry to `docs/devlog.md` with the measured values and the macOS build, following the existing heading format
  - If a measurement cannot be taken, keep the design defaults (`UserNotificationCenter`, layer 8, menu bar layer 24 or higher) and note that in the devlog entry
  - _Requirements: 6.1, 9.4, 10.4_

- [x] 2. Set up the framework skeleton and test harness
  - [x] 2.1 Create `lib/common.sh` and the `capture.sh` dispatcher
    - Implement `ext`, `quote_cmd`, `log_step`, `die`, `utc_now_ms`, and the exit-code constants
    - Create `capture.sh` with subcommand dispatch, global option parsing, `--dry-run` handling, and the personal-data notice printed before any Scenario
    - Add `captures/` to `.gitignore`
    - _Requirements: 11.9, 12.9, 13.6, 13.10, 14.5, 14.8_

  - [x] 2.2 Create the Python test harness and stub binaries
    - Create `tests/conftest.py` with the bash function runner (values passed as arguments), the temporary repo copy, and Hypothesis strategies for IDs, prompt text, window rows, rectangles, button labels, manifests, and file names
    - Create stub `tccutil`, `osascript`, `screencapture`, `pgrep`, and `open` in `tests/stubs/` that log argv to a call log and return canned output
    - Add a skip helper that marks a test skipped with a reason when a macOS permission is required
    - _Requirements: 14.3, 14.4_

  - [x] 2.3 Write property test for argument quoting
    - **Property 7: Argument quoting is lossless**
    - **Validates: Requirements 13.10**
    - File: `tests/test_quoting.py`

  - [x] 2.4 Write property test for the step log line
    - **Property 23: Step log line**
    - **Validates: Requirements 12.9**
    - File: `tests/test_log_step.py`

- [x] 3. Implement option validators
  - [x] 3.1 Create `lib/validate.sh`
    - Implement `valid_resolve`, `valid_display`, `valid_range`, and `with_default` with the documented defaults (launch 20, prompt 45, dwell 4, resolve `deny`, main display)
    - _Requirements: 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3_

  - [x] 3.2 Write property test for option validators
    - **Property 12: Option validators**
    - **Validates: Requirements 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3**
    - File: `tests/test_validate.py`

- [x] 4. Implement App_Profile loading, validation, and shipped profiles
  - [x] 4.1 Create `lib/profile.sh` and wire `list`
    - Implement `profile_parse` (restricted `key = value` parser that never sources the file), `profile_validate`, `profile_load_all`, `profile_services`, and `profile_scenarios`
    - Validate required fields, 1 to 20 scenarios, prompt length 1 to 2,000, numeric ranges, and that `profile_id` equals the file name stem
    - Wire `capture.sh list`, including the `no profiles found` exit 1 case
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [x] 4.2 Add the shipped profiles and template
    - Create `profiles/zcode.profile` (bundle ID `dev.zcode.app`) and `profiles/deepseek-harness.profile` (bundle ID `com.deepseek.dsh`), each with at least the `desktop` and `removable-volume` Scenarios and read-only list-directory prompts
    - Create `profiles/_template.profile.example` with a comment for each required field
    - _Requirements: 4.8, 4.9, 4.10, 13.5_

  - [x] 4.3 Write property test for profile round trip
    - **Property 1: Profile round trip**
    - **Validates: Requirements 4.2, 4.3**
    - File: `tests/test_profile_roundtrip.py`

  - [x] 4.4 Write property test for profile loading
    - **Property 2: Profile loading ignores non-profile files**
    - **Validates: Requirements 4.1, 4.5, 4.9**
    - File: `tests/test_profile_loading.py`

  - [x] 4.5 Write property test for incomplete profiles
    - **Property 3: Incomplete profiles are rejected by field name**
    - **Validates: Requirements 4.6**
    - File: `tests/test_profile_fields.py`

  - [x] 4.6 Write property test for profile ID and file name match
    - **Property 4: Profile ID must match file name**
    - **Validates: Requirements 4.7**
    - File: `tests/test_profile_id.py`

- [x] 5. Implement the scoped permission reset
  - [x] 5.1 Create `lib/reset.sh` and wire `reset`
    - Implement `guard_bundle_id`, `reset_plan`, and `reset_run` with `--service` and `--dry-run`
    - Run the guard on every planned command before running any `tccutil` command, print each command with its exit code, and continue after a failure
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 13.1, 13.2, 13.3_

  - [x] 5.2 Write property test for the bundle-ID guard
    - **Property 5: Bundle-ID guard**
    - **Validates: Requirements 3.2, 13.2, 13.3**
    - File: `tests/test_reset_guard.py`

  - [x] 5.3 Write property test for the reset plan
    - **Property 6: Reset plan is scoped to one bundle and the profile's services**
    - **Validates: Requirements 3.1, 3.3, 3.4, 3.8, 10.7**
    - File: `tests/test_reset_plan.py`

- [x] 6. Implement the manifest and Session_Directory logic
  - [x] 6.1 Create `lib/json.js` and `lib/manifest.sh`
    - Implement `manifest_set`, `manifest_add_artifact`, `manifest_write`, `manifest_check`, and `manifest_roundtrip`, building JSON through `osascript -l JavaScript`
    - Enforce the outcome enum, 0 to 50 relative artifact names, UTC timestamps, the ward commit format, and the failure fields
    - _Requirements: 11.1, 11.2, 11.5, 11.8_

  - [x] 6.2 Create `lib/session.sh` path and directory functions
    - Implement `run_timestamp`, `session_path`, and `session_create` (plain `mkdir` on the last segment, leaving an existing directory untouched)
    - _Requirements: 9.10, 11.3, 11.4_

  - [x] 6.3 Write property test for session paths
    - **Property 8: Session path structure**
    - **Validates: Requirements 11.3, 9.10**
    - File: `tests/test_session_path.py`

  - [x] 6.4 Write property test for existing Session_Directory safety
    - **Property 9: Existing Session_Directory is never modified**
    - **Validates: Requirements 11.4**
    - File: `tests/test_session_exists.py`

  - [x] 6.5 Write property test for manifest validity
    - **Property 10: Manifest validity**
    - **Validates: Requirements 11.1, 11.2, 11.5**
    - File: `tests/test_manifest_check.py`

  - [x] 6.6 Write property test for manifest JSON round trip
    - **Property 11: Manifest JSON round trip**
    - **Validates: Requirements 11.8**
    - File: `tests/test_manifest_roundtrip.py`

- [x] 7. Implement window matching, prompt classification, and screenshot geometry
  - [x] 7.1 Create `lib/windows.js`, `lib/windows.sh`, and `lib/services.tbl`
    - Implement the JXA window and display lists, `match_prompt`, `match_hud`, `match_ward_item`, `poll_window`, and `classify_prompt`
    - Read the prompt owner, layer, and menu bar layer from `lib/defaults.sh` (task 1)
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 6.7, 9.4_

  - [x] 7.2 Create `lib/shots.sh`
    - Implement `crop_rect`, `shot_screen`, `shot_window`, and `shot_pair`
    - Write to a temporary name, rename only on success, remove partial files, and use the literal names `screen.png`, `prompt.png`, `hud.png`, and `pair.png`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

  - [x] 7.3 Write property test for prompt window matching
    - **Property 13: Prompt window matching**
    - **Validates: Requirements 6.1**
    - File: `tests/test_match_prompt.py`

  - [x] 7.4 Write property test for HUD and menu bar item matching
    - **Property 14: HUD and menu bar item matching**
    - **Validates: Requirements 6.4, 9.4**
    - File: `tests/test_match_hud.py`

  - [x] 7.5 Write property test for prompt text classification
    - **Property 15: Prompt text classification**
    - **Validates: Requirements 6.7**
    - File: `tests/test_classify_prompt.py`

  - [x] 7.6 Write property test for the pair crop rectangle
    - **Property 16: Pair crop rectangle**
    - **Validates: Requirements 7.4**
    - File: `tests/test_crop_rect.py`

- [x] 8. Implement session planning and the failure policy
  - [x] 8.1 Create `lib/plan.sh`
    - Implement `plan_sessions` (profiles in name order, scenarios in declared order, `baseline` before `ward`, skipped profiles named on stderr), `plan_continue`, and `plan_exit_code`
    - _Requirements: 9.7, 9.8, 12.3, 12.4, 12.6_

  - [x] 8.2 Write property test for planning order
    - **Property 19: Session planning order**
    - **Validates: Requirements 9.7, 12.3, 12.4**
    - File: `tests/test_plan_order.py`

  - [x] 8.3 Write property test for the failure policy
    - **Property 20: Failure policy**
    - **Validates: Requirements 9.8, 12.6**
    - File: `tests/test_plan_failure.py`

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Implement setup, doctor, and teardown
  - [x] 10.1 Create `lib/permcheck.swift`, `lib/setup.sh`, and wire `setup` and `doctor`
    - Implement `perm_status`, `perm_request` (opens the System Settings pane within 5 s), `setup_state_merge`, `cmd_setup`, and `cmd_doctor`
    - `doctor` stays read-only: no permission request and no Setup_State_File write
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [x] 10.2 Create `lib/cleanup.sh` and wire `teardown` and signal traps
    - Implement idempotent `cleanup_all` (clipboard restore, recorder stop and playability check, Ward stop with `SIGKILL` fallback, quit of apps the framework launched, Focus restore, revoke guidance) and the `INT`/`TERM`/`EXIT` traps with exit 130 and 143
    - Use the helper functions from tasks 11.1 to 11.5 through guarded calls so cleanup works from a fresh shell
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [x] 10.3 Write property test for setup state merge
    - **Property 25: Setup state is never overwritten**
    - **Validates: Requirements 1.3**
    - File: `tests/test_setup_state.py`

  - [x] 10.4 Write property test for teardown revoke guidance
    - **Property 26: Teardown revoke guidance**
    - **Validates: Requirements 2.4**
    - File: `tests/test_teardown_guidance.py`

  - [x] 10.5 Write unit tests for setup, doctor, and teardown
    - Cover four status lines, exit codes, doctor tool lines and read-only behavior, teardown with a dummy process, a stale Marker_File, and the nothing-to-tear-down message
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 2.9_
    - File: `tests/test_setup_teardown.py`

- [x] 11. Implement the side-effecting drivers
  - [x] 11.1 Create `lib/video.sh`
    - Implement `video_start`, `video_stop`, `video_duration`, and `video_playable` for `screencapture -v` and the `ffmpeg` backend, with the 1 second liveness check and the 10 second finalize wait
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10_

  - [x] 11.2 Create `lib/ward.sh`
    - Implement `ward_pids`, `ward_ensure` (baseline refusal, reuse without Marker_File, start through `scripts/run_ward.sh`, 10 second menu bar wait), and `ward_stop_if_marked`
    - Record the Ward commit hash as 40 hex characters or `unknown`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.9, 11.2_

  - [x] 11.3 Create `lib/app.sh`, `lib/ui.applescript`, and `lib/clipboard.js`
    - Implement `app_launch`, `app_focus_input`, `app_check_paths` with the `/Volumes/<name>` extractor, `app_send` (clipboard and keystroke, with clipboard restore on success and failure), and `app_approve`
    - Pass every value to `osascript` as argv, never in script source
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 13.10_

  - [x] 11.4 Create `lib/resolve.sh`
    - Implement `pick_button` and `resolve_prompt` (allow, deny, none), the 5 second dismissal check, and the not-found path that saves a screenshot and lists the buttons found
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 11.5 Create `lib/focus.sh` and `lib/focus.applescript`
    - Implement `focus_enable` and `focus_restore` for `--redact-notifications`, failing closed when the Focus state cannot be read or set
    - _Requirements: 13.7, 13.8, 13.9_

  - [x] 11.6 Write property test for removable-volume path extraction
    - **Property 17: Removable-volume path extraction**
    - **Validates: Requirements 5.5, 5.6**
    - File: `tests/test_volume_paths.py`

  - [x] 11.7 Write property test for button selection
    - **Property 18: Button selection**
    - **Validates: Requirements 10.1, 10.4**
    - File: `tests/test_pick_button.py`

  - [x] 11.8 Write unit tests for the drivers with stubs
    - Cover ffmpeg missing, recorder exiting within 1 second, Ward reuse and baseline refusal, clipboard restore on a failed paste, and `--resolve none`
    - _Requirements: 5.9, 8.5, 8.6, 9.2, 9.6, 10.2_
    - File: `tests/test_drivers.py`

- [x] 12. Wire the run orchestration
  - [x] 12.1 Implement the session step runner and the `prompt` and `run` subcommands
    - Add `run_step`, the preflight check (all three conditions always run), the twelve ordered steps, error cleanup with an `error` Manifest, the `screenshots` ordering (screen and prompt first, then HUD polling and `hud.png` and `pair.png`), the end-of-session scoped reset, and `--keep-going`, `--all-scenarios`, `--all-profiles`, `--no-reset`, `--no-video`, `--no-images`, `--display`, and `--mode`
    - Make `--dry-run` print each step name and the quoted text of each command, create nothing, and call no external binary
    - Reject unknown profiles, scenarios, and option values with exit 2 before any step
    - _Requirements: 3.8, 3.9, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 8.2, 9.7, 9.8, 10.6, 10.7, 10.8, 11.1, 11.5, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 14.5, 14.6_

  - [x] 12.2 Implement `summary.md` and `export`
    - Add `write_summary` to `lib/session.sh` (only when both manifests exist) and create `lib/export.sh` with the `<ts>__<profile>__<scenario>__<mode>__<file>` naming and the two distinct error messages
    - Wire `capture.sh export <dir>` and the summary call at the end of `run`
    - _Requirements: 11.6, 11.7, 11.10, 11.11_

  - [x] 12.3 Write property test for unknown profile or scenario
    - **Property 21: Unknown profile or scenario creates nothing**
    - **Validates: Requirements 12.2**
    - File: `tests/test_unknown_names.py`

  - [x] 12.4 Write property test for preflight
    - **Property 22: Preflight reports every failure**
    - **Validates: Requirements 12.7, 12.8**
    - File: `tests/test_preflight.py`

  - [x] 12.5 Write property test for dry-run
    - **Property 24: Dry-run has no effects**
    - **Validates: Requirements 3.7, 12.1, 14.5, 14.6**
    - File: `tests/test_dryrun.py`

  - [x] 12.6 Write property test for summary links
    - **Property 27: Summary links match manifests**
    - **Validates: Requirements 11.6, 11.7**
    - File: `tests/test_summary.py`

  - [x] 12.7 Write property test for export
    - **Property 28: Export copies the selected files and nothing else**
    - **Validates: Requirements 11.10, 11.11**
    - File: `tests/test_export.py`

  - [x] 12.8 Write unit tests for orchestration and security boundaries
    - Cover step order with stubs, a failing step producing an `error` Manifest and cleanup, a failed screenshot being skipped, a static scan that no script references `TCC.db`, `curl`, or `nc`, and the no-permission-required guarantee of the suite
    - _Requirements: 7.8, 12.1, 12.5, 13.1, 13.4, 14.3, 14.4_
    - File: `tests/test_orchestration.py`

- [x] 13. Documentation and project integration
  - [x] 13.1 Write `scripts/capture/README.md`
    - Add a section for setup, teardown, reset, profile authoring, each subcommand, each option, and the permissions each subcommand needs
    - Add the worked example from creating a new profile to a successful `run --dry-run`, and how to re-derive input locators with Accessibility Inspector
    - Use gender-neutral wording throughout
    - _Requirements: 14.1, 14.2_

  - [x] 13.2 Add the pre-commit test hook line and the devlog entry
    - Add a line to `scripts/git-hooks/pre-commit` that runs `.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests` when the virtualenv exists
    - Add a `docs/devlog.md` entry stating the feature's purpose, with a placeholder list for the assets of the first successful capture, using gender-neutral wording
    - _Requirements: 14.3, 14.7_

- [x] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 15. Measure TCC database behavior on this macOS (temp copy only)
  - Copy the user TCC database to a temporary file under the system temp directory and work only on the copy. Never open or write the real database for writing
  - Record the real `access` table columns on this build (macOS 27.2.1, build 26B131) with `PRAGMA table_info(access)`, and whether any cell holds a real (floating point) value
  - On the copy, run snapshot-style queries and a delete-then-`INSERT OR REPLACE` transaction to confirm `sqlite3` can write a database of this shape. Note that the result for the real file may still differ because of macOS database protection
  - If Full Disk Access allows it, run once against the real database with a real backup: snapshot, `tccutil reset` for a throwaway bundle ID, restore, then check whether `pkill -x -u "$(id -u)" tccd` makes `tccd` reload. If this cannot be done safely, record that it was not measured
  - Add a `docs/devlog.md` entry (UTC heading, gender-neutral wording) with the columns, the write result, the `tccd` reload result, and the macOS build. If a value cannot be measured, say so and keep the design defaults
  - Record whether Full Disk Access must be granted to the Capture_Host and whether it needs a restart of the Capture_Host
  - _Requirements: 15.2, 16.4, 16.7, 16.9, 16.13, 17.1_

- [x] 16. Implement the TCC_Access_Module `lib/tccdb.sh`
  - [x] 16.1 Add TCC test fixtures and stubs
    - Extend `tests/conftest.py` with a fixture that builds a temp SQLite database with the `access` table (column set from task 15), fills it from a Hypothesis strategy (rows for the bundle ID in declared services, the same bundle ID in undeclared services, other bundle IDs, and the client `All`; cells with NULL, integers, ASCII and Unicode text, quotes, and random `csreq`-like blobs including empty ones), and exports `CAPTURE_TCC_DB_TEST`
    - Add a row reader that uses Python's `sqlite3` module, independent of the code under test
    - Add stub `sqlite3` (logs argv, then runs `/usr/bin/sqlite3`) and `pkill` (logs the `tccd` restart), and change the `tccutil` stub to delete matching rows from the temp database to imitate a reset
    - Make no test open the user database
    - _Requirements: 13.1, 14.3, 14.9_

  - [x] 16.2 Implement path guard, literal builders, guards, and probe
    - Create `lib/tccdb.sh` with `tcc_path_ok`, `tcc_db_path` (honors `CAPTURE_TCC_DB_TEST` only under the system temporary directory), `tcc_probe` (read-only open), `sql_quote`, `tcc_valid_bundle`, `tcc_valid_service`, `tcc_ident`, `cell_literal`, and `tcc_guard` (sources `reset.sh` for `guard_bundle_id`)
    - Send every SQL script to `sqlite3` on stdin and start each with `.bail on`
    - _Requirements: 1.9, 13.1, 13.12, 17.1, 17.2, 17.4, 17.5_

  - [x] 16.3 Implement snapshot and backup
    - Add `tcc_columns`, `tcc_scope_query`, `tcc_rows` (read-only, fails closed on a real-number cell), `tcc_snapshot` (atomic write, typed hex cells, `services_without_row`, row count re-check), `tcc_backup` (byte copy with size and readability check, never overwrites), and `tcc_notice`
    - _Requirements: 15.2, 15.5, 15.6, 15.8, 15.9, 17.3, 17.6, 17.7, 17.8, 17.10_

  - [x] 16.4 Implement restore, verify, and pending lookup
    - Add `tcc_restore` (one `BEGIN IMMEDIATE` transaction with delete of the scope rows then `INSERT OR REPLACE`), `tcc_verify` (names each differing service), `tcc_restart_daemon`, `tcc_mark_restored`, and `tcc_pending` (reads only the state directory)
    - Refuse cells that do not match the cell grammar before any `sqlite3` write
    - _Requirements: 16.4, 16.5, 16.6, 16.7, 16.8, 16.9, 16.10, 16.11, 16.12, 16.13, 17.9, 17.11_

  - [x] 16.5 Write property test for snapshot exactness and scope
    - **Property 29: Snapshot is exact and scoped**
    - **Validates: Requirements 15.2, 15.5, 15.6, 17.3, 17.6**
    - File: `tests/test_tccdb_snapshot.py`

  - [x] 16.6 Write property test for the restore round trip
    - **Property 30: Restore round trip**
    - **Validates: Requirements 16.4, 16.6, 16.8**
    - File: `tests/test_tccdb_roundtrip.py`

  - [x] 16.7 Write property test for restore idempotence
    - **Property 31: Restore is idempotent**
    - **Validates: Requirements 16.10**
    - File: `tests/test_tccdb_idempotent.py`

  - [x] 16.8 Write property test for created-row removal
    - **Property 32: Rows created after the snapshot are removed**
    - **Validates: Requirements 16.5, 16.6, 17.9**
    - File: `tests/test_tccdb_created_rows.py`

  - [x] 16.9 Write property test for scope limits
    - **Property 33: Restore never touches rows outside the scope**
    - **Validates: Requirements 15.6, 17.3**
    - File: `tests/test_tccdb_scope.py`

  - [x] 16.10 Write property test for unsafe bundle IDs and services
    - **Property 34: Unsafe bundle IDs and services are refused**
    - **Validates: Requirements 13.2, 17.4, 17.5**
    - File: `tests/test_tccdb_refusals.py`

  - [x] 16.11 Write property test for the database path guard
    - **Property 35: Database path guard**
    - **Validates: Requirements 17.1, 17.2**
    - File: `tests/test_tccdb_path.py`

  - [x] 16.12 Write property test for failed restore
    - **Property 36: Failed restore leaves the database unchanged**
    - **Validates: Requirements 16.7, 16.12, 16.13**
    - File: `tests/test_tccdb_failed_restore.py`

  - [x] 16.13 Write property test for verification
    - **Property 37: Verification detects every difference**
    - **Validates: Requirements 16.8, 16.12**
    - File: `tests/test_tccdb_verify.py`

  - [x] 16.14 Write property test for SQL literal construction
    - **Property 38: SQL literal construction is lossless**
    - **Validates: Requirements 13.12, 15.2**
    - File: `tests/test_tccdb_literals.py`

  - [x] 16.15 Write property test for backups
    - **Property 39: Backup is byte-identical and never overwritten**
    - **Validates: Requirements 15.9, 17.7, 17.8**
    - File: `tests/test_tccdb_backup.py`

  - [x] 16.16 Write property test for database references staying in `tccdb.sh`
    - **Property 43: Database references stay in `tccdb.sh`**
    - Add a `scan_tcc_refs` helper in `tests/tcc_scan.py` that reports files containing `TCC.db` or `com.apple.TCC`, excluding `lib/tccdb.sh`, files under `tests/`, and `*.md`; also assert the real `scripts/capture/` tree reports nothing
    - **Validates: Requirements 13.1, 13.11, 14.9**
    - File: `tests/test_tcc_scan.py`

- [x] 17. Implement `lib/restore.sh`, the `restore` subcommand, and `--no-restore`
  - [x] 17.1 Create `lib/restore.sh`
    - Implement `tcc_ensure_snapshot` (once per bundle per run, reuse of a pending snapshot that covers all services, failure when it does not, dry-run output with no `sqlite3` call, `--no-restore` notice), `tcc_copy_snapshot_to_session`, `restore_one` (verify failure and write rejection messages with the backup path and the manual fallback), `restore_all`, and `cmd_restore`
    - Refuse a pending snapshot whose bundle ID is in no loaded profile and count it as a failure
    - _Requirements: 15.1, 15.3, 15.4, 15.7, 15.10, 15.11, 16.2, 16.9, 16.11, 16.12, 16.13, 16.14, 16.16, 16.17, 17.4_

  - [x] 17.2 Wire `restore` and `--no-restore` in `capture.sh`
    - Add the `restore [<profile>]` subcommand with `--dry-run`, and parse `--no-restore` for `setup`, `doctor`, `reset`, `prompt`, and `run`
    - _Requirements: 1.9, 15.10, 16.2, 16.16, 16.17_

- [x] 18. Add Full Disk Access as the fifth permission
  - [x] 18.1 Update `permcheck.swift`, `setup.sh`, and doctor
    - Make `perm_status full-disk-access` call `tcc_probe`, and make `perm_request full-disk-access` only open the `Privacy_AllFiles` pane
    - Print exactly five status lines in `setup` (the fifth reads `full-disk-access: skipped (--no-restore)` with `--no-restore`, with no probe), write five Setup_State_File entries (four with `--no-restore`), and print the Full Disk Access pane when it is missing
    - Add the `pending tcc snapshot: <bundle_id>|none` line to `doctor` through `tcc_pending`, keeping `doctor` read-only
    - Update `setup_state_merge` to cover all five keys
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.9, 17.11_

- [x] 19. Integrate snapshot and restore into the runner and cleanup
  - [x] 19.1 Update `cleanup.sh` and teardown
    - Make `cleanup_all` run `restore_all` after the target app quit and before the Focus restore, continue after a restore failure, and return non-zero when it failed, so `teardown` exits 1
    - Make the signal trap exit 130 or 143 whatever the restore result, printing the restore failure first
    - _Requirements: 2.11, 16.1, 16.3, 16.15_

  - [x] 19.2 Update the runner, `reset`, and preflight in `capture.sh`
    - Call `tcc_ensure_snapshot` inside the `reset` step before the first `tccutil reset`, print `tcc-snapshot` and `tcc-restore` lines without changing the twelve step names or their order, and copy the snapshot to each Session_Directory and its Manifest
    - Run the session's scoped reset first and then `cleanup_all` on step failure and on signals, and run the restore once in the run epilogue after the last `reset-after` step
    - Make `reset` take the snapshot and leave it pending
    - Add Full Disk Access to the preflight permission check (four checks with `--no-restore`) while still running all three conditions and naming every failure
    - Include the restore status in `plan_exit_code`
    - _Requirements: 3.8, 10.7, 12.1, 12.7, 12.8, 15.1, 15.3, 15.4, 15.7, 16.1, 16.15_

  - [x] 19.3 Write property test for one snapshot per run
    - **Property 40: One snapshot per run, taken before the first reset**
    - **Validates: Requirements 15.1, 15.4, 16.11**
    - File: `tests/test_tcc_wiring.py`

  - [x] 19.4 Write property test for failed snapshot blocking resets
    - **Property 41: A failed snapshot blocks every reset**
    - **Validates: Requirements 15.7, 15.8, 17.8**
    - File: `tests/test_tcc_snapshot_failure.py`

  - [x] 19.5 Write property test for `--no-restore`
    - **Property 42: `--no-restore` touches no database**
    - **Validates: Requirements 1.9, 12.7, 15.10, 16.16**
    - File: `tests/test_tcc_no_restore.py`

  - [x] 19.6 Write unit tests for restore wiring
    - Check from the stub call log that restore runs after the session reset and after the app quit in the success, step-failure, and signal paths
    - Cover `teardown` and `restore` restoring every pending snapshot, the `tccd` restart through the `pkill` stub, the rename to `.restored.json`, `nothing to restore`, a read-only temp database keeping the snapshot pending with the cause and backup path, `tcc-snapshot.json` in the session directory and Manifest, the notice naming the bundle ID and backup path, and `reset` followed by `restore`
    - _Requirements: 2.11, 15.3, 16.1, 16.3, 16.9, 16.11, 16.13, 16.14, 16.15, 17.10_
    - File: `tests/test_tcc_restore_wiring.py`

- [x] 20. Update existing tests for the new behavior
  - [x] 20.1 Update `tests/test_orchestration.py`
    - Change the static scan so `TCC.db` and `com.apple.TCC` are allowed only in `lib/tccdb.sh`, `tests/`, and `*.md`, keeping the `curl` and `nc` checks
    - Update the step-order and error-cleanup checks for the snapshot and restore lines and the reset-before-cleanup order
    - _Requirements: 12.1, 12.5, 13.1, 13.4, 13.11_

  - [x] 20.2 Update `tests/test_setup_teardown.py`
    - Change "four status lines" assertions to five, add the `--no-restore` case with the skipped Full Disk Access line, the Full Disk Access pane message, and the doctor pending-snapshot line, and make teardown cases cover a pending snapshot
    - _Requirements: 1.1, 1.5, 1.6, 1.9, 2.9, 2.11, 17.11_

  - [x] 20.3 Update `tests/test_setup_state.py` and `tests/test_teardown_guidance.py`
    - Make generated Setup_State_File data cover five permissions including `full-disk-access`
    - _Requirements: 1.3, 2.4_

  - [x] 20.4 Update `tests/test_dryrun.py` and `tests/test_preflight.py`
    - Extend the dry-run property with `--no-restore`, a pending snapshot, `reset --dry-run`, `restore --dry-run`, and the empty `sqlite3` stub log, and check the `would snapshot`, `would back up`, and `would restore` lines
    - Make the preflight stubs cover Full Disk Access as part of the permissions condition
    - Re-run the other test files and fix any that assert the old four-permission count or the old step output
    - _Requirements: 12.7, 12.8, 14.5, 14.6, 15.11, 16.17_

- [x] 21. Add the steering and hook exception for `lib/tccdb.sh`
  - [x] 21.1 Update the `macos-security-boundaries` steering file
    - Find the file under `.kiro/steering/` and add a narrowly worded exception: `scripts/capture/lib/tccdb.sh` may open the user-level TCC database only, for the target app's rows in declared services, after a backup, and never the system-level database
    - Keep every other TCC database prohibition unchanged
    - _Requirements: 13.1, 17.1, 17.9_

  - [x] 21.2 Update `scripts/hooks/guard-security-boundaries.py`
    - Read the hook's current matching rules first, then allow exactly the path `scripts/capture/lib/tccdb.sh` and keep blocking every other file that references a TCC database
    - Add `tests/test_guard_hook.py` under `scripts/capture/tests/` that feeds the hook `lib/tccdb.sh` and another path (including a lookalike path) and checks the allow and block results
    - _Requirements: 13.1, 13.11, 17.1_

- [x] 22. Documentation and project integration for TCC restore
  - [x] 22.1 Update `scripts/capture/README.md`
    - Add sections for Full Disk Access as the fifth permission, the `restore` subcommand, `--no-restore`, the snapshot and backup files in `captures/.state/`, the manual fallback when macOS rejects a write, the note that Full Disk Access may need a Capture_Host restart, and the Ward-commit note for a reused Ward
    - Update the permissions-per-subcommand table, the `setup` and `doctor` output description, and the worked example
    - Use gender-neutral wording
    - _Requirements: 14.1, 14.2, 15.10, 16.2, 16.13_

  - [x] 22.2 Update the devlog entry and pre-commit hook
    - Add the TCC snapshot and restore design to the `docs/devlog.md` entry for this feature (purpose, the single-file boundary, and the results from task 15)
    - Confirm `scripts/git-hooks/pre-commit` still runs the capture tests and passes with the new files
    - _Requirements: 14.3, 14.7, 14.9_

- [x] 23. Final checkpoint - Ensure all tests pass with a clean PATH
  - Run the full suite with `.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests` using a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin` plus the venv) so only the stubs and system tools are found, and confirm that no test needs a macOS permission or opens the user TCC database
  - Run `swift build` and `swift test --skip integration`, and confirm the static scan finds no TCC database reference outside `lib/tccdb.sh`, `tests/`, and `*.md`
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties and use Hypothesis with at least 100 examples
- Unit tests validate specific examples and edge cases
- The first successful live capture needs a manual run (`capture.sh setup`, then `run zcode desktop`); its asset names are then added to the devlog entry from task 13.2

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1", "6.1", "7.1"] },
    { "id": 3, "tasks": ["2.3", "2.4", "3.2", "4.1", "6.2", "7.2", "7.3", "7.4", "7.5"] },
    { "id": 4, "tasks": ["4.2", "4.3", "4.4", "4.5", "4.6", "5.1", "6.3", "6.4", "6.5", "6.6", "7.6", "8.1"] },
    { "id": 5, "tasks": ["5.2", "5.3", "8.2", "8.3"] },
    { "id": 6, "tasks": ["9"] },
    { "id": 7, "tasks": ["10.1", "11.1", "11.2", "11.3", "11.4", "11.5"] },
    { "id": 8, "tasks": ["10.2", "10.3", "11.6", "11.7", "11.8"] },
    { "id": 9, "tasks": ["10.4", "10.5", "12.1"] },
    { "id": 10, "tasks": ["12.2", "12.3", "12.4", "12.5"] },
    { "id": 11, "tasks": ["12.6", "12.7", "12.8", "13.1", "13.2"] },
    { "id": 12, "tasks": ["14"] },
    { "id": 13, "tasks": ["15"] },
    { "id": 14, "tasks": ["16.1", "21.1", "21.2"] },
    { "id": 15, "tasks": ["16.2"] },
    { "id": 16, "tasks": ["16.3", "16.11", "16.14", "16.16"] },
    { "id": 17, "tasks": ["16.4", "16.5", "16.15"] },
    { "id": 18, "tasks": ["16.6", "16.7", "16.8", "16.9", "16.10", "16.12", "16.13", "17.1", "18.1"] },
    { "id": 19, "tasks": ["17.2", "19.1"] },
    { "id": 20, "tasks": ["19.2"] },
    { "id": 21, "tasks": ["19.3", "19.4", "19.5", "19.6", "20.1", "20.2", "20.3", "20.4"] },
    { "id": 22, "tasks": ["22.1", "22.2"] },
    { "id": 23, "tasks": ["23"] }
  ]
}
```
