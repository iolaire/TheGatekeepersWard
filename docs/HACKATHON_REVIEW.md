# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-22
Days until deadline (Dec 4, 2026 2:00 PM PT): 12

Scope: `main` at `3ca960a`. `git status -sb` shows `main...origin/main [ahead 1]`, so the latest commit (AI-art licensing docs) is **not pushed yet**. Reviewed on macOS 27.2.1 with Swift 6.4.2. Verified directly in this run: `gh repo view`, `git log`, `git ls-files .kiro`, `.gitignore`, `swift build` (passes), `swift test` (**166 tests in 23 suites passed**), force-unwrap scan, file-size scan, spec task counts, hook JSON and helper scripts. Not verified: the Python MCP suite, a live TCC prompt, and anything on macOS 13 to 26. No demo video, Devpost text, Kiro write-up, blog post or social post exists yet, so Presentation is scored on what is observable.

## Overall Score: 34/50

Up from 33/50 in the 2026-11-20 review. The code is in good shape and the Kiro usage is strong. The submission materials are the gap, and they are worth up to about 7 points.

| Criterion | Score |
|---|---|
| Potential Impact | 7 |
| Technological Implementation | 8.5 |
| Design | 8 |
| Innovation / Idea | 8 |
| Presentation | 2.5 |
| **Total** | **34 / 50** |

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: **Frankenstein**. README ("Hackathon Category") and `docs/pitch.md` both state it. The fit is genuine: 20-year-old POSIX `sysctl(KERN_PROCARGS2)`, Unified Log NDJSON streaming, SwiftUI/AppKit and AI coding-agent workflows are stitched into one tool. Kiro use is substantial and committed: 5 specs, 9 steering files, 6 hooks, a custom MCP server, a committed review prompt, and a documented `swift-expert` power workflow (devlog Day 8). Stage One disqualification risk for "insufficient use of Kiro" is low.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `visibility: PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License at root, detected by GitHub | Pass | `licenseInfo.key: apache-2.0`; `LICENSE` is the stock text (11,358 bytes), copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro` lists hooks, prompts, settings, 5 specs, 9 steering files, tools. `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, build and run instructions | Pass, with gaps | `swift build` succeeds; `swift test` passes 166 tests. README Quick Start lists `swift build`, `swift test`, `scripts/run_ward.sh`. Gaps: the MCP server needs a gitignored venv and README does not say how to create it (setup lives only in `.kiro/tools/README.md`); README does not name the Swift 6 toolchain's install path beyond "Xcode 16+"; the unpushed commit must be pushed |
| Built in Submission Period | Pass | First commit `70a9194` on 2026-11-05, 39 commits, none before Oct 30. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Build and tests pass here. Devlog records live runs on macOS 27 with WardTrigger and a Kiro CLI session. Open per `ward-app/tasks.md`: 5 unchecked tasks (including multi-display placement, concurrent prompts, and older-macOS wording). Nothing verified on macOS 13 to 26 |
| Demo video, under 3 min, public YouTube | **Missing** | No link in README, pitch or elsewhere. `docs/pitch.md` checklist item is unchecked. Plan schedules it Nov 28 to Dec 1 |
| Text description of features | **Missing** (partly covered) | README describes features well. No Devpost text drafted |
| Write-up on how Kiro was used | **Missing** | The raw material exists (specs, steering, hooks, MCP, PBT, power use in devlog) but is not assembled into answers to the rules' questions |
| Category selected | Pass | Frankenstein |
| Team of 3 or fewer, one Representative | Pass | 2 members; Representative is Iolaire McFadden (README "Team"). Must match the Devpost form |
| English | Pass | All materials in English |
| Third-party IP, dependencies licensed | Pass, one item to confirm | Swift package has no external dependencies. Python deps (`mcp`, `pycparser`, `hypothesis`, `pytest`) are permissive. AI art is disclosed in README and `docs/ai-asset-licensing.md`. The four Gemini mood-board JPGs (2.6 to 4.4 MB each) in `docs/Planning/Styles/` should be either kept with that disclosure or removed. No copyrighted music exists yet because no video exists |

## Stage Two Scoring

### Potential Impact (7/10)

**Justification.** The problem is real and specific: AI coding agents trigger opaque TCC prompts and the user cannot tell which command caused them. The pipeline is complete: `TCCWatcher` streams `log stream`, `TCCEventParser` and the correlator attribute the prompt to a PID, `ProcessInspector` reads argv, cwd and lineage, `RiskTagger` flags `.pem`, `.env`, `curl`, `base64`, and `FortressHUDView` shows it. Scope is honest ("we inform, we don't intercept"). No entitlements, no SIP bypass. A "not watching" badge covers the case where `log stream` fails.

**Strengths**
- Actionable forensics shown at the moment of decision.
- Handles concurrent prompts and finds Apple's dialog without Screen Recording or Accessibility permission.
- Reduce Motion is respected and the status badge has accessibility labels.

**Areas for improvement** (ranked by points per hour)
1. Record one real run with Cursor or Claude Code, not only WardTrigger. This is the strongest proof that the audience exists. About 2 hours; worth +1.
2. Add an "Install on a clean Mac" section: toolchain, first-run behavior, what the app asks for. About 1 hour; +0.5.
3. Capture one result on an older macOS (13 to 15), or state "verified on macOS 27 only" in the README. The "macOS 13+" target is currently unbacked. 1 hour for the honest statement.
4. Close multi-display and two-prompt tasks in `ward-app/tasks.md`. 2 hours.

### Technological Implementation (8.5/10)

**Justification.** This is the strongest criterion. Specs were written before code for `castle-keep-visual-theme` and `hud-placement-and-menubar-theme`, and after code for `ward-app`, which gives a real spec-first versus spec-later comparison. Steering visibly shaped the code: the scan found no force-unwraps in `GatekeepersWard/`, `GatekeepersWardApp/` or `WardTrigger/`, and the largest file is 301 lines against a 300-line standard. The `swift-expert` power drove a Swift 6 strict-concurrency migration with concrete findings (devlog Day 8).

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes, 5 | `ward-trigger` 41/41, `castle-keep-visual-theme` 39/39, `hud-placement-and-menubar-theme` 22/22, `darwin-tcc-mcp-server` 36/36, `ward-app` 39 done, 5 open. Each has requirements, design, tasks | No written spec-driven vs vibe comparison. `ward-app` has no `.config.kiro` |
| Steering | Yes, 9 files | 8 have `inclusion:` frontmatter (7 `auto`, `darwin-mcp-usage` `manual`); `project.md` has none (always included). Topics: Darwin interop, memory safety, TCC boundaries, log parsing, HUD design, testing | Write up 2 or 3 cases where steering changed the output |
| Hooks | Yes, 6 | `build-test-gate`, `castle-keep-palette-check`, `raw-pointer-review`, `security-boundary-guard`, `spec-first-nudge`, `swift-standards-lint`. Helper scripts exist in `scripts/hooks/`; opt-in `scripts/git-hooks/pre-commit` | No recorded instance of a hook catching something. No CI (`.github/` absent) |
| MCP | Yes | `darwin-tcc-docs` in `.kiro/settings/mcp.json`, with its own spec (36/36) and Python tests | Venv is gitignored and absent from root README. No documented case where it prevented a mistake |
| Property-based testing | Yes | 166 tests pass. Property suites cover the `KERN_PROCARGS2` buffer parser (`ParseProcArgsBufferTests`), the NDJSON parser (`TCCEventParserTests`, `TCCWatcherPipelineTests` with random chunking), placement and alert matching. Hypothesis on the Python side | No record that PBT found a real bug. If it did, write it up |
| Powers | Yes | `swift-expert`: settings audit, then `targeted`, `complete`, Swift 6 mode; found a main-actor bug, non-`Sendable` globals and a closure-capture bug | None |
| Custom agents | No | None in repo | State why not in the write-up |
| IDE vs CLI vs Web vs Crew | Not documented | Devlog mentions a Kiro CLI session in Zed | One paragraph on which surfaces were used and where each helped |
| Experimentation | Strong | Dated devlog with dead ends (window-title approach dropped for needing Screen Recording), live-test fix loop, macOS 27 `msgID` attribution fix `8de0079` | Collect in one section of the write-up |
| Required write-up | No | | Hard requirement, not started |

**Areas for improvement**
1. Write the Kiro write-up, answering each question in the rules. 2 to 3 hours; protects against a Stage One problem and lifts this score to 9+.
2. Add a minimal GitHub Actions workflow running `swift build` and `swift test` on a macOS runner. 30 minutes; shows the hooks idea enforced.
3. Show one hook firing on screen or in the devlog. 30 minutes.

### Design (8/10)

**Justification.** The product is a coherent experience, not a proof of concept: a menu bar ghost with idle and alert poses, a non-activating floating HUD placed beside Apple's dialog, vector spirit sprites per lineage node, risk legend, and distinct states (watching, not watching, process exited, concurrent prompts). Tests assert the panel never steals focus (`FortressHUDWindowTests`: style mask, level, key and main flags) and that copy avoids "Block" and "Banish" wording. The Castle Keep palette is enforced by a hook. The theme maps to function: lineage rows are spirits, the gate is the permission.

**Strengths**
- Palette and copy are applied consistently and checked by a hook and tests.
- The README shows a real screenshot (`docs/screenshots/Screenshot.png`).

**Areas for improvement**
1. Add 2 or 3 more screenshots or a GIF (alert state, risk-tagged command, "not watching"). 1 hour; +0.5 Design and Presentation.
2. Verify the open items in `ward-app/tasks.md` (multi-display, Spectral Ectoplasm secondary tone). 2 hours.
3. Hand-check contrast of body text on the frosted material.

### Innovation / Idea (8/10)

**Justification.** Little Snitch, Santa and Objective-See tools focus on network, binaries and persistence. None surface "which agent command is behind this TCC prompt" at the moment Apple's dialog is up. Combining `KERN_PROCARGS2`, `proc_pidinfo`, Unified Log streaming and a themed HUD, with zero entitlements, is a novel stitch and a clear Frankenstein fit. The insight that `tccd` blocks the child so `sysctl` is reliable during the prompt is a good one.

**Areas for improvement**
1. State the comparison to existing tools in one short table in the README or pitch. 30 minutes; +0.5.
2. Lead the video with the agent angle, not the ghost.

### Presentation (2.5/10)

**Justification.** The README is clear and has a screenshot, and the pitch doc has a storyboard, but the three artifacts judges weigh most do not exist: demo video, Devpost text and Kiro write-up. This is the largest score gap and the largest disqualification risk.

**Areas for improvement** (all ranked highest value first)
1. **Demo video, under 3:00, public on YouTube.** Suggested shape: 0:00 to 0:20 hook and problem; 0:20 to 1:30 live agent triggers a prompt with Apple's dialog and the HUD side by side; 1:30 to 2:20 `.kiro` walkthrough (specs, steering, hooks, MCP, PBT); 2:20 to 2:50 impact. Use no music or original music only. 4 to 6 hours; +4 to +5 points.
2. **Devpost text** (problem, audience, features, how Kiro was used). 2 hours; +1.
3. **README additions:** video link, an MCP setup note, and a short "Verified on" line.
4. Add a link from the README to the write-up.

## Code Quality

- Build passes; 166 tests pass.
- No force-unwraps found in production Swift directories. Largest file `GatekeepersWard/HUD/Art/GhostGeometry.swift` is 301 lines, `TCCWatcher.swift` 294.
- Graceful degradation is implemented and spec'd (process exited, regex fallback on `eventMessage`, restart backoff).
- Doc-comment coverage was not audited line by line. A hook checks it on save.
- No secrets found; `.gitignore` covers `*.pem`, `.env` and similar. Large binaries are the four mood-board JPGs plus screenshots.
- Test count in the README (166) now matches reality.

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs the video and a top 10% overall score |
| Bonus Blog Prize | Not yet | No post exists. Needs a public third-party post, published in the Submission Period, saying it was written for Kiroween 2026, URL in the submission |
| Social Blitz Prize | Not yet | No post. Must start with `#KiroweenHackathon26`, state a favorite thing about Kiro and how it changed development, URL in the submission |
| Best Ghost of Kiroween Past | Unknown | Applies only if a team member registered for Kiroween 2025; the team should confirm |
| Best Student Project | Unknown | Only if every member is a student; needs LinkedIn, student emails, year, degree, school |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup website |
| Best Kiro Crew App | No | Needs a separate public repo created in the Submission Period; none exists |

A project can win one Overall or Category prize, not both, but any number of bonus prizes.

## Summary

**Top Strengths:**
- Working end-to-end product that builds and passes 166 tests on this machine.
- Broad, specific Kiro use: 5 specs, 9 steering files, 6 hooks, custom MCP server, PBT, and the `swift-expert` power with real findings.
- Honest, zero-entitlement architecture and a theme that maps to function.
- Clean licensing and timeline: Apache 2.0 detected by GitHub, all commits inside the Submission Period.

**Critical Issues (disqualification or major score risk):**
- No demo video. A missing video is a disqualification risk and caps Presentation.
- No Kiro write-up and no Devpost text. Both are required submission items.
- The latest commit is unpushed (`main` is ahead by 1).
- "macOS 13+" is claimed but only macOS 27 was verified.
- The real-agent evidence is thin: no recorded Cursor or Claude Code run.

**Prioritized Recommendations (highest score gain per effort first):**
1. Push `main` now (1 minute).
2. Record and upload the demo video (4 to 6 hours; +4 to +5).
3. Write the Kiro write-up and Devpost text from the devlog, answering each question in the rules (3 to 4 hours; +1 to +1.5).
4. Capture one real Cursor or Claude Code run for the video (about 2 hours; +1 Impact).
5. Add a GitHub Actions macOS build and test workflow, and an MCP venv setup note in the README (45 minutes).
6. Publish a short blog post and a `#KiroweenHackathon26` social post for the two bonus prizes (1 to 2 hours; bonus only).
7. Add the existing-tools comparison table and two more screenshots (1.5 hours).
8. Replace the "macOS 13+" claim with "verified on macOS 27" unless an older Mac is available.

**Hackathon Readiness:** Needs Work. The product and Kiro usage are ready. The submission cannot be filed until the video, text description and write-up exist. At 12 days left, the plan in `docs/pitch.md` (video Nov 28 to Dec 1, submit by Dec 2) is feasible if it starts on schedule.
