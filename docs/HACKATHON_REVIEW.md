# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-09
Days until deadline (Dec 4, 2026 2:00 PM PT): 25

Scope note: reviewed at commit `82695ec` on local `main` (two unrelated docs files have uncommitted edits). That commit is not pushed yet, so GitHub still shows `6b86320`. Devpost pages return 403 to tooling, so the rules were read from `docs/Planning/HackathonDetails/Rules.md`. No demo video, Devpost text, blog post or social post exists yet. Those are scored on what is observable.

## Overall Score: 19/50 (current state, Phase 2 of 7 just starting)

This is a mid-project snapshot. The score is low because the product (inspector, watcher, HUD, menu bar) is not built yet, which is expected on day 5 of a 35-day window. Kiro usage is already strong and the hard-requirement blockers from the previous review (license detection, MIT/Apache mismatch) are fixed.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: Frankenstein. Darwin `sysctl`/`proc_pidinfo`, unified log streaming, SwiftUI/AppKit and AI-agent workflows are stitched into one tool, which fits "seemingly incompatible elements." Kiro use is substantial and visible in `.kiro/`. The README leans on "resurrecting 20-year-old POSIX APIs", which is a Resurrection pitch. Keep Frankenstein primary in the video and Devpost text.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License detected by GitHub | Pass | `gh repo view --json licenseInfo` returns `apache-2.0`. Fixed in `aa07d0e`; copyright now in `NOTICE`. Re-check after each LICENSE edit |
| `/.kiro` committed, not ignored | Pass | 46 tracked files; `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, run instructions | Partial | `swift build` succeeds, README documents build/test and the 11 WardTrigger subcommands. Product code is missing: `App/`, `HUD/`, `MenuBar/`, `Resources/` empty; `Core/` and `Permissions/` hold only the two parsers. Latest commit `82695ec` is local only: run `git push` so judges see it |
| Built in Submission Period | Pass | First commit 2026-11-05, 19 commits, all by `iolaire`. No pre-existing code to disclose |
| Runs as depicted | Not verifiable | README describes a HUD that does not exist yet |
| Demo video (<3 min, public YouTube) | Missing | Phase 6 |
| Text description | Missing | README covers part of it; Devpost text not written |
| Kiro write-up | Missing | Raw material exists in specs, steering, devlog |
| Category | Pass | Frankenstein |
| Team of 3 or fewer, one Representative | Pass (confirm) | 2 members. Confirm who is Representative. All commits are from one author, which is fine but Dharshaneshwaran's contribution is not visible in git |
| English | Pass | |
| Third-party IP | Pass (check) | Swift has no dependencies. Python MCP tool has `.kiro/tools/requirements.txt`; confirm licenses |

## Stage Two Scoring

### Potential Impact (5/10)
- **Strengths:** Real, relatable pain: opaque TCC prompts from AI agents with no indication of which command asked. The "we inform, we don't intercept" framing is honest. The process stays blocked in the process table during the prompt, so inspection is reliable. WardTrigger now fires 11 real prompts (Documents, Desktop, Downloads, Contacts, Calendar, Reminders, Photos, Microphone, Camera, Automation, Screen Recording), run by hand on a Mac, and `TCCService` has a named case for each (enforced by a test), so the demo can show services agents actually trip.
- **Gaps:** Nothing works end to end. `ProcArgsParser` (74 lines) and `TCCEventParser` (175 lines) are not called by anything. No first-run or permission guidance, no accessibility implementation.
- **Improve:** Land Phase 2 (inspector plus watcher printing real forensics for a real prompt). That alone should move this to 6 or 7.

### Technological Implementation (8/10)
Strongest area. `swift build` passes; `swift test` passed again at `82695ec` (27 tests, 3 suites) and `pytest` for the MCP server passed (55 passed, 1 skipped). The flaky failure noted earlier has not reproduced and is still unexplained.

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes | `.kiro/specs/ward-trigger/` (41/41 tasks done, including Requirement 13 added today for the expanded trigger set), `darwin-tcc-mcp-server/` (34 done, 2 open) | No spec for ProcessInspector, TCCWatcher, HUD or MenuBar. Write them before coding Phases 2 and 3 |
| Steering | Yes, strong | 9 files in `.kiro/steering/` (Darwin interop, memory safety, log parsing, security boundaries, HUD, testing, coding standards, MCP usage, project) with always and auto modes | Show 2 or 3 concrete cases where steering changed output |
| Hooks | Yes, 6 | `.kiro/hooks/`: `build-test-gate` (PostTaskExec), `swift-standards-lint` and `castle-keep-palette-check` (PostFileSave, backed by `scripts/hooks/*.sh`), `security-boundary-guard` (PreToolUse, asks before forbidden entitlements/APIs), `raw-pointer-review` (agent, PostFileSave on `Core/`), `spec-first-nudge` (UserPromptSubmit). Each maps to a steering file. Lint script passes on all 6 Swift files; guard and palette scripts verified on planted violations | Added in `6b86320` and not yet observed firing inside Kiro (payload shape assumed; scripts fall back to scanning the tree). Palette hook has nothing to check until `HUD/` exists. Capture a short clip or devlog entry of a hook catching a violation for the write-up |
| MCP | Yes, strong | Custom `darwin-tcc-docs` server in `.kiro/tools/` (header search, struct lookup, TCC registry) with Python tests, configured in `.kiro/settings/mcp.json` | Document concrete cases where it prevented a wrong struct layout or TCC service name. Config uses `.kiro/tools/.venv/bin/python`, which is gitignored; README needs venv setup steps for judges |
| Property-based testing | Yes | Swift Testing properties: argv round trip, parser never traps, buffer round trip, event extractor never traps, demo echo. Hypothesis on the Python side | Parsers not integrated yet. Report any real bug PBT found |
| Custom agents / powers | No | None in repo | Optional; state in the write-up why not |
| IDE vs CLI vs Web vs Crew | Not documented | | One paragraph in the write-up |
| Experimentation | Partial | `docs/devlog.md`, `PlanReview_20261106.md`, license fix commits | Log dead ends and course corrections |
| Required write-up | No | | Missing |

### Design (3/10)
- **Strengths:** The Castle Keep palette, UI copy ("Let Spirit Pass", "Lower Portcullis") and `NSPanel` non-activating rule are specified in `docs/Planning/Styles/` and `swiftui-hud-design.md`.
- **Gaps:** No implemented UI at all. No assets in `Resources/`, no ghost icon states, no empty/error/process-exited states built. Design is judged on a finished experience, so this stays low until Phase 3.
- **Improve:** Build the HUD against a fixture snapshot first so it can be styled before the live pipeline is ready.

### Innovation / Idea (7/10)
- **Strengths:** Distinct from Little Snitch, Santa and Objective-See: it explains a TCC prompt while it is pending, using only `sysctl`, `proc_pidinfo` and `log stream`. No SIP bypass, no kernel extension, no restricted entitlements. The gothic castle metaphor is coherent and memorable. The custom Darwin MCP server is an unusual Kiro angle.
- **Gaps:** Novelty is claimed in docs but not demonstrated. The `log stream` TCC wording varies across macOS versions; this needs to be proven on a real Mac.

### Presentation (1/10)
- No video, Devpost text, blog post or screenshots. The README is clear and well structured (83 lines, build/test commands) but has no GIF, no video link, and no Kiro write-up section.
- **Improve:** Storyboard exists in `docs/pitch.md`. Record rough footage as soon as Phase 3 works, not on Dec 1.

## Code Quality
- Matches standards: no force-unwraps found in `GatekeepersWard/` or `WardTrigger/`, all files under 180 lines, small value-type parsers.
- Build warning: `GatekeepersWardTests/WardTrigger/README.md` is an unhandled resource in `Package.swift`. Exclude it.
- No secrets or large binaries tracked; `.build/` is ignored.
- Not yet testable: graceful degradation when a process has exited, and regex fallback in a live pipeline.

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs a strong video and top 10% overall score |
| Bonus Blog Prize | Possible | Public third-party post, published in the period, stating it was written for Kiroween 2026, URL in submission. Not written |
| Social Blitz | Possible | Post starting `#KiroweenHackathon26`, URL in submission. Not written |
| Best Ghost of Kiroween Past | Unknown | Only if a team member registered for Kiroween 2025 |
| Best Student Project | Unknown | Only if all members are students; needs LinkedIn, emails, school details |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup site |
| Best Kiro Crew App | No | Needs a separate public repo created in the period |

A project can win one Overall or Category prize, but any number of bonus prizes.

## Summary

**Top Strengths:**
- Real, well-framed problem with an honest scope
- Deep Kiro use: 2 specs, 9 steering files, a custom MCP server, 6 hooks tied to steering, and property-based tests
- Clean hard-requirement hygiene: public repo, Apache 2.0 detected, `.kiro` committed, builds and tests green
- Coherent theme and palette documented

**Critical Issues (disqualification or major score risk):**
- Product is unbuilt (inspector, watcher, HUD, menu bar). Everything in Impact, Design and Presentation depends on it
- No demo video, Devpost text or Kiro write-up yet (all required)
- No specs for the main app, which weakens the spec-driven story
- MCP config depends on a gitignored venv; judges cannot run it without setup steps

**Prioritized Recommendations (highest score gain per effort first):**
1. Write specs for ProcessInspector and TCCWatcher, then implement Phase 2 with real console output (Impact, Tech)
2. Build the HUD and menu bar ghost (Design, Impact, Presentation)
3. Add README venv setup for the MCP server, and a Kiro usage section with steering/MCP/PBT examples (Tech)
4. Record one real hook catch (e.g. security guard prompt) for the video and write-up (Tech, cheap)
5. Record the demo video once Phase 3 works; keep it under 3:00 and show the real TCC prompt beside the HUD (Presentation)
6. Publish a blog post and a `#KiroweenHackathon26` post (bonus prizes)
7. Exclude the stray README from `Package.swift` and investigate the earlier flaky test (polish)
8. Push `main` (or open a PR from `feature/expand-ward-trigger`) so the public repo matches the review, and add a 2026-11-09 devlog entry: it still describes the old `tmp/` relay and has nothing on the eight new triggers (Tech, minutes)

**Hackathon Readiness:** Needs Work
