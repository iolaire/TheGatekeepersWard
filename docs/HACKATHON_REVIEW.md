# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-09
Days until deadline (Dec 4, 2026 2:00 PM PT): 25

Scope note: reviewed at commit `f2c2567` on `main`, which matches `origin/main` (`git status -sb` shows no ahead/behind, working tree clean). Devpost pages return 403 to tooling, so the rules were read from `docs/Planning/HackathonDetails/Rules.md`. I did not run the app or fire a real TCC prompt in this review. Runtime behavior is taken from the spec's manual-verification tasks (ward-app tasks 7.1 to 7.5, ticked) and the devlog. No demo video, Devpost text, blog post or social post exists yet; those are scored on what is observable.

## Overall Score: 30/50

This replaces the earlier 19/50 snapshot. That review ran against local `main` before Dharshaneshwaran's `dev` branch (inspector, watcher, HUD, menu bar) was merged. The product now exists and the Kiro story is strong. The remaining gap is almost entirely submission material: video, write-up, screenshots, posts.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: Frankenstein. Darwin `sysctl`/`proc_pidinfo`, unified log streaming, SwiftUI/AppKit and AI-agent workflows are stitched into one tool, which fits "seemingly incompatible elements." Kiro use is substantial and visible in `.kiro/` (3 specs, 9 steering files, 6 hooks, custom MCP server). The README also leans on "resurrecting 20-year-old POSIX APIs", which reads as a Resurrection pitch. Keep Frankenstein primary in the video and Devpost text. The devlog lists Costume Contest as secondary, so decide before submitting: Devpost allows one category.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License detected by GitHub | Pass | `gh repo view --json licenseInfo` returns `apache-2.0`; `LICENSE` (11,358 bytes) at root, copyright in `NOTICE`. The About-sidebar display itself was not checked in a browser |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro` lists specs, steering, hooks, settings, prompts and tools. `.gitignore` excludes only `.kiro/sessions/`, `.kiro/tools/.venv/`, caches |
| Source, assets, run instructions | Pass with gaps | `swift build` completes (one warning: unhandled `GatekeepersWardTests/WardTrigger/README.md`). `swift test`: 81 tests, 11 suites, pass. README has `scripts/run_ward.sh` and WardTrigger steps. `GatekeepersWard/Resources/` is empty (ghost drawn in code via `GhostIcon.swift`). The MCP server needs a gitignored venv; setup is in `.kiro/tools/README.md` but not in the root README |
| Built in Submission Period | Pass | First commit 2026-11-05 (`70a9194`), 27 commits, none before Oct 30. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Build and tests verified here. HUD beside Apple's dialog is claimed by ticked tasks 7.1 to 7.5; not re-run by me. Tasks 7.6 and 8.10 (record macOS version, concurrent prompts, quit cleanup) are still open |
| Demo video (<3 min, public YouTube) | Missing | Phase 6 |
| Text description | Missing | README covers most of it; Devpost text not written |
| Kiro write-up | Missing | Raw material is in specs, steering, hooks, devlog |
| Category | Pass | Frankenstein |
| Team of 3 or fewer, one Representative | Pass (confirm) | 2 members. `git shortlog`: iolaire 22, Dharshaneshwaran 5. Confirm who is Representative |
| English | Pass | |
| Third-party IP | Pass (check) | Swift package has no dependencies. Python MCP tool has `.kiro/tools/requirements.txt`; confirm the licenses. No third-party trademarks in the repo, but emoji and "Cursor"/"Claude Code" names appear in README copy: keep them out of the video's visuals |

## Stage Two Scoring

### Potential Impact (7/10)
- **Justification:** The pain is real and easy to explain: AI agents trigger opaque TCC prompts and users cannot tell which command asked. The pipeline now exists: `TCCWatcher.swift` (222 lines) streams `log stream`, `TCCEventParser` and `TCCRequestCorrelator` match prompts, `ProcessInspector` (149 lines) reads argv/cwd/lineage, `RiskTagger` flags suspicious arguments, `FortressHUDView` shows them. WardTrigger fires 11 real prompts, and the HUD has named vault copy for each service.
- **Strengths:** Honest scope ("we inform, we don't intercept"). Zero entitlements. Accessibility basics are present: reduce-motion handling in `FortressHUDWindow.swift`, `accessibilityLabel` in `FortressHUDView.swift` and `MenuBarController.swift`. Concurrency, timeout and restart-backoff are handled in `PromptTracker`.
- **Gaps:**
  - Only tested against WardTrigger. Task 4 in the plan (real agent testing with Cursor or Claude Code) has no recorded result.
  - Legacy-wording prompts (macOS 13/14, no `msgID`) have no captured log sample and only the 30 s timer ends them (task 8.3). The "macOS 13+" claim is not backed by evidence.
  - Single-screen placement only (task 8.7); log-stream failure has no visible UI state (8.5b).
  - No install story beyond building from source, and no first-run guidance.
- **Improve:** Capture one real run with a real agent, record the macOS version, and show it. That moves this to 8.

### Technological Implementation (8/10)
Strongest area. `swift build` passes, `swift test` passes (81 tests including 5 property-based suites), and `pytest` for the MCP server passes (55 passed, 1 skipped). The spec-first workflow is visibly real: the missing `ward-app` spec was caught in review, written (13 requirements, design, tasks), and the review findings were recorded as open follow-ups (tasks.md section 8).

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes | `ward-trigger` (Requirement 13 added before code), `darwin-tcc-mcp-server`, `ward-app` (35 tasks done, 9 open) | `ward-app` spec was written after the code landed, not before. Say so honestly; the story is "spec added at integration, then drove follow-ups". Spec vs vibe comparison is not written down |
| Steering | Yes, strong | 9 files in `.kiro/steering/` with always and auto modes (Darwin interop, memory safety, log parsing, security boundaries, HUD, testing, coding standards, MCP usage, project) | Show 2 or 3 concrete cases where steering changed output. The code does follow it: no force-unwraps, all files under 300 lines |
| Hooks | Yes, 6 | `build-test-gate` (PostTaskExec), `swift-standards-lint` and `castle-keep-palette-check` (PostFileSave, scripts in `scripts/hooks/`), `security-boundary-guard` (PreToolUse), `raw-pointer-review` (PostFileSave on `Core/`), `spec-first-nudge` (UserPromptSubmit). All 6 JSON files parse; matchers are valid | No evidence any hook has fired in Kiro. Palette hook now has `HUD/` files to check. Capture one catch for the video |
| MCP | Yes, strong | Custom `darwin-tcc-docs` server in `.kiro/tools/`, configured in `.kiro/settings/mcp.json`; tests pass | No documented case of it preventing a wrong struct layout or service name. Config depends on a gitignored venv; judges must run setup |
| Property-based testing | Yes | Swift Testing properties for `KERN_PROCARGS2` round trip and never-traps, NDJSON decode/encode, extractor never-traps, chunked-stream equivalence; Hypothesis in Python | No record that PBT found a real bug. If it did, write it up |
| Custom agents / powers | No | None in repo | State why not in the write-up |
| IDE vs CLI vs Web vs Crew | Not documented | | One paragraph |
| Experimentation | Good | `docs/devlog.md` (6 dated entries), `PlanReview_20261106.md`, license fix, relay removed from the launcher, macOS 27 `msgID` attribution fix (`8de0079`) | Add dead ends and course corrections in one place |
| Required write-up | No | | Missing |

### Design (6/10)
- **Justification:** A coherent product now exists: menu bar ghost with state (`GhostIcon.swift`, `MenuBarController.swift`), a floating HUD (`FortressHUDWindow.swift` uses `.nonactivatingPanel` per the steering), `CastlePalette.swift` tokens, `FlowLayout`, lineage and risk-tag views, themed copy and per-service vault names.
- **Strengths:** The theme carries function (spirit paused at the gate, crimson risk tags). Reduce-motion respected. Fade animation is gated.
- **Gaps:** I did not see the HUD running and the repo has no screenshots or GIFs, so polish is unverified. `Resources/` is empty. Open design decisions: the `#C7D2FE` secondary tone and emoji header (8.9). Error and empty states are partial (8.5b). No history view. Contrast and VoiceOver passes are untested.
- **Improve:** Take screenshots of each state (idle, alert, process exited, watcher failed), put them in the README, and fix whatever looks rough.

### Innovation / Idea (7/10)
- **Justification:** Different from Little Snitch, Santa and Objective-See: it explains a TCC prompt while it is pending, using only `sysctl`, `proc_pidinfo` and `log stream`, with no SIP bypass and no kernel extension. Pairing it with a custom Darwin-docs MCP server is an unusual Kiro angle. The castle metaphor is memorable.
- **Gaps:** The "blocked process stays inspectable" claim is the core insight, and it is not shown anywhere as evidence. A short capture of argv read during a live prompt would prove it. Cross-version log wording is unproven.

### Presentation (2/10)
- **Justification:** The README is clear and well structured (119 lines, ASCII HUD mock, build/run/test steps), and `docs/pitch.md` has a storyboard. There is no video, no screenshots or GIF, no Kiro section, no Devpost text.
- **Improve:** Record rough footage now. Add a "How we used Kiro" section to the README. Link the video once public.

## Code Quality
- No force-unwraps found in `GatekeepersWard/` or `GatekeepersWardApp/` (regex scan). Largest file is 222 lines (`TCCWatcher.swift`), well under the 300 limit. Parsers are small value types.
- Graceful degradation exists in `ProcessSnapshot`/`ProcessInspector` for exited processes (per the spec); regex fallback exists in `TCCEventParser`. I did not exercise either live.
- Build warning to fix: exclude `GatekeepersWardTests/WardTrigger/README.md` in `Package.swift`.
- Stale docs: the devlog's Day 5 entry says 70 tests and "Not pushed yet"; it is now 81 and pushed. README says 81, so the README is correct.
- No secrets or large binaries tracked (128 files). `.DS_Store` is ignored.

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs a strong video and top 10% overall score |
| Bonus Blog Prize | Possible | Public third-party post in the period, stating it was written for Kiroween 2026, URL in submission. Not written |
| Social Blitz | Possible | Post starting `#KiroweenHackathon26` with a favorite Kiro thing, URL in submission. Not written |
| Best Ghost of Kiroween Past | Unknown | Only if a member registered for Kiroween 2025 |
| Best Student Project | Unknown | Only if all members are students; needs LinkedIn, emails, school details |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup site |
| Best Kiro Crew App | No | Needs a separate public repo created in the period |

A project can win one Overall or Category prize, but any number of bonus prizes.

## Summary

**Top Strengths:**
- A real, relatable problem with honest scope, and a working pipeline from log stream to HUD
- Deep Kiro use: 3 specs, 9 steering files, 6 hooks, custom MCP server, 5 property-based suites
- Clean hard-requirement hygiene: public repo, Apache 2.0 detected, `.kiro` committed, `main` pushed, build and 81 tests green
- Code follows its own steering (no force-unwraps, small files, value types)
- Two contributors visible in history with a merge that kept authorship

**Critical Issues (disqualification or major score risk):**
- No demo video, Devpost text or Kiro write-up yet; all required
- No evidence of a real AI-agent run, only WardTrigger; cross-version (macOS 13/14) behavior is unproven
- No screenshots or GIFs anywhere, so Design and Presentation cannot be judged from the repo
- MCP config depends on a gitignored venv with setup only in `.kiro/tools/README.md`

**Prioritized Recommendations (highest score gain per effort first):**
1. Write the "How we used Kiro" section (README and Devpost): specs, steering, hooks, MCP, PBT, spec vs vibe, IDE vs CLI, why no powers or agents. Mostly assembling existing material (Tech, Presentation; about 1 hour)
2. Add screenshots or a GIF of the HUD for each state to the README (Design, Presentation; about 1 hour)
3. Run the HUD against a real agent (Cursor or Claude Code reading `~/Documents`) and record macOS version and outcome (tasks 7.6, 8.10) (Impact, Innovation; about 2 hours)
4. Capture one hook firing (security guard or lint catching a violation) and one MCP lookup that mattered, for the write-up and video (Tech; 30 minutes)
5. Record the demo video: problem, real prompt beside the HUD, `.kiro` walkthrough, under 3:00, no copyrighted music (Presentation; about 4 hours)
6. Add a root-README venv setup line for the MCP server; exclude the stray README in `Package.swift` (Tech polish; 10 minutes)
7. Close the open follow-ups that show on camera: 8.5b log-stream failure state, 8.9 palette decision (Design; about 2 hours)
8. Publish the blog post and a `#KiroweenHackathon26` post, add URLs to the submission (bonus prizes)
9. Refresh the devlog (test count, pushed state) and decide Frankenstein vs Costume Contest

**Hackathon Readiness:** Needs Work
