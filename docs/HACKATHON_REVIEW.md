# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-23 (UTC)
Days until deadline (Dec 4, 2026 2:00 PM PT): 11

Scope: `main` at `f65aad6`, in sync with `origin/main`. Verified in this run: `swift build` completes (only Sendable warnings in `WardTrigger`), `swift test` passes (169 tests in 23 suites), `gh repo view` reports PUBLIC with `apache-2.0` detected, `git ls-files .kiro` lists the committed tree. Not verified: the video on YouTube (none exists), that the hooks fire inside Kiro IDE, behavior on any macOS other than 27.x.

## Overall Score: 37/50

| Criterion | Score |
|---|---|
| Potential Impact | 8 |
| Technological Implementation | 8.5 |
| Design | 8 |
| Innovation / Idea | 8 |
| Presentation | 4.5 |
| **Total** | **37 / 50** |

The product and the Kiro process are strong. The score is held down by submission artifacts that do not exist yet: a public YouTube link, a Kiro write-up, Devpost text, and the blog and social posts.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: **Frankenstein**. `sysctl(KERN_PROCARGS2)` and `proc_pidinfo` (decades-old POSIX and Darwin APIs), Unified Log NDJSON streaming, SwiftUI/AppKit, and current agentic-IDE workflows are stitched into one tool, and the README and `docs/pitch.md` say so. Costume Contest would also fit the Castle Keep UI, but Frankenstein is the stronger story. Kiro use is broad and visible in git (7 specs, 9 steering files, 6 hooks, a custom MCP server, a power, a review prompt), so the "insufficient use of Kiro" risk is low. It drops further once a write-up exists.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `visibility: PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License at root, detected by GitHub | Pass | `licenseInfo.key: apache-2.0`; stock `LICENSE` (11,358 bytes), copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro`: 6 hooks, `prompts/`, `settings/mcp.json`, 7 spec folders, 9 steering files, MCP server source and tests. `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, build and run instructions | Pass, with gaps | README Quick Start: `swift build`, `swift test`, `scripts/run_ward.sh`. `swift build` and `swift test` succeed here. No clean-Mac first-run section. MCP venv setup now documented in the README (section "Optional: the Darwin docs MCP server") |
| Built in Submission Period | Pass | First commit 2026-11-05, 56 commits (45 iolaire, 11 Dharshaneshwaran), none before Oct 30. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Tests pass. Real captures in `docs/demo/assets/deepseek-harness/` and `qoder/`. Only macOS 27.x is evidenced; README claims macOS 13+. `ward-app/tasks.md` has 5 unchecked tasks and `hud-plain-language-copy/tasks.md` has 1 |
| Demo video: under 3 min, public YouTube, on a Mac, no copyrighted music or third-party trademarks | **Not met yet** | `docs/demo/remotion/out/gatekeepers-ward-demo.mp4` is 2:30 and `...-draft.mp4` is 2:53, both under 3:00. Narration is macOS `say` and no music is used. No YouTube URL exists anywhere. The video shows "DeepSeek Harness" and "Qoder" windows; the team treats these as brief nominative samples with a disclaimer (README, `NOTICE`, `docs/ai-asset-licensing.md`). Add the same line to the video end card |
| Text description of features | Partly | README covers features well. No Devpost text drafted in the repo |
| Write-up on how Kiro was used | Pass (repo) | `docs/KIRO_USAGE.md` answers each question in the rules, linked from the README. It still needs to be pasted into or linked from the Devpost form |
| Category selected | Pass | Frankenstein, reasoned in README, `docs/pitch.md`, devlog 2026-11-09 |
| Team of 3 or fewer, one Representative | Pass | 2 members; Representative Iolaire McFadden (README). Must match the Devpost form |
| English | Pass | All materials in English |
| Third-party IP, dependencies licensed | Pass, with items to confirm | No external Swift dependencies. Python deps (`mcp`, `pycparser`, `hypothesis`, `pytest`) are permissive. AI art provenance in `docs/ai-asset-licensing.md`. Third-party names covered by the disclaimer above |

## Stage Two Scoring

### Potential Impact (8/10)

**Justification.** The problem is specific and real: a TCC prompt names the app and not the command. The pipeline is complete: `TCCWatcher` streams `log stream`, `TCCEventParser` and `TCCRequestCorrelator` attribute the prompt to a PID, `ProcessInspector` reads argv, cwd and lineage, a risk tagger flags risky arguments, and the HUD shows the result. README "Why Gatekeeper's Ward Matters" has same-machine before/after captures with real values, plus cited public concern about agents and file access. The limit ("we inform, we don't intercept") is stated plainly, and the Little Snitch / Santa / Objective-See comparison is fair. Reduce Motion is honored in `GateBanner.swift`, and VoiceOver labels are tested in `HUDSectionTests`.

**Strengths**
- Real third-party agent captures (DeepSeek Harness, Qoder), not only the WardTrigger harness.
- Honest limits and a clear audience (developers using agentic IDEs).
- Accessibility is built in and tested.

**Areas for improvement** (ranked by points per hour)
1. Add a "clean Mac" section: toolchain, `scripts/run_ward.sh`, first launch, what to expect. About 1 hour, +0.5.
2. Put "verified on macOS 27.x" next to the "macOS 13+" claim, or test one older Mac. 15 minutes for the honest line.
3. The Qoder capture shows `swift-frontend -interpret`, not a readable command. Keep the DeepSeek risk-tag capture as the headline and say why Qoder differs. 15 minutes.
4. Replace or footnote personal paths (`/Users/iolaire/Desktop`, `/Volumes/Gold/...`). 15 minutes.

### Technological Implementation (8.5/10)

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes, 7 | `.kiro/specs/{ward-trigger,ward-app,castle-keep-visual-theme,hud-placement-and-menubar-theme,hud-plain-language-copy,permission-capture-framework,darwin-tcc-mcp-server}`, each with requirements, design, tasks. 295 of 301 tasks ticked. Specs map to commits (`d46f055` ward-app spec; `a63efa2` plain-language spec, then `e17fdc1` and `2c548c5` implementation) | `ward-app` has 5 unticked lines (one deferred follow-up group, reasons recorded); `hud-plain-language-copy` is complete. Spec-vs-vibe observation is in `docs/KIRO_USAGE.md` |
| Steering | Yes, 9 | `.kiro/steering/` covers Darwin interop, memory safety, log parsing, security boundaries, HUD design, testing, coding standards, MCP usage. Visible effect: no force-unwraps found in `GatekeepersWard/`, largest file 301 lines, `///` docs present, `NSPanel` non-activating test passes | Inclusion modes (always, fileMatch, manual) are not described anywhere |
| Hooks | Yes, 6 | `.kiro/hooks/*.json`: build-test gate (PostTaskExec), palette check and standards lint (PostFileSave, command), raw-pointer review (PostFileSave, agent), security guard (PreToolUse, agent), spec-first nudge (UserPromptSubmit, agent). Scripts in `scripts/hooks/`. The spec-first nudge and the security guard both fired during this review session | No log or devlog entry showing a file-save hook catching a real problem. The security guard's description still carries a "Migration note: confirm it covers the tools you meant" |
| MCP | Yes, 1 custom | `.kiro/tools/mcp_darwin_server.py` with header search, struct parser, TCC service registry, 6 Python test files; `darwin-tcc-docs` in `.kiro/settings/mcp.json` | Story of what it changed in the Swift code is thin. venv setup is missing from the README, so judges cannot start it |
| Property-based testing | Yes, partly | Seeded random-input tests on the `KERN_PROCARGS2` parser (`ParseProcArgsBufferTests`) and the NDJSON parser (`TCCEventParserTests`), plus placement and alert-matching properties. Python side uses Hypothesis. Devlog records bugs found (badge placement, `kTCCService` prefix) | The Swift tests use a hand-rolled seeded RNG, with no shrinking and no PBT library. A judge may read them as randomized unit tests. `tooShortBufferReturnsNil` (line 46 of `ParseProcArgsBufferTests.swift`) uses an unseeded `UInt8.random`, so it is not reproducible |
| Powers | Yes, 1 | `swift-expert` installed and used for the Swift 6 migration; devlog 2026-11-12 lists three concrete findings | No screenshot or quote of the power's output in the README |
| Custom agents | No | None in `.kiro/` | Skip unless a quick one is real |
| Kiro IDE vs CLI vs Crew | Mentioned | Devlog notes a Kiro CLI session in Zed, and hooks exist in IDE format plus CLI scripts | No comparison written |
| Experimentation | Yes | Devlog covers capture-framework measurements that were not taken, Gemini art licensing checks, the macOS 27 log format fix, "First live test, four fixes" | Not summarized for a judge |
| Prompts | Yes | `.kiro/prompts/code-review-hackathon.md` drives this review; earlier review scores are recorded in git (30, 32, 33, 34, 36) | Good evidence of iterative self-review. Mention it in the write-up |

**Strengths**
- Specs, steering, hooks, MCP and a power all appear, and each ties to code or commits.
- Steering is enforced mechanically (lint script, palette check, security guard), not only written down.
- 169 tests pass, and the PBT requirement in the project rules is met in spirit.

**Areas for improvement**
1. Write the Kiro write-up (`docs/KIRO_USAGE.md` or the Devpost field). Answer each rules question in two or three sentences with a file path. About 1.5 hours, +1 to +1.5. This is the largest single gain.
2. Seed the unseeded random test at `ParseProcArgsBufferTests.swift:46`, and either add a shrinking PBT library (SwiftCheck) or say plainly that the Swift tests use seeded generators. 30 to 60 minutes, +0.25.
3. Add the MCP venv setup to the README Quick Start (3 commands), and one paragraph on what the MCP server answered during development. 20 minutes, +0.25.
4. ~~Close or annotate the 6 open tasks.~~ Done: 1 ticked, the rest annotated as deferred.
5. Record one hook catching a real problem (screenshot or devlog line). 20 minutes.

### Design (8/10)

**Justification.** The experience is coherent: a menu bar ghost with idle and alert states, a "not watching" badge when the watcher cannot run (devlog 2026-11-10), a floating HUD placed beside Apple's alert via `AlertLocator` with a top-right fallback, plain-language banner copy, and risk reasons in everyday language. `FortressHUDWindowTests` confirms the panel is non-activating, floating and never key or main, so Apple's dialog keeps focus. The Castle Keep palette is enforced by a hook that flags off-palette hex values. The theme explains the function (lineage tree, spirits per process) instead of hiding it. Art is a polished vector set (`HUD/Art/`).

**Strengths**
- Focus safety is tested, not just claimed.
- Graceful states: watcher off, process already exited, alert not found.
- Theme and plain-language copy coexist; the `hud-plain-language-copy` spec exists because of a usability finding.

**Areas for improvement**
1. Show the error and "process exited" states in a screenshot or in the video, since judges mostly see what is shown. 30 minutes, +0.25.
2. `docs/screenshots/` holds one image. Add 2 or 3 (idle ghost, risk-tagged HUD, not-watching badge) to the README. 30 minutes, +0.25.
3. Placement relies on macOS 27.x window owner and layer names (devlog 2026-11-09); say so in the README known limits. 10 minutes.

### Innovation / Idea (8/10)

**Justification.** The combination is unusual: reading `KERN_PROCARGS2` and the process tree while `tccd` holds the requesting thread, triggered by the TCC subsystem's own log lines, with no Endpoint Security, no system extension, no SIP change and no restricted entitlement (README "why this works in user space"). Existing tools are firewall-focused (Little Snitch), binary-authorization-focused (Santa) or manual (`log stream` by hand); none that the README names shows the command behind a TCC prompt. The idea targets a new problem (agent-driven prompts) at the right moment, and the "inform, don't intercept" stance is a deliberate design choice.

**Strengths**
- Zero-entitlement architecture is both novel and easy to explain.
- The pause-at-the-prompt insight removes the race that usually defeats short-lived command inspection.

**Areas for improvement**
1. State what the tool cannot see (for example a process that exits before the log line arrives, and the `swift -e` case) in one README paragraph. 15 minutes.
2. Lead the Devpost text with the pause insight, since it is the most original technical point. 15 minutes.

### Presentation (4.5/10)

**Justification.** Observable: a 2:30 Remotion video built from real captures, a timed voiceover script, a strong README with before/after tables, `docs/pitch.md`, and a public devlog. Not observable: a YouTube upload, a Devpost description, a Kiro write-up. A synthetic `say` voice and scripted scenes may read as less personal than a live screen recording, and the rules ask whether the video shows the project working end to end. The README itself calls the video a "scripted draft".

**Strengths**
- Copy is plain and specific; README leads with the problem and the audience.
- Real captures are used instead of mock-ups.

**Areas for improvement**
1. Upload the final video to YouTube as public, and add the link to the README. 30 minutes, +1.5 to +2 (it is a requirement and the base for this score).
2. Make sure the video includes a live segment: real TCC prompt and HUD side by side on one screen, then a short `.kiro` walkthrough (specs, steering, hooks, MCP). 2 to 3 hours, +1.
3. Draft the Devpost text (problem, audience, features, how Kiro was used), reusing README text. 1 hour, +0.5.
4. Put the third-party-names line on the end card. 5 minutes.
5. ~~Update the README test count~~ Done (169).

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs a public video and a top-10% overall score. Presentation must rise first |
| Bonus Blog Prize | Not yet | No post exists. `docs/pitch.md` plans a Dev.to post. Needs: public third-party post, stated as written for Kiroween 2026, published in the Submission Period, URL in the submission |
| Social Blitz Prize | Not yet | No post. Must start with `#KiroweenHackathon26`, share a favorite thing about Kiro and how it changed development, URL in the submission |
| Best Ghost of Kiroween Past | Unknown | Only if a team member registered for Kiroween 2025 (Devpost verifies). Nothing in the repo says either way |
| Best Student Project | Unknown | Only if every member is a student; README bios do not state student status. Needs LinkedIn, student emails, year, degree, school |
| Best Startup Project | No evidence | Only if a founder; needs LinkedIn and a startup website |
| Best Kiro Crew App | No | Needs a separate public repo for a Kiro Crew app created in the Submission Period; none exists |

A project wins one Overall or one Category prize, not both, but any number of bonus prizes.

## Summary

**Top Strengths:**
- A working, tested product: 169 passing tests, a Swift 6 strict-concurrency build, no force-unwraps in `GatekeepersWard/`, and a non-activating panel verified by a test.
- Broad, visible Kiro use that ties to commits: 7 specs, 9 steering files, 6 hooks, a custom MCP server, a power, and a recorded self-review loop.
- A clear problem, honest limits, and real before/after captures from third-party agents.
- Zero-entitlement architecture that is novel and easy to explain.

**Critical Issues (disqualification or major score risk):**
- No public YouTube demo video yet. It is a hard requirement, and Presentation is capped until it exists.
- ~~No Kiro usage write-up~~ Fixed: `docs/KIRO_USAGE.md`. Remaining: link it in the Devpost form.
- No Devpost text, blog post or social post in the repo.
- ~~Judges cannot start the MCP server from the README~~ Fixed: README now has an "Optional: the Darwin docs MCP server" section with venv setup, checked on a fresh venv (55 tests pass).

**Prioritized Recommendations (highest score gain per effort first):**
1. Upload the final video to YouTube (public), add the link to README and the Devpost form. 30 minutes.
2. ~~Write the Kiro usage write-up~~ Done (`docs/KIRO_USAGE.md`); paste or link it in Devpost.
3. Draft the Devpost text from README and `docs/pitch.md`. 1 hour.
4. Add a live side-by-side segment and a `.kiro` walkthrough to the video. 2 to 3 hours.
5. Publish the blog post (Dev.to) and the `#KiroweenHackathon26` post, then add both URLs. 1 to 2 hours, bonus prizes.
6. Add MCP venv steps and a clean-Mac section to the README; fix the 166 vs 169 count. 1 hour.
7. Seed the unseeded random test, tick or explain the 6 open tasks, and state the macOS 27.x-only verification. 1 hour.

**Hackathon Readiness:** Needs Work. The product is ready. The submission materials are not.
