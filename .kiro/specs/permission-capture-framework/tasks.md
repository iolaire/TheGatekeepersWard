# Implementation Plan: Permission Capture Framework

## Overview

The framework is implemented in bash (bash 3.2 compatible) under `scripts/capture/`, with small JXA, AppleScript, and Swift helpers. Pure decision logic goes into `lib/*.sh` first, together with its property tests (pytest + Hypothesis, run from `.kiro/tools/.venv`), then the side-effecting drivers (video, Ward, target app, resolve, Focus), then the `run` orchestration that wires every step together. All external calls in tests go through stub binaries, so no test needs Accessibility, Screen Recording, or Automation grants.

Test files are named per task so tasks in the same wave never write the same file.

## Tasks

- [-] 1. Re-measure the TCC dialog window owner and layer on this macOS
  - Run `scripts/dump_window_list.swift` on this Mac (macOS 27.2.1, build 26B131) while a real TCC prompt is showing, for example one raised by WardTrigger
  - Record the measured window owner, layer, and size of the TCC prompt, and the Ward menu bar item layer if Ward is running
  - Record the Allow and Deny button labels seen on the prompt for folder and removable-volume services
  - Create `scripts/capture/lib/defaults.sh` that defines `CAPTURE_PROMPT_OWNER`, `CAPTURE_PROMPT_LAYER`, the Ward menu bar minimum layer, and the allow and deny label lists, each overridable by an environment variable of the same name
  - Add a short entry to `docs/devlog.md` with the measured values and the macOS build, following the existing heading format
  - If a measurement cannot be taken, keep the design defaults (`UserNotificationCenter`, layer 8, menu bar layer 24 or higher) and note that in the devlog entry
  - _Requirements: 6.1, 9.4, 10.4_

- [ ] 2. Set up the framework skeleton and test harness
  - [~] 2.1 Create `lib/common.sh` and the `capture.sh` dispatcher
    - Implement `ext`, `quote_cmd`, `log_step`, `die`, `utc_now_ms`, and the exit-code constants
    - Create `capture.sh` with subcommand dispatch, global option parsing, `--dry-run` handling, and the personal-data notice printed before any Scenario
    - Add `captures/` to `.gitignore`
    - _Requirements: 11.9, 12.9, 13.6, 13.10, 14.5, 14.8_

  - [~] 2.2 Create the Python test harness and stub binaries
    - Create `tests/conftest.py` with the bash function runner (values passed as arguments), the temporary repo copy, and Hypothesis strategies for IDs, prompt text, window rows, rectangles, button labels, manifests, and file names
    - Create stub `tccutil`, `osascript`, `screencapture`, `pgrep`, and `open` in `tests/stubs/` that log argv to a call log and return canned output
    - Add a skip helper that marks a test skipped with a reason when a macOS permission is required
    - _Requirements: 14.3, 14.4_

  - [~] 2.3 Write property test for argument quoting
    - **Property 7: Argument quoting is lossless**
    - **Validates: Requirements 13.10**
    - File: `tests/test_quoting.py`

  - [~] 2.4 Write property test for the step log line
    - **Property 23: Step log line**
    - **Validates: Requirements 12.9**
    - File: `tests/test_log_step.py`

- [ ] 3. Implement option validators
  - [~] 3.1 Create `lib/validate.sh`
    - Implement `valid_resolve`, `valid_display`, `valid_range`, and `with_default` with the documented defaults (launch 20, prompt 45, dwell 4, resolve `deny`, main display)
    - _Requirements: 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3_

  - [~] 3.2 Write property test for option validators
    - **Property 12: Option validators**
    - **Validates: Requirements 5.3, 6.3, 7.5, 7.6, 7.7, 8.2, 10.1, 10.3**
    - File: `tests/test_validate.py`

- [ ] 4. Implement App_Profile loading, validation, and shipped profiles
  - [~] 4.1 Create `lib/profile.sh` and wire `list`
    - Implement `profile_parse` (restricted `key = value` parser that never sources the file), `profile_validate`, `profile_load_all`, `profile_services`, and `profile_scenarios`
    - Validate required fields, 1 to 20 scenarios, prompt length 1 to 2,000, numeric ranges, and that `profile_id` equals the file name stem
    - Wire `capture.sh list`, including the `no profiles found` exit 1 case
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

  - [~] 4.2 Add the shipped profiles and template
    - Create `profiles/zcode.profile` (bundle ID `dev.zcode.app`) and `profiles/deepseek-harness.profile` (bundle ID `com.deepseek.dsh`), each with at least the `desktop` and `removable-volume` Scenarios and read-only list-directory prompts
    - Create `profiles/_template.profile.example` with a comment for each required field
    - _Requirements: 4.8, 4.9, 4.10, 13.5_

  - [~] 4.3 Write property test for profile round trip
    - **Property 1: Profile round trip**
    - **Validates: Requirements 4.2, 4.3**
    - File: `tests/test_profile_roundtrip.py`

  - [~] 4.4 Write property test for profile loading
    - **Property 2: Profile loading ignores non-profile files**
    - **Validates: Requirements 4.1, 4.5, 4.9**
    - File: `tests/test_profile_loading.py`

  - [~] 4.5 Write property test for incomplete profiles
    - **Property 3: Incomplete profiles are rejected by field name**
    - **Validates: Requirements 4.6**
    - File: `tests/test_profile_fields.py`

  - [~] 4.6 Write property test for profile ID and file name match
    - **Property 4: Profile ID must match file name**
    - **Validates: Requirements 4.7**
    - File: `tests/test_profile_id.py`

- [ ] 5. Implement the scoped permission reset
  - [~] 5.1 Create `lib/reset.sh` and wire `reset`
    - Implement `guard_bundle_id`, `reset_plan`, and `reset_run` with `--service` and `--dry-run`
    - Run the guard on every planned command before running any `tccutil` command, print each command with its exit code, and continue after a failure
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 13.1, 13.2, 13.3_

  - [~] 5.2 Write property test for the bundle-ID guard
    - **Property 5: Bundle-ID guard**
    - **Validates: Requirements 3.2, 13.2, 13.3**
    - File: `tests/test_reset_guard.py`

  - [~] 5.3 Write property test for the reset plan
    - **Property 6: Reset plan is scoped to one bundle and the profile's services**
    - **Validates: Requirements 3.1, 3.3, 3.4, 3.8, 10.7**
    - File: `tests/test_reset_plan.py`

- [ ] 6. Implement the manifest and Session_Directory logic
  - [~] 6.1 Create `lib/json.js` and `lib/manifest.sh`
    - Implement `manifest_set`, `manifest_add_artifact`, `manifest_write`, `manifest_check`, and `manifest_roundtrip`, building JSON through `osascript -l JavaScript`
    - Enforce the outcome enum, 0 to 50 relative artifact names, UTC timestamps, the ward commit format, and the failure fields
    - _Requirements: 11.1, 11.2, 11.5, 11.8_

  - [~] 6.2 Create `lib/session.sh` path and directory functions
    - Implement `run_timestamp`, `session_path`, and `session_create` (plain `mkdir` on the last segment, leaving an existing directory untouched)
    - _Requirements: 9.10, 11.3, 11.4_

  - [~] 6.3 Write property test for session paths
    - **Property 8: Session path structure**
    - **Validates: Requirements 11.3, 9.10**
    - File: `tests/test_session_path.py`

  - [~] 6.4 Write property test for existing Session_Directory safety
    - **Property 9: Existing Session_Directory is never modified**
    - **Validates: Requirements 11.4**
    - File: `tests/test_session_exists.py`

  - [~] 6.5 Write property test for manifest validity
    - **Property 10: Manifest validity**
    - **Validates: Requirements 11.1, 11.2, 11.5**
    - File: `tests/test_manifest_check.py`

  - [~] 6.6 Write property test for manifest JSON round trip
    - **Property 11: Manifest JSON round trip**
    - **Validates: Requirements 11.8**
    - File: `tests/test_manifest_roundtrip.py`

- [ ] 7. Implement window matching, prompt classification, and screenshot geometry
  - [~] 7.1 Create `lib/windows.js`, `lib/windows.sh`, and `lib/services.tbl`
    - Implement the JXA window and display lists, `match_prompt`, `match_hud`, `match_ward_item`, `poll_window`, and `classify_prompt`
    - Read the prompt owner, layer, and menu bar layer from `lib/defaults.sh` (task 1)
    - _Requirements: 6.1, 6.2, 6.4, 6.5, 6.7, 9.4_

  - [~] 7.2 Create `lib/shots.sh`
    - Implement `crop_rect`, `shot_screen`, `shot_window`, and `shot_pair`
    - Write to a temporary name, rename only on success, remove partial files, and use the literal names `screen.png`, `prompt.png`, `hud.png`, and `pair.png`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9_

  - [~] 7.3 Write property test for prompt window matching
    - **Property 13: Prompt window matching**
    - **Validates: Requirements 6.1**
    - File: `tests/test_match_prompt.py`

  - [~] 7.4 Write property test for HUD and menu bar item matching
    - **Property 14: HUD and menu bar item matching**
    - **Validates: Requirements 6.4, 9.4**
    - File: `tests/test_match_hud.py`

  - [~] 7.5 Write property test for prompt text classification
    - **Property 15: Prompt text classification**
    - **Validates: Requirements 6.7**
    - File: `tests/test_classify_prompt.py`

  - [~] 7.6 Write property test for the pair crop rectangle
    - **Property 16: Pair crop rectangle**
    - **Validates: Requirements 7.4**
    - File: `tests/test_crop_rect.py`

- [ ] 8. Implement session planning and the failure policy
  - [~] 8.1 Create `lib/plan.sh`
    - Implement `plan_sessions` (profiles in name order, scenarios in declared order, `baseline` before `ward`, skipped profiles named on stderr), `plan_continue`, and `plan_exit_code`
    - _Requirements: 9.7, 9.8, 12.3, 12.4, 12.6_

  - [~] 8.2 Write property test for planning order
    - **Property 19: Session planning order**
    - **Validates: Requirements 9.7, 12.3, 12.4**
    - File: `tests/test_plan_order.py`

  - [~] 8.3 Write property test for the failure policy
    - **Property 20: Failure policy**
    - **Validates: Requirements 9.8, 12.6**
    - File: `tests/test_plan_failure.py`

- [~] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 10. Implement setup, doctor, and teardown
  - [~] 10.1 Create `lib/permcheck.swift`, `lib/setup.sh`, and wire `setup` and `doctor`
    - Implement `perm_status`, `perm_request` (opens the System Settings pane within 5 s), `setup_state_merge`, `cmd_setup`, and `cmd_doctor`
    - `doctor` stays read-only: no permission request and no Setup_State_File write
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

  - [~] 10.2 Create `lib/cleanup.sh` and wire `teardown` and signal traps
    - Implement idempotent `cleanup_all` (clipboard restore, recorder stop and playability check, Ward stop with `SIGKILL` fallback, quit of apps the framework launched, Focus restore, revoke guidance) and the `INT`/`TERM`/`EXIT` traps with exit 130 and 143
    - Use the helper functions from tasks 11.1 to 11.5 through guarded calls so cleanup works from a fresh shell
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 2.10_

  - [~] 10.3 Write property test for setup state merge
    - **Property 25: Setup state is never overwritten**
    - **Validates: Requirements 1.3**
    - File: `tests/test_setup_state.py`

  - [~] 10.4 Write property test for teardown revoke guidance
    - **Property 26: Teardown revoke guidance**
    - **Validates: Requirements 2.4**
    - File: `tests/test_teardown_guidance.py`

  - [~] 10.5 Write unit tests for setup, doctor, and teardown
    - Cover four status lines, exit codes, doctor tool lines and read-only behavior, teardown with a dummy process, a stale Marker_File, and the nothing-to-tear-down message
    - _Requirements: 1.1, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 2.9_
    - File: `tests/test_setup_teardown.py`

- [ ] 11. Implement the side-effecting drivers
  - [~] 11.1 Create `lib/video.sh`
    - Implement `video_start`, `video_stop`, `video_duration`, and `video_playable` for `screencapture -v` and the `ffmpeg` backend, with the 1 second liveness check and the 10 second finalize wait
    - _Requirements: 8.1, 8.3, 8.4, 8.5, 8.6, 8.7, 8.8, 8.9, 8.10_

  - [~] 11.2 Create `lib/ward.sh`
    - Implement `ward_pids`, `ward_ensure` (baseline refusal, reuse without Marker_File, start through `scripts/run_ward.sh`, 10 second menu bar wait), and `ward_stop_if_marked`
    - Record the Ward commit hash as 40 hex characters or `unknown`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.9, 11.2_

  - [~] 11.3 Create `lib/app.sh`, `lib/ui.applescript`, and `lib/clipboard.js`
    - Implement `app_launch`, `app_focus_input`, `app_check_paths` with the `/Volumes/<name>` extractor, `app_send` (clipboard and keystroke, with clipboard restore on success and failure), and `app_approve`
    - Pass every value to `osascript` as argv, never in script source
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7, 5.8, 5.9, 5.10, 13.10_

  - [~] 11.4 Create `lib/resolve.sh`
    - Implement `pick_button` and `resolve_prompt` (allow, deny, none), the 5 second dismissal check, and the not-found path that saves a screenshot and lists the buttons found
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [~] 11.5 Create `lib/focus.sh` and `lib/focus.applescript`
    - Implement `focus_enable` and `focus_restore` for `--redact-notifications`, failing closed when the Focus state cannot be read or set
    - _Requirements: 13.7, 13.8, 13.9_

  - [~] 11.6 Write property test for removable-volume path extraction
    - **Property 17: Removable-volume path extraction**
    - **Validates: Requirements 5.5, 5.6**
    - File: `tests/test_volume_paths.py`

  - [~] 11.7 Write property test for button selection
    - **Property 18: Button selection**
    - **Validates: Requirements 10.1, 10.4**
    - File: `tests/test_pick_button.py`

  - [~] 11.8 Write unit tests for the drivers with stubs
    - Cover ffmpeg missing, recorder exiting within 1 second, Ward reuse and baseline refusal, clipboard restore on a failed paste, and `--resolve none`
    - _Requirements: 5.9, 8.5, 8.6, 9.2, 9.6, 10.2_
    - File: `tests/test_drivers.py`

- [ ] 12. Wire the run orchestration
  - [~] 12.1 Implement the session step runner and the `prompt` and `run` subcommands
    - Add `run_step`, the preflight check (all three conditions always run), the twelve ordered steps, error cleanup with an `error` Manifest, the `screenshots` ordering (screen and prompt first, then HUD polling and `hud.png` and `pair.png`), the end-of-session scoped reset, and `--keep-going`, `--all-scenarios`, `--all-profiles`, `--no-reset`, `--no-video`, `--no-images`, `--display`, and `--mode`
    - Make `--dry-run` print each step name and the quoted text of each command, create nothing, and call no external binary
    - Reject unknown profiles, scenarios, and option values with exit 2 before any step
    - _Requirements: 3.8, 3.9, 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 8.2, 9.7, 9.8, 10.6, 10.7, 10.8, 11.1, 11.5, 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 14.5, 14.6_

  - [~] 12.2 Implement `summary.md` and `export`
    - Add `write_summary` to `lib/session.sh` (only when both manifests exist) and create `lib/export.sh` with the `<ts>__<profile>__<scenario>__<mode>__<file>` naming and the two distinct error messages
    - Wire `capture.sh export <dir>` and the summary call at the end of `run`
    - _Requirements: 11.6, 11.7, 11.10, 11.11_

  - [~] 12.3 Write property test for unknown profile or scenario
    - **Property 21: Unknown profile or scenario creates nothing**
    - **Validates: Requirements 12.2**
    - File: `tests/test_unknown_names.py`

  - [~] 12.4 Write property test for preflight
    - **Property 22: Preflight reports every failure**
    - **Validates: Requirements 12.7, 12.8**
    - File: `tests/test_preflight.py`

  - [~] 12.5 Write property test for dry-run
    - **Property 24: Dry-run has no effects**
    - **Validates: Requirements 3.7, 12.1, 14.5, 14.6**
    - File: `tests/test_dryrun.py`

  - [~] 12.6 Write property test for summary links
    - **Property 27: Summary links match manifests**
    - **Validates: Requirements 11.6, 11.7**
    - File: `tests/test_summary.py`

  - [~] 12.7 Write property test for export
    - **Property 28: Export copies the selected files and nothing else**
    - **Validates: Requirements 11.10, 11.11**
    - File: `tests/test_export.py`

  - [~] 12.8 Write unit tests for orchestration and security boundaries
    - Cover step order with stubs, a failing step producing an `error` Manifest and cleanup, a failed screenshot being skipped, a static scan that no script references `TCC.db`, `curl`, or `nc`, and the no-permission-required guarantee of the suite
    - _Requirements: 7.8, 12.1, 12.5, 13.1, 13.4, 14.3, 14.4_
    - File: `tests/test_orchestration.py`

- [ ] 13. Documentation and project integration
  - [~] 13.1 Write `scripts/capture/README.md`
    - Add a section for setup, teardown, reset, profile authoring, each subcommand, each option, and the permissions each subcommand needs
    - Add the worked example from creating a new profile to a successful `run --dry-run`, and how to re-derive input locators with Accessibility Inspector
    - Use gender-neutral wording throughout
    - _Requirements: 14.1, 14.2_

  - [~] 13.2 Add the pre-commit test hook line and the devlog entry
    - Add a line to `scripts/git-hooks/pre-commit` that runs `.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests` when the virtualenv exists
    - Add a `docs/devlog.md` entry stating the feature's purpose, with a placeholder list for the assets of the first successful capture, using gender-neutral wording
    - _Requirements: 14.3, 14.7_

- [~] 14. Final checkpoint - Ensure all tests pass
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
    { "id": 12, "tasks": ["14"] }
  ]
}
```
