# How We Used Kiro

Gatekeeper's Ward was built in the Kiroween 2026 Submission Period (first commit 2026-11-05). This page answers the questions the Devpost rules ask about Kiro use. Every claim points to a file or a commit you can open. Where the record does not support a claim, we say so.

Day-by-day notes, including failures, are in [devlog.md](devlog.md).

## At a glance

| Kiro feature | What we did | Where to look |
|---|---|---|
| Specs | 7 specs with requirements, design and tasks. 296 of 301 task lines ticked; the other 5 are one group of deferred follow-ups | `.kiro/specs/` |
| Steering | 9 files, 8 loaded automatically and 1 manual, most paired with a hook or a test | `.kiro/steering/` |
| Hooks | 6 Kiro hooks plus a git pre-commit gate | `.kiro/hooks/`, `scripts/hooks/`, `scripts/git-hooks/pre-commit` |
| MCP | A custom Darwin and TCC reference server, built spec-first | `.kiro/tools/`, `.kiro/settings/mcp.json` |
| Property-based testing | Seeded random-input tests on both parsers, plus Hypothesis in Python | `GatekeepersWardTests/`, `.kiro/tools/tests/`, `scripts/capture/tests/` |
| Powers | `swift-expert`, used for the Swift 6 migration | devlog 2026-11-12 |
| Custom agents | None created | n/a |
| Prompts | A reusable review prompt that scores the repo against the rules | `.kiro/prompts/code-review-hackathon.md` |

## Kiro IDE, CLI, Web, Crew

We used more than one Kiro surface, for different jobs.

- **Kiro IDE** is where specs, steering and hooks live and run. The hooks in `.kiro/hooks/` load and fire in the IDE: the security guard (before a write) and the spec-first nudge (on each prompt) both fired while we produced the submission review. Devlog bylines read "pairing with Kiro".
- **Kiro CLI** was a second host and a test subject. The Ward was verified live on macOS 27.0.1 "from a Kiro CLI session in Zed" (devlog 2026-11-08). That check mattered because the app has to attribute a permission prompt to a child process started by an agent. `scripts/hooks/guard-security-boundaries.py` is the CLI form of the IDE security guard.
- **Kiro Crew** was used for the demo video work. The Remotion draft, voice-over timing and narrative rewrite (devlog 2026-11-23, bylines "pairing with KiroCrew") were done there.
- **Kiro Web**: no use is recorded in the repo.

What differed in practice: the IDE gave us the structured features (specs, hooks, steering inclusion). The CLI was the quickest way to run an agent that triggers real macOS prompts. Crew suited the long, multi-step video assembly.

## Custom agents

We did not create custom agents. Two things stand in for them. Three of the hooks run an agent prompt on an event (`raw-pointer-review`, `security-boundary-guard`, `spec-first-nudge`), which behaves like a small single-purpose reviewer. And `.kiro/prompts/code-review-hackathon.md` is a reusable prompt that produces `docs/HACKATHON_REVIEW.md`. Its scores are recorded in git history (30, 32, 33, 34, 36, 37 out of 50) and each run drove concrete follow-up work.

## Agent hooks

| Hook | Trigger | Action | Workflow it automates |
|---|---|---|---|
| Build and Test Gate | After a spec task finishes | `swift build && swift test --skip integration` | Every finished task is proven by a green build and test run |
| Castle Keep Palette Check | Save in `HUD/` or `MenuBar/` | `scripts/hooks/check-palette.sh` | Flags hex colours outside the palette and generic Allow/Deny copy |
| Swift Standards Lint | Save in app or WardTrigger code | `scripts/hooks/lint-swift-standards.sh` | Flags force-unwraps, files over about 300 lines, public declarations without `///` |
| Raw Pointer Safety Review | Save in `Core/` | Agent prompt | Reviews `KERN_PROCARGS2` and `proc_pidinfo` code against the memory-safety and Darwin steering |
| Security Boundary Guard | Before a write tool runs | Agent prompt | Stops and asks before writing forbidden entitlements, `task_for_pid`, direct TCC database access, signals to inspected processes, or a focus-stealing `NSPanel` |
| Spec-First Nudge | On each user prompt | Agent prompt | Reminds Kiro to check `.kiro/specs/` before building a component |

`scripts/git-hooks/pre-commit` repeats the build and test gate at commit time and also runs the Python capture-framework tests when the virtual environment exists.

How they helped: the rules we care about most are checked every time instead of remembered. The final tree has no force-unwraps in `GatekeepersWard/`, and the largest source file is 301 lines. The palette hook shaped a decision too: when three colours from the chosen art joined the palette, the palette and the hook were updated together, and a `palette-ok` marker exempts one quoted line (devlog 2026-11-10). We have not logged a case where a hook caught a serious bug, so we do not claim one.

One note on format: the devlog entry of 2026-11-23 03:30 UTC describes converting the hooks to `*.kiro.hook` files. The committed files are JSON (`.kiro/hooks/*.json`) after a later "standardize hook configurations" commit (`ab6966b`), and the IDE loads them as described above.

## Spec-driven development

**Structure.** Each spec has `requirements.md` (user stories with numbered acceptance criteria in "THE system SHALL" form), `design.md`, and `tasks.md`. Tasks cite the requirement numbers they satisfy (for example `_Requirements: 11.2 to 11.7_`), so a reader can go from a task to the criterion and back. The seven specs are `ward-trigger`, `ward-app`, `castle-keep-visual-theme`, `hud-placement-and-menubar-theme`, `hud-plain-language-copy`, `permission-capture-framework` and `darwin-tcc-mcp-server`.

**How it helped.**
- `ward-trigger` (spec first) gave us the test harness that can raise a real macOS prompt on demand. The rest of the app was verified with it.
- `hud-plain-language-copy` is a clean example. The spec (`a63efa2`) was written before the code (`e17fdc1`, `2c548c5`). It set a height budget the HUD must stay under, and the task list records the measured heights.
- `permission-capture-framework` (109 tasks) kept a large, risky piece of work (it snapshots and restores TCC state) bounded by a single-file rule and property tests.

**Versus vibe coding.** We did not run a controlled comparison, so this is an observation, not a measurement. The core runtime (`TCCWatcher`, `ProcessInspector`, the HUD and the menu bar) was built first on a `dev` branch without a spec. The `ward-app` spec was written afterward and says so in its introduction ("written retroactively"). Reviewing that code against its own spec produced 11 follow-ups (prompt tracking by `msgID`, restart backoff, a visible "not watching" state, non-blocking shutdown and others). 7 are done and 4 are deferred, with reasons in `.kiro/specs/ward-app/tasks.md`. Work that started from a spec arrived with its acceptance criteria and tests already written. Unspecced work needed a review pass to find what was missing. The cost of a spec is the writing time up front, and for small UI tweaks we skipped it.

## Steering

**Files.** `project.md` (always on), seven auto-included files (`darwin-c-interop`, `log-stream-parsing`, `macos-security-boundaries`, `swift-coding-standards`, `swift-memory-safety`, `swiftui-hud-design`, `testing-strategy`), and one manual file (`darwin-mcp-usage`).

**Strategy.** Every steering rule that a machine can check is paired with a check:

| Steering rule | Check that enforces it |
|---|---|
| No force-unwrap, files near 300 lines, `///` docs | Swift Standards Lint hook |
| Castle Keep palette and UI copy | Palette Check hook |
| Panel must be non-activating and floating | Security Boundary Guard hook and `FortressHUDWindowTests` |
| No direct TCC database reads, no restricted entitlements, no SIP bypass | Security Boundary Guard hook |
| Safe raw-pointer use in the `KERN_PROCARGS2` parser | Raw Pointer Safety Review hook and the parser property tests |
| Property tests on both parsers | `testing-strategy` and the PBT suites |

We think this pairing made the biggest difference: steering tells Kiro the rule, and the hook or test tells both of us when it is broken. The security steering also encodes the product's central design decision, "we inform, we don't intercept", so generated code stays inside it.

## MCP

We wrote one server, `darwin-tcc-docs` (`.kiro/tools/mcp_darwin_server.py`), from its own spec (`darwin-tcc-mcp-server`, all tasks ticked). It exposes `search_darwin_headers`, `get_darwin_struct` and `lookup_tcc_service`. It reads the installed macOS SDK headers and a TCC service-key registry, so Kiro can check a `KERN_PROCARGS2` constant, a `proc_pidinfo` flavour or a `kTCCService*` name against the real SDK instead of recalling it from memory. The `darwin-mcp-usage` steering file says to call it before writing code that touches those APIs.

This mattered because the project's core code is C-level interop, where a wrong constant or struct offset fails silently. The server has 55 passing tests (1 skipped). To run it, follow the README section "Optional: the Darwin docs MCP server". We have no log of a specific bug the server prevented, so we describe its role as a lookup safeguard, not a measured saving.

## Property-based testing

**What we enabled it for.**
- The `KERN_PROCARGS2` buffer parser (`ParseProcArgsBufferTests`): random byte buffers must never crash the parser.
- The `log stream` NDJSON parser (`TCCEventParserTests`): random strings must never crash it. A random-chunking test checks the stream pipeline.
- HUD placement geometry and alert matching (`PlacementCalculatorPropertyTests`, `AlertMatcherPropertyTests`).
- In Python, Hypothesis covers the MCP server and the capture framework's TCC snapshot code.

**What it caught.** The clearest catches came from Hypothesis on the capture framework (devlog 2026-11-22 21:55 UTC). `INSERT OR REPLACE` silently replaced stored NULLs with column defaults. `cell_literal` mishandled empty blobs, empty text and int64 limits. The service-prefix mapping could double the `kTCCService` prefix.

**Limits.** The Swift tests use a hand-written seeded random generator. They do not shrink failing inputs, and one short-buffer test (`tooShortBufferReturnsNil`) is unseeded. For the two Swift parsers, the devlog does not record a bug that property testing found. Their value so far is a guarantee that arbitrary bytes and strings cannot crash the inspector or the log pipeline.

## Kiro powers and third-party tools

We installed the `swift-expert` power and used it to audit the whole package (devlog 2026-11-12). Following its "read the build settings first" rule showed the package was in Swift 5 mode with no strict concurrency. We moved to Swift 6 language mode with `StrictConcurrency=complete` in three steps (targeted, complete, Swift 6), running tests after each. It found a main-actor call inside a nonisolated SIGTERM handler, non-`Sendable` globals in `WardTrigger`, and an unsafe test helper. It also cleared one suspected main-thread problem in `ProcessInspector`. Where its general guide differed from our project steering, our steering won.

Third-party tooling outside Kiro: Hypothesis and pytest (Python tests), the Python `mcp` SDK, and Remotion for the demo video draft. The Swift app itself has no external dependencies.

## Experimentation and course corrections

- **macOS 27 changed the TCC log shape.** The prompt line names only the responsible app, and the child's PID is in an earlier attribution line. We added `TCCRequestCorrelator` and a new parser pattern (devlog 2026-11-08).
- **First live test, four fixes.** The menu bar icon was too fine at real size, the alert pulse needed redesign, the command box cut off at two lines, and service keys meant nothing to people. Each became a spec task (devlog 2026-11-10).
- **A measurement we could not take.** The TCC snapshot design assumed a per-user TCC database. On macOS 27.2.1 it does not exist, so the design was changed and the finding recorded (devlog 2026-11-22).
- **A capture scenario that raised no prompt.** `ls` on a single file and on `~/.aws` do not trigger TCC, so the risk-tag scenario was rebuilt around `wc -c` on a file in a protected folder (devlog 2026-11-23 13:05 UTC).
- **Hook format.** Our first hook files used a custom schema the IDE did not load. We rewrote them and later standardized them again (see the note under Agent hooks).
- **Scoring loop.** The review prompt was re-run after each milestone, and the score history in git is the record of what was missing at each point.
