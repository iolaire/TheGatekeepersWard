# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-09
Days until deadline (Dec 4, 2026 2:00 PM PT): 25

Scope note: reviewed the repo as of commit `9a61bd8` plus uncommitted work (`ScoringWell.md`, `.kiro/prompts/`). The Devpost pages returned 403 to my tooling, so I used the repo's saved copies of the rules. No demo video, Devpost text, blog post, or social post exists yet, so those items are scored on what is observable (nothing).

## Overall Score: 18/50 (current state, Phase 1 of 7 complete)

This is a mid-project snapshot, not a final projection. The score is low mainly because the product (HUD, menu bar, ProcessInspector, TCCWatcher) does not exist yet, which is expected on day 4 of a 35-day window. The Kiro usage is already strong.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: Frankenstein. The stitch of Darwin `sysctl`/`proc_pidinfo`, unified log streaming, SwiftUI/AppKit and AI-agent workflows fits "seemingly incompatible elements." Kiro use is substantial and visible in `.kiro/`. Note: the README frames `KERN_PROCARGS2` as "resurrecting 20-year-old POSIX APIs," which is a Resurrection pitch. Keep the Frankenstein story primary and do not blur the two in the video.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view` reports `PUBLIC`; remote `github.com/iolaire/TheGatekeepersWard` |
| License detectable by GitHub | **FAIL** | `LICENSE` is Apache 2.0, but GitHub's detector returns key `other`, name "Other". The file has custom copyright/boilerplate lines appended after the appendix text, which breaks the match. The About sidebar will not show a license |
| License consistent across docs | **FAIL** | `LICENSE`, README, CONTRIBUTING, pitch say Apache 2.0; `.kiro/steering/project.md` and the older devlog entries say MIT |
| `/.kiro` committed, not gitignored | Pass | 40+ files tracked; `.gitignore` only excludes `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Repo has source, assets, instructions to run | Partial | `swift build` and `swift test` work. But the actual product (menu bar app, HUD, inspector, watcher) is not implemented; `App/`, `HUD/`, `MenuBar/`, `Resources/` are empty |
| Built during Submission Period (Oct 30 to Dec 4) | Pass | First commit 2026-11-05. Pre-existing code is not an issue |
| Runs as depicted in video/description | Not yet verifiable | README describes a HUD that is not built |
| Demo video (<3 min, public YouTube) | Missing | Not started (Phase 6) |
| Text description | Missing | Devpost text not written; README partially covers it |
| Kiro write-up | Missing | Not written. Raw material exists in specs, steering, devlog |
| Category selected | Pass | Frankenstein, stated in README |
| Team of 3 or fewer | Pass | 2 members; confirm a Representative is appointed |
| English | Pass | |
| Third-party IP/dependency licensing | Pass (check) | Swift side has no dependencies. Python MCP tool has `requirements.txt`; confirm those licenses and attribute them |

## Stage Two Scoring

### Potential Impact (5/10)

- **Strengths:** The problem is real and relatable: opaque TCC prompts triggered by AI agents, with no way to see which command asked. The README states it clearly. The honest "we inform, we don't intercept" framing is good. The design reasoning (the process is blocked in the process table while the prompt is open, so inspection is reliable) is sound.
- **Gaps:** Nothing is demonstrable end to end. `ProcArgsParser` and `TCCEventParser` exist (74 and 151 lines) but nothing calls them: no `ProcessInspector`, `TCCWatcher`, or UI. No first-run or permissions guidance, no accessibility plan beyond a steering doc. "Would someone actually use this" cannot be answered yet.
- **Improve:** Land Phase 2 (inspector plus watcher printing real forensics for a real prompt) as soon as possible; that alone moves this to 6 to 7.

### Technological Implementation (8/10)

- **Strengths:** This is the strongest area, with evidence for most features the rules list.
- **Gaps:** No write-up yet comparing spec-driven to vibe coding. Hook is thin. Custom agents, Kiro powers and CLI/Web/Crew comparison are not used or not documented. PBT currently covers only parsers that are not wired up.

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes | `.kiro/specs/ward-trigger/` (requirements, design, tasks; 33/33 tasks done) and `darwin-tcc-mcp-server/` (34 done, 2 open) | No spec yet for ProcessInspector, TCCWatcher, HUD, MenuBar. The main app has no spec, which hurts the "thoughtful strategy" story. Write these before coding Phases 2 and 3 |
| Steering | Yes, strong | 9 files in `.kiro/steering/`: project, Darwin C interop, memory safety, log-stream parsing, security boundaries, HUD design, testing, coding standards, MCP usage. Mixed inclusion modes (always and auto) | Show 2 or 3 concrete before/after examples where steering changed output |
| Hooks | Yes, minimal | `.kiro/hooks/build-test-gate.json` (PostTaskExec runs build and tests) plus a git pre-commit hook in `scripts/git-hooks/` | One hook. Add 1 or 2 more with distinct purposes (for example PostFileSave doc-comment/force-unwrap lint, or a steering-drift check) |
| MCP | Yes, strong | Custom `darwin-tcc-docs` server in `.kiro/tools/` (header search, struct lookup, TCC service registry) with its own spec and Python tests, wired via `.kiro/settings/mcp.json` | This is a standout. Document concrete cases where it prevented a wrong struct layout or TCC service name |
| Property-based testing | Yes | 5 properties in Swift Testing: argv round trip, parser never traps, buffer round trip, event extractor never traps, demo echo. Python side uses Hypothesis | Parsers are not integrated yet. Report any bug PBT found. Note: one run of `swift test` reported 1 failed issue, then 5 consecutive reruns passed. That indicates a flaky test or a property with an unseeded counterexample; find it |
| Custom agents / powers | No | None in repo | Optional. Say explicitly in the write-up why not |
| IDE vs CLI vs Web vs Crew | Unknown | Nothing documented | One paragraph in the write-up |
| Experimentation | Partial | `docs/devlog.md` with decisions; `PlanReview` doc | Devlog has only ~107 lines and the license note says reconciliation is pending. Log dead ends and course corrections |
| Required write-up | No | | Missing |

### Design (3/10)

- **Strengths:** Design intent is unusually well specified: Castle Keep palette tokens, UI copy ("Let Spirit Pass" / "Lower Portcullis"), non-activating `NSPanel` rule, ghost states, risk-tag logic, all in `swiftui-hud-design.md` and `docs/Planning/Styles/`. The README shows an ASCII mock.
- **Gaps:** There is no UI at all (`HUD/`, `MenuBar/`, `Resources/` are empty). Design is scored on delivered experience, not intent, so this cannot score higher until Phase 3 lands. No screenshots exist.
- **Improve:** Build the HUD early and iterate. Include idle, alert, process-exited, and error states. Check contrast and reduced motion.

### Innovation / Idea (7/10)

- **Strengths:** A distinctive angle: attribute TCC prompts to the actual agent child process with argv, cwd and lineage, using zero entitlements and no SIP bypass. The lore (castle, spirits, lantern) is memorable and ties to function. The custom Darwin/TCC MCP server is itself an unusual build-time tool.
- **Gaps:** Must differentiate explicitly from Little Snitch, Santa, and Objective-See tools in the pitch. Needs proof the unified-log approach works on real macOS TCC events across versions (Ventura/Sonoma/Sequoia); this is the biggest technical risk to the idea. The Frankenstein vs Resurrection framing needs tightening (see Stage One).

### Presentation (0/10)

- **Strengths:** README is clear and has personality; `docs/pitch.md` has a storyboard; `scripts/run_ward_trigger.sh` gives a repeatable demo trigger.
- **Gaps:** No video, no Devpost text, no screenshots/GIF, no blog or social post. Nothing to score yet.
- **Improve:** Plan the 3-minute video around the side-by-side moment (Apple's prompt plus the HUD). Record rough takes at the end of each phase so the final cut is not a Dec 3 scramble.

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Yes (automatic) | Needs a strong video and top-10% overall score |
| Bonus Blog Prize | Not yet | Public post on Dev.to/Medium etc., published by Dec 4, stating it was written for Kiroween 2026, URL in submission |
| Social Blitz Prize | Not yet | Post starting with `#KiroweenHackathon26`, your favorite thing about Kiro and how it changed your approach, URL in submission |
| Best Ghost of Kiroween Past | Unknown | Only if a team member registered for Kiroween 2025; confirm on the form |
| Best Student Project | Unknown | All members must be students, with LinkedIn, student email, year/degree, school |
| Best Startup Project | Unlikely | Founder, LinkedIn, startup site |
| Best Kiro Crew App | No | Would need a separate Kiro Crew repo built in the window |

Reminder: Kiro credits must be requested by Dec 1, 12:00 PM PT, and only one Overall or Category prize can be won.

## Summary

**Top Strengths:**
- Exceptional Kiro footprint for day 4: two complete specs, nine steering documents, a custom MCP server with tests, an active hook, and a pre-commit gate.
- PBT is in place on the two parsers the project says it needs, and `swift build`/`swift test` run cleanly.
- Clear problem statement, strong theme, and a coherent technical thesis (zero entitlements).
- WardTrigger test harness gives a repeatable, honest demo path.

**Critical Issues (disqualification or major score risk):**
- **License is not detected by GitHub** (`licenseInfo.key = other`). The rules require a license visible in the About section. Fix before anything else.
- **License inconsistency:** steering and old devlog say MIT; the repo is Apache 2.0.
- **The product is not built.** No inspector, watcher, HUD, or menu bar yet, and no spec for any of them. This drives the low Design, Impact, and Presentation scores.
- **Committed build artifacts:** 30 `__pycache__/*.pyc` files under `.kiro/tools/` are tracked. They are noise for judges reading `.kiro`.
- **One-off test failure** seen in `swift test` (1 issue, not reproducible in 5 reruns). A flaky test on the PBT suite is a credibility risk if it shows up during judging.
- No Kiro write-up, video, or Devpost text exists yet (expected at this stage, but all are mandatory).

**Prioritized Recommendations (highest score gain per effort first):**
1. Replace `LICENSE` with the unmodified Apache-2.0 text from choosealicense.com (or switch to MIT), push, and confirm GitHub's About sidebar shows the license. Put the copyright line in `NOTICE` or the README. Update `.kiro/steering/project.md` to match. (Minutes; avoids a disqualification risk.)
2. `git rm --cached` the `__pycache__` files and add `__pycache__/` and `*.pyc` to `.gitignore`. Keep `.kiro` itself tracked.
3. Write specs for ProcessInspector/TCCWatcher and for the HUD/MenuBar before coding them; this strengthens Technological Implementation and the spec-vs-vibe story.
4. Land Phase 2 and prove the `log stream` TCC wording on your actual macOS version with WardTrigger. This is the main technical risk and unlocks everything after it.
5. Reproduce and fix the flaky test (run `swift test` in a loop with output saved; check seeds on the property tests).
6. Add 1 or 2 more hooks with different triggers, and record in the devlog what each one caught.
7. Build the HUD and menu bar early; take screenshots at each milestone for the README, Devpost, and video.
8. Start the Kiro write-up now as a running section in `docs/devlog.md`, one entry per feature, so it is not written from memory on Dec 3.
9. Schedule the blog post and social post for the week of Nov 28 and the video recording for Dec 1 to 2, leaving two days of slack before the deadline.

**Hackathon Readiness:** Needs Work. On schedule for a Phase 1 finish, with the Kiro story ahead of the product. Fix the license first.
