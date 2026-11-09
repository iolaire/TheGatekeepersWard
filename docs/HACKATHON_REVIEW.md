# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-09
Days until deadline (Dec 4, 2026 2:00 PM PT): 25

Scope note: reviewed at commit `670cf4d` on `main`. `git status -sb` shows `main...origin/main` with nothing ahead or behind. The working tree has one uncommitted change, `docs/devlog.md` (not part of this review). Devpost pages return 403 to tooling, so the rules were read from `docs/Planning/HackathonDetails/Rules.md` and the saved review prompt. I ran `swift build`, `swift test` and the MCP server's `pytest` myself (macOS 27.0.1, Swift 6.4). I did not run the app, fire a real TCC prompt, or look at the GitHub About sidebar in a browser. Runtime behaviour is taken from the devlog and ticked spec tasks. No demo video, Devpost text, blog post or social post exists yet, so Presentation is scored on what is observable.

## Overall Score: 32/50

This replaces the 30/50 snapshot taken at `f2c2567`. Since then the HUD placement and menu bar theme spec landed (HUD opens beside Apple's alert, full-colour ghost) and the Swift test count went from 81 to 108. The product and the Kiro story are strong. The remaining gap is submission material: video, write-up, screenshots, posts, and one real-agent run on record.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: Frankenstein. Darwin `sysctl`/`proc_pidinfo`, unified log streaming, SwiftUI/AppKit and AI-agent workflows are stitched into one tool, which fits "seemingly incompatible elements." Kiro use is substantial and visible in `.kiro/`: 4 specs, 9 steering files, 6 hooks, a custom MCP server and a committed review prompt. `docs/devlog.md` and `docs/pitch.md` still list Costume Contest as a secondary target. Devpost takes one category, so pick Frankenstein and make the video and text say so.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `visibility: PUBLIC`, `https://github.com/iolaire/TheGatekeepersWard`, default branch `main` |
| License detected by GitHub | Pass (About sidebar not checked) | `gh repo view --json licenseInfo` returns key `apache-2.0`. `LICENSE` (11,358 bytes) at root, copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro` lists hooks, prompts, settings, specs, steering, tools. `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, run instructions | Pass with gaps | `swift build` completes; `swift test` passes. README Quick Start lists build, test, `scripts/run_ward.sh`, WardTrigger steps. `GatekeepersWard/Resources/` is empty (README still lists "Assets & gothic iconography"; the ghost is drawn in `GhostIcon.swift`). The MCP server needs a gitignored venv, documented in `.kiro/tools/README.md` but not in the root README. README says "81 tests"; the real count is 108 |
| Built in Submission Period | Pass | First commit 2026-11-05 (`70a9194`), 29 commits, none before Oct 30. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Build and tests verified here. HUD beside Apple's dialog is claimed in the devlog, but it says placement and the larger ghost are "not yet verified by eye on a real Mac". Spec tasks 7.6, 8.3, 8.4, 8.5b, 8.7, 8.9, 8.10 in `ward-app` are open |
| Demo video (<3 min, public YouTube) | Missing | Phase 6; nothing in repo or README links to one |
| Text description | Missing | README covers most of it; Devpost text not written |
| Kiro write-up | Missing | Raw material exists in specs, steering, hooks, devlog |
| Category | Pass | Frankenstein (decide against Costume Contest) |
| Team of 3 or fewer, one Representative | Pass (confirm) | 2 members. `git shortlog -sn`: iolaire 24 commits, Dharshaneshwaran 5. Representative not recorded anywhere I found |
| English | Pass | |
| Third-party IP | Pass (check) | Swift package has no external dependencies. The Python MCP tool has `.kiro/tools/requirements.txt`; confirm those licenses. README and mock text name Cursor and Claude Code and use emoji; keep third-party logos and trademarks out of the video visuals |

## Stage Two Scoring

### Potential Impact (7/10)
- **Justification:** The pain is real and easy to state: agents trigger opaque TCC prompts and the user cannot tell which command asked. The pipeline exists end to end: `TCCWatcher.swift` (222 lines) streams `log stream`, `TCCEventParser` and `TCCRequestCorrelator` match prompts and PIDs, `ProcessInspector` (149 lines) reads argv, cwd and lineage, `RiskTagger` flags suspicious arguments, and `FortressHUDView` presents them. WardTrigger fires 11 real prompts, and every service has its own vault copy in the HUD.
- **Strengths:** Honest scope ("we inform, we don't intercept"; HUD has no buttons). Zero entitlements. Accessibility basics: Reduce Motion handled in the HUD window, accessibility labels in `FortressHUDView.swift` and `MenuBarController.swift`. `AlertLocator` finds Apple's dialog without Screen Recording or Accessibility permission. `PromptTracker` handles concurrent prompts, and the watcher has restart backoff.
- **Gaps:**
  - Only exercised with WardTrigger and one Kiro CLI session in Zed (devlog, Day 4). No recorded run with Cursor or Claude Code.
  - Verified on macOS 27.0.1 only. The "macOS 13+" target is unbacked: no Ventura or Sonoma log capture exists (task 8.3), and the alert window owner name `UserNotificationCenter` is recorded for macOS 27 only.
  - Single-screen placement is unchecked on multi-display (8.7). No visible state when `log stream` cannot start (8.5b).
  - Install story is "build from source". No first-run guidance.
- **Improve:** Record one run with a real agent and its macOS version (task 7.6). That is about an hour and moves this to 8.

### Technological Implementation (8/10)
Strongest area. `swift build` passes. `swift test` passes: 108 tests in 17 suites. MCP server `pytest` passes: 55 passed, 1 skipped (venv present locally). Spec-first work is visible in the history: `ward-trigger` Requirement 13 was written before the code, `hud-placement-and-menubar-theme` was specced before commit `670cf4d`, and the missing `ward-app` spec was caught in review and written with review findings recorded as open tasks.

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes | 4 specs: `ward-trigger` (41/41 tasks), `darwin-tcc-mcp-server` (34 done, 2 open), `ward-app` (35 done, 9 open), `hud-placement-and-menubar-theme` (22/22). Requirements, design and tasks each | `ward-app` spec was written after the code landed (devlog says so). No written spec-driven vs vibe comparison. `ward-app` and `darwin-tcc-mcp-server` lack `.config.kiro` (minor) |
| Steering | Yes, strong | 9 files in `.kiro/steering/` (Darwin interop, memory safety, log parsing, security boundaries, HUD design, testing, coding standards, MCP usage, project) | Show 2 or 3 concrete cases where steering changed output. The code matches it: grep found no force-unwraps in `GatekeepersWard`, `GatekeepersWardApp` or `WardTrigger`; the largest file is 222 lines |
| Hooks | Yes, 6 | `build-test-gate` (PostTaskExec), `swift-standards-lint` and `castle-keep-palette-check` (PostFileSave), `raw-pointer-review` (PostFileSave on `Core/`), `security-boundary-guard` (PreToolUse), `spec-first-nudge` (UserPromptSubmit). All 6 JSON files parse with valid triggers and matchers; helper scripts in `scripts/hooks/` | I did not run them inside Kiro, so firing is unverified. No recorded case of a hook catching something. Capture one for the video |
| MCP | Yes, strong | Custom `darwin-tcc-docs` server in `.kiro/tools/`, configured in `.kiro/settings/mcp.json`; Hypothesis and pytest tests pass | No documented case of it preventing a wrong struct layout or service name. Config needs the gitignored venv, so judges must run setup |
| Property-based testing | Yes | Swift Testing property tests: `KERN_PROCARGS2` buffer parser, NDJSON decode/encode round trip, extractor never traps, chunked-stream equivalence, `PlacementCalculator`, `AlertMatcher`. Hypothesis on the Python side | No record that PBT found a real bug. If it did, write it up |
| Custom agents / powers | No | None in repo | State why not in the write-up |
| IDE vs CLI vs Web vs Crew | Not documented | Devlog mentions a Kiro CLI session in Zed and "pairing with Kiro" | One paragraph on what was used and where |
| Experimentation | Good | `docs/devlog.md` (dated entries with decisions), `PlanReview_20261106.md`, macOS 27 `msgID` attribution fix (`8de0079`), launcher relay removed, LICENSE fix (`aa07d0e`), flaky-test fix | Gather dead ends and course corrections in one place |
| Required write-up | No | | Missing |

### Design (7/10)
- **Justification:** There is a coherent product, not a proof of concept: a menu bar ghost with idle and alert poses (`GhostIcon.swift`, `MenuBarController.swift`), a non-activating floating HUD (`FortressHUDWindow.swift`, test "Panel never steals focus: style mask, level, key and main flags" passes), placement beside Apple's alert (`PlacementCalculator`, `AlertLocator`), a history of the last 10 spirits, and states for exited and denied processes.
- **Strengths:** Castle Keep palette is centralised in `CastlePalette.swift` and enforced by a hook. Theme copy ("Spirit Paused at the Gate", vault names) adds flavour while the facts (PID, path, argv, lineage, risk tags) stay legible. Pure, tested geometry for placement.
- **Gaps:**
  - HUD placement and the 22 pt ghost are not yet confirmed on a real screen (devlog says so).
  - Spectral Ectoplasm secondary tone and emoji header undecided (8.9).
  - No screenshot or GIF anywhere in the README. Judges cannot see the design without running it.
  - README mock shows a cursor/ripgrep example; make sure it matches what the HUD actually renders.
- **Improve:** Add 2 screenshots to the README and tidy the one-screen edge case.

### Innovation / Idea (8/10)
- **Justification:** Existing tools (Little Snitch, Santa, Objective-See utilities, hand-run `log stream`) either block or log at a system level. None that I know of correlates a TCC prompt to the exact child process, its argv and its lineage while the dialog is still on screen. That comparison is my own knowledge and was not checked against the web in this review.
- **Strengths:** Zero entitlements, no SIP bypass. The macOS 27 attribution work (`AUTHREQ_ATTRIBUTION` joined to `AUTHREQ_PROMPTING` by `msgID`) is original and reported honestly. The Frankenstein fit is genuine: 20-year-old `sysctl` plus unified log plus SwiftUI plus agent workflows. The gothic theme explains the function.
- **Gaps:** The novelty only lands if the video shows the real prompt and HUD side by side with a recognisable agent.

### Presentation (2/10)
- **Justification:** Observable material only. README is clear on problem, approach and run steps, but has no screenshot, no video link and a stale test count. No video, Devpost text, blog or social post exists. Devlog and pitch are good raw material (`docs/pitch.md` has a storyboard and a video checklist).
- **Strengths:** Strong story and a concrete demo path (`scripts/run_ward.sh`, then `scripts/run_ward_trigger.sh docs rg ...`).
- **Gaps:** Everything that is scored here: video under 3 minutes on YouTube, Kiro walkthrough, Devpost text.
- **Improve:** Script and record the video; this is the biggest available gain (up to 6 points).

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Not yet | Video must exist and the overall score must land in the top 10% |
| Bonus Blog Prize | Not yet | Public post on a third-party platform, published during the Submission Period, says it was written for Kiroween 2026, URL in the submission |
| Social Blitz Prize | Not yet | Public post that starts with `#KiroweenHackathon26`, shares a favourite thing about Kiro and how it changed development, URL in the submission |
| Best Ghost of Kiroween Past | Unknown | Needs a team member registered for Kiroween 2025 (Devpost verifies). Nothing in the repo says either way |
| Best Student Project | Unknown | Only if every member is a student; no evidence either way. Needs LinkedIn, student emails, year, degree, school |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup website. No evidence |
| Best Kiro Crew App | No | Needs a separate public GitHub repo for a Kiro Crew app created during the Submission Period; none exists |

A project can win one Overall or Category prize plus any number of bonus prizes.

## Summary

**Top Strengths:**
- Working end-to-end pipeline from TCC log event to process forensics to HUD, built with zero entitlements.
- 108 Swift tests (including property-based suites for the buffer and NDJSON parsers) and 55 Python tests pass; build is clean.
- Broad, real Kiro usage: 4 specs, 9 steering files, 6 valid hooks, a custom MCP server, and code that visibly follows the steering rules.
- Honest devlog that records dead ends, a macOS 27 log-format discovery and open follow-ups.
- Clear, defensible Frankenstein fit and a clear problem statement.

**Critical Issues (disqualification or major score risk):**
- No demo video, Devpost text or Kiro write-up yet. These are hard requirements and cover a whole scoring criterion.
- "Runs as depicted" is only partly verified: HUD placement and ghost size have not been checked by eye, and no run with a real coding agent is recorded.
- The macOS 13+ support claim has no evidence; only macOS 27.0.1 has been captured.
- No screenshot or GIF in the README.
- Team Representative and Costume Contest versus Frankenstein are undecided in the repo.

**Prioritized Recommendations (highest score gain per effort first):**
1. Script and record the demo video (under 3:00, public on YouTube): the real prompt and HUD side by side, a recognisable agent, a short `.kiro` walkthrough.
2. Write the Kiro write-up and Devpost text from the specs, steering, hooks, MCP server and devlog. Cover IDE vs CLI, spec-driven vs vibe, hooks, MCP, PBT, and say why no custom agents or powers.
3. Run a real agent (Cursor or Claude Code) against the HUD, tick `ward-app` 7.6 and 8.10, and log the macOS version. Add 2 screenshots or a GIF to the README.
4. Fix README drift: test count (108), the empty `Resources/` line, the MCP venv setup, and a link to the video once it exists. Add a "Known limits" note (tested on macOS 27.0.1 only).
5. Publish the blog post (written for Kiroween 2026) and the `#KiroweenHackathon26` social post for the bonus prizes. Capture one real hook catch and one case where the MCP server saved a mistake to strengthen the Technological Implementation story.

**Hackathon Readiness:** Needs Work
