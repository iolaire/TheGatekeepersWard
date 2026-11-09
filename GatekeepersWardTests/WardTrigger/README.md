# WardTrigger Test Suite

Tests for the `WardTrigger` CLI harness (`WardTrigger/` at the repository
root) — the standalone executable that deterministically triggers macOS TCC
permission dialogs for Gatekeeper's Ward development and demo recording.

These tests exercise the CLI **without ever firing a real TCC dialog**: the
trigger functions are replaced with stubs via `WardTriggerBehaviors`
(function-pointer injection in `WardTrigger/Dispatch.swift`), and the smoke
test only invokes the binary with no arguments (which prints usage and exits
`1` before any trigger runs).

## Contents

| File | What it verifies |
|---|---|
| `DemoEchoTests.swift` | **Property 5 — extra argv passthrough** (every extra argument appears in the echoed `> docs …` command line; 200 iterations in CI, 1000 locally) plus unit tests for `printUsage()` / `printUnrecognized(_:)` output contracts (Requirements 1.5, 1.6, 8.2, 8.4) |
| `SubcommandDispatchTests.swift` | The dispatch contract in `runWardTriggerDispatch(arguments:behaviors:)` — each subcommand fires exactly one stub trigger, no-args and unknown-subcommand exit `1` with usage, valid invocations exit `0` (Requirements 1.1–1.7) |
| `WardTriggerSmokeTests.swift` | End-to-end: spawns the **built binary** with no arguments and asserts exit code `1` plus the usage summary on stdout (Requirement 1.5) |

Shared fixtures these tests rely on live in `../Fixtures/`:
`ProcArgsFixtures.swift` (`SeededRNG`, `generatePrintableASCIIArgv`,
`encodeProcArgsBuffer`), `TCCLogFixtures.swift`, and `OutputCollector.swift`
(per-test output sink).

## Running

```bash
swift build                                     # smoke test needs the binary
swift test --filter DemoEchoTests
swift test --filter SubcommandDispatchTests
swift test --filter WardTriggerSmokeTests
swift test                                      # everything
```

Property loops run 1000 iterations locally; set the `CI` environment variable
to drop to 200 (e.g. `CI=1 swift test`).

## Manual TCC verification (not automated — separate from this suite)

These tests deliberately never fire a real TCC dialog. To exercise the real
prompt path — e.g. while developing `TCCWatcher`/`ProcessInspector` or
recording the demo — use the launcher scripts, which attribute the prompt to
WardTrigger's own bundle ID via LaunchServices:

```bash
# One-time: create the canary file the Documents probe reads (never modified).
touch ~/Documents/.ward_canary

# Fire a real TCC dialog for each service (dialog appears on screen):
scripts/run_ward_trigger.sh docs rg "AWS_SECRET" ~/Documents/prod.env
scripts/run_ward_trigger.sh contacts
scripts/run_ward_trigger.sh mic

# Read the captured stdout of the trigger run:
cat tmp/ward-trigger.out
# > docs rg AWS_SECRET /Users/<you>/Documents/prod.env
# [WardTrigger] Documents access granted/denied…

# Re-arm first-prompt state and clean tmp/ward-trigger.out:
scripts/reset_ward_trigger.sh
```

Behavior per subcommand:

| Subcommand | TCC service | What you'll see |
|---|---|---|
| `docs` | `kTCCServiceSystemPolicyDocumentsFolder` | Documents dialog (needs the canary file to exist; enumerates `~/Documents` read-only) |
| `contacts` | `kTCCServiceAddressBook` | Contacts dialog — blocks until you click, then exits 0 either way |
| `mic` | `kTCCServiceMicrophone` | Microphone dialog — same semaphore pattern as contacts |

Extra positional arguments after the subcommand are echoed as a simulated
command line and live in the process's argv (for `ProcessInspector`'s
`sysctl(KERN_PROCARGS2)` capture) — they never change trigger behavior.

Tips:

- Check whether a dialog is pending with `pgrep -l -f WardTrigger` — an alive
  process is suspended waiting for your click.
- Verify attribution in **System Settings → Privacy & Security** — entries
  appear as *WardTrigger*, not your terminal.
- If a prompt stops appearing after a rebuild, the ad-hoc signature changed —
  run `scripts/reset_ward_trigger.sh`.
- Targeted re-arm of a single service:
  `tccutil reset Microphone com.gatekeepersward.ward-trigger`

## Implementation notes

- **Never redirect stdout in tests.** Swift Testing runs tests in parallel and
  file descriptor 1 is process-global, so any `dup2` capture races with every
  other test that prints (this caused a flaky `noExtraArgsProducesMinimalOutput`).
  The `print*` helpers take an injectable `write:` sink; tests pass an
  `OutputCollector` so each test owns its output.
- **Real TCC behavior is deliberately untested here.** Triggering an actual
  prompt requires LaunchServices attribution, usage-description keys, a
  code-sealed bundle, and a foreground app — all handled by
  `scripts/run_ward_trigger.sh`, which is exercised manually (see
  `.kiro/steering/testing-strategy.md` §5). In-process tests stub the
  triggers instead.
- The smoke test locates the binary under `.build/` (falling back to
  `swift build --show-bin-path`), so it assumes a prior `swift build`.
