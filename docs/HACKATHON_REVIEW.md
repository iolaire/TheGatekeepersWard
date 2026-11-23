# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-23 (UTC)
Days until deadline (Dec 4, 2026 2:00 PM PT): 11

Scope: local `main` at `82bfcca`, which is one commit ahead of `origin/main` (not pushed). Verified in this run: `swift test` passes (169 tests in 23 suites), `gh repo view` reports a PUBLIC repo with `apache-2.0` detected, `git ls-files .kiro` lists the committed `.kiro` tree. `swift build` was not re-run separately; the test run builds the package.

## Overall Score: 36/50

| Criterion | Score |
|---|---|
| Potential Impact | 7.5 |
| Technological Implementation | 8.5 |
| Design | 8 |
| Innovation / Idea | 8 |
| Presentation | 4 |
| **Total** | **36 / 50** |

Product and process are strong. The score is held down by missing submission artifacts: no public video link, no Devpost text, no Kiro write-up. A video draft now exists locally, which lifts Presentation by one point over the earlier review.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: **Frankenstein**. The fit is credible: 20-year-old POSIX APIs (`sysctl KERN_PROCARGS2`, `proc_pidinfo`), Unified Log NDJSON streaming, SwiftUI/AppKit, and current agentic-IDE workflows are stitched into one tool. Costume Contest would also fit (the Castle Keep UI), but Frankenstein is the better story. Kiro use is broad (specs, steering, hooks, MCP server, a power, PBT-style tests), so the "insufficient use of Kiro" risk is low once it is written up.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `visibility: PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License at root, detected by GitHub | Pass | `licenseInfo.key: apache-2.0`; stock `LICENSE` (11,358 bytes), copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro`: 6 hooks, `prompts/`, `settings/mcp.json`, 7 spec folders, 9 steering files, MCP server source and tests. `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, build and run instructions | Pass, with gaps | README Quick Start: `swift build`, `swift test`, `scripts/run_ward.sh`. No clean-Mac first-run section. MCP venv setup is not in the root README (venv is gitignored; see memory note on judges' setup) |
| Built in Submission Period | Pass | First commit 2026-11-05, 52 commits, none before Oct 30. Two authors. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Tests pass. Real before/after captures in `docs/demo/assets/deepseek-harness/` and `qoder/`. Only macOS 27.x is evidenced. `ward-app/tasks.md` has 5 unchecked tasks, `hud-plain-language-copy/tasks.md` has 1 |
| Demo video: under 3 min, public YouTube, on a Mac, no copyrighted music or third-party trademarks | **Missing** | Draft renders exist at `docs/demo/remotion/out/` (about 2:47, `say` narration). No YouTube link anywhere. The video shows "DeepSeek Harness" and "Qoder" windows and names. Team position: brief nominative samples, no claim of affiliation, so not treated as an issue (see note below the table) |
| Text description of features | Partly | README covers features well. No Devpost text drafted |
| Write-up on how Kiro was used | **Missing** | Raw material exists in `docs/devlog.md`, but no document answers the rules' questions |
| Category selected | Pass | Frankenstein, with reasoning in README and devlog 2026-11-09 |
| Team of 3 or fewer, one Representative | Pass | 2 members; Representative Iolaire McFadden. Must match the Devpost form |
| English | Pass | All materials in English |
| Third-party IP, dependencies licensed | Pass, with items to confirm | No external Swift dependencies. Python deps (`mcp`, `pycparser`, `hypothesis`, `pytest`) are permissive. AI art provenance in `docs/ai-asset-licensing.md`. Third-party app names in screenshots and video: see the note below the table |

**Note on third-party names in the video.** Rules section on the video requires that it "must not include third party trademarks, or copyrighted music or other material unless the Entrant has permission to use such material." The team's position is that the DeepSeek Harness and Qoder appearances are very short samples shown only to demonstrate the tool, with no claim of association. This review accepts that and does not count it as a critical issue. The rule text speaks of permission, not fair use, so the exposure is small but not zero. A one-line disclaimer in the README and the video end card ("Third-party product names appear only to show Gatekeeper's Ward working with them; no affiliation or endorsement") costs minutes and states the intent.

## Stage Two Scoring

### Potential Impact (7.5/10)

**Justification.** The problem is real and specific: TCC prompts name the app and say nothing about the command. The pipeline is complete: `TCCWatcher` (294 lines) streams `log stream`, `TCCEventParser` and `TCCRequestCorrelator` attribute the prompt to a PID, `ProcessInspector` reads argv, cwd and lineage, `RiskTagger` flags risky arguments, and the HUD shows the result. The README "Why Gatekeeper's Ward Matters" section has a same-machine before/after table with real values (lineage `DeepSeek Harness → … → bash → ls`, command `ls -1 /Users/iolaire/Desktop`) and a second capture for Qoder and the Microphone. The inform-only limit is stated plainly, and the comparison table against Little Snitch, Santa and Objective-See is fair.

**Strengths**
- Real third-party agent captures, not only the WardTrigger harness.
- Honest limits: inform only, Apple's dialog keeps control; Apple's future permissions acknowledged.
- Accessibility work: Reduce Motion, VoiceOver labels on HUD reasons (`HUDSectionTests`).

**Areas for improvement** (ranked by points per hour)
1. Add a "clean Mac" section: toolchain, `scripts/run_ward.sh`, what the app asks for, what first launch looks like. About 1 hour, +0.5.
2. State "verified on macOS 27.x only" beside the "macOS 13+" claim, or test one older Mac. 15 minutes for the honest line.
3. Capture a real-agent prompt that triggers a risk tag (for example `curl` on a `.pem`), so the headline feature appears in real evidence. 1 to 2 hours, +0.5 to +1. The Qoder capture admits the command is unreadable (`swift-frontend -interpret`), which is a weak spot.
4. Replace personal paths (`/Users/iolaire/Desktop`, `/Volumes/Gold/Vegrún`) or note they are the author's. 15 minutes.
5. Close the open tasks in `ward-app/tasks.md`. 2 hours.

### Technological Implementation (8.5/10)

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes, strong | 7 specs, each with requirements, design, tasks (`ward-app`, `ward-trigger`, `castle-keep-visual-theme`, `hud-placement-and-menubar-theme`, `hud-plain-language-copy`, `darwin-tcc-mcp-server`, `permission-capture-framework`). About 295 checked tasks, 6 unchecked. Test names cite requirement numbers (for example "hud-plain-language-copy 2.1, 2.6"), so tasks map to tests | No spec-driven vs vibe-coding comparison written. `ward-app` lacks `.config.kiro` |
| Steering | Yes, strong | 9 files; 8 `inclusion: auto`, 1 `manual`. Visible effect: no force-unwrap, Darwin interop, raw-pointer rules, TCC boundaries, palette | No `fileMatch` inclusion used. Little written evidence of steering changing an outcome |
| Hooks | Present, **unverified** | 6 files in `.kiro/hooks/*.json` (build-test gate, palette check, raw-pointer review, security-boundary guard, spec-first nudge, standards lint) | Files use a custom schema (`"version": "v1"`, `hooks[]`, `trigger: PostTaskExec`). The Kiro IDE's own hook format is a `.kiro.hook` file with `when` and `then`. The IDE may not load these. Confirm in the Hooks panel; if they do not appear, convert them. Also the system's own hook for spec-first behavior is in use in this session, which is a point the write-up could cite |
| MCP | Yes | `.kiro/settings/mcp.json` and `.kiro/tools/mcp_darwin_server.py` (custom `darwin-tcc-docs` server: header search, struct lookup, TCC service registry) with its own Python tests | Needs `.kiro/tools/.venv`, which is gitignored. Setup steps must be in the README. Little evidence of what the server changed in the code |
| Property-based testing | Yes, hand-rolled | `ParseProcArgsBufferTests` (round-trip and never-traps properties, 200 or 1000 iterations with seeded RNG), `TCCEventParserTests`, `PlacementCalculatorPropertyTests`, `AlertMatcherPropertyTests`; Hypothesis on the Python MCP tools. `swift test`: 169 pass | Loops are not a PBT library, so no shrinking. Judges may still accept it. No record of a bug PBT found, which is the strongest PBT story |
| Kiro power | Yes | `swift-expert` installed; led to Swift 6 strict concurrency (devlog Day 8, commit `20f0d42`) | Only one power |
| Custom agents, prompts | Partial | `.kiro/prompts/code-review-hackathon.md` used repeatedly (reviews at 30, 33, 34, 35/50) | No custom agent |
| IDE vs CLI vs Crew | Not documented | Devlog says "pairing with Kiro" | The rules ask for differences; nothing written |
| Experimentation | Yes | Devlog with 20 dated entries, abandoned measurements (TCC DB snapshot design reversed on macOS 27), four fixes after first live test, Day 5 review follow-ups, reviews driving changes | Not summarized for judges |

**Strengths**
- Many Kiro surfaces used, and the specs drive real code and tests.
- A custom MCP server with its own tests is above the usual.
- Honest devlog that records reversals.

**Areas for improvement**
1. Write `docs/KIRO_USAGE.md` that answers the rules' questions (IDE/CLI/Crew, hooks, spec vs vibe, steering strategy, MCP, PBT, powers) with links to files and commits. 2 to 3 hours, +0.5 to +1, and removes a Stage One risk.
2. Verify hooks load in the IDE; convert to `.kiro.hook` if not. 30 to 60 minutes. A non-loading hook is visible to judges who open the folder.
3. Document one spec-vs-vibe comparison (for example the `hud-plain-language-copy` spec against the unspecced HUD work). 1 hour.
4. Put MCP venv setup in the README and add one example of the MCP answering a real question during the build. 30 minutes.
5. Record one bug a property test caught, if any. 30 minutes of devlog digging.

### Design (8/10)

**Justification.** This is a product, not a proof of concept: a menu bar ghost with states (idle, alert, not-watching badge), a non-activating `NSPanel` HUD placed beside Apple's dialog (`AlertLocator`, `PlacementCalculator`, multi-prompt tracking in `PromptTracker`), a plain-language banner and per-category risk reasons, a risk legend, and a lineage tree. Art is drawn in code (`HUD/Art/`, `GhostGeometry`, `FigureRenderer`) with the documented palette and the "Let Spirit Pass" / "Spirit Paused at the Gate" copy. The plain-language banner (commit `e17fdc1`) shows the theme being corrected where it hid function, which is the right instinct.

**Strengths**
- Non-activating panel preserves Apple's dialog focus (project steering rule, enforced by tests in `FortressHUDWindowTests`).
- Rendering and placement are unit and property tested.
- Real screenshots show the HUD beside Apple's prompt.

**Areas for improvement**
1. Show the error states (process exited, watcher down) in a screenshot or the video. 1 hour, +0.3.
2. Check contrast of Spectral Ectoplasm text over `.ultraThinMaterial` on a light wallpaper. 1 hour.
3. The README ASCII mockup still shows the older layout; replace it with the real screenshot. 10 minutes.
4. Add a short GIF of the ghost animation to the README. 1 hour.

### Innovation / Idea (8/10)

**Justification.** No tool in the README comparison table explains who is behind a TCC prompt. The idea connects Darwin process introspection, unified log streaming and the AI-agent problem with zero entitlements, no SIP bypass and no kernel or system extension. The Castle Keep lore is coherent with the function. Frankenstein is a defensible label. Limits to be honest about: it depends on TCC log wording that changes between macOS versions (regex fallback mitigates), and the capture work shows one macOS version.

**Areas for improvement**
1. Say in the pitch what is novel in one sentence: the prompt-to-process correlation (`TCCRequestCorrelator`, msgID matching). 15 minutes.
2. Show the regex fallback working on a changed log line in the video or README. 1 hour.

### Presentation (4/10)

**Justification.** README is detailed and has real screenshots and a comparison table. A Remotion video project exists (`docs/demo/remotion/`, about 2:47, `VOICEOVER.md`, draft MP4 in `out/`), built from real captures. Missing: a public YouTube upload, a Devpost description, a Kiro write-up, and any `.kiro` walkthrough in the video. The narration is macOS `say` output, which may sound flat. The video script covers problem and before/after, but the Kiro story needs to be in it, and the scoring rubric asks to see the project running end to end. A rendered explainer of captured clips is acceptable only if it clearly shows the real app working; consider a short live screen recording at the start.

**Strengths**
- Real captures with a measured baseline.
- A timed script and a reproducible video pipeline.

**Areas for improvement** (ranked)
1. Upload the video to YouTube as public, under 3:00, and put the link in the README and Devpost. 1 hour, and it clears a disqualification item.
2. Add a 20 to 30 second `.kiro` walkthrough (specs, steering, hooks, MCP) to the video. 1 to 2 hours, +1 on Presentation and Technology.
3. Draft the Devpost text from `docs/pitch.md` and the README. 1 to 2 hours.
4. Add a no-affiliation disclaimer for third-party names to the README and video end card. 10 minutes.
5. Replace `say` narration with a human voice-over. 1 hour, +0.5.
6. Push the unpushed commit so the repo matches what you review. 1 minute.

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs a public video and a top-10% overall score |
| Bonus Blog Prize | Not yet | No post exists. `docs/pitch.md` plans a Dev.to post. Needs public post, states it was written for Kiroween 2026, URL in submission, published in the Submission Period |
| Social Blitz Prize | Not yet | No post. Must start with `#KiroweenHackathon26`, share a favorite thing about Kiro and how it changed development, URL in submission |
| Best Ghost of Kiroween Past | Unknown | Only if a team member registered for Kiroween 2025 (Devpost verifies) |
| Best Student Project | Unknown | Only if all members are students; needs LinkedIn, student emails, year, degree, school |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup site |
| Best Kiro Crew App | No | Would need a separate public repo created in the Submission Period |

A project can win one Overall or Category prize, not both, but any number of bonus prizes. The blog and social posts are the cheapest bonus targets.

## Summary

**Top Strengths:**
- A working, tested product (169 tests) with a coherent theme and a non-activating HUD that leaves Apple's prompt in control.
- Seven structured specs, nine steering files, a custom MCP server and a power, with specs traceable to tests.
- Real third-party before/after evidence and an honest comparison with existing tools.
- A candid devlog that records course changes.

**Critical Issues (disqualification or major score risk):**
- No public YouTube demo video link. A draft exists, but nothing satisfies the requirement yet.
- No Kiro usage write-up and no Devpost description. Without them Stage One carries risk and Technological Implementation cannot reach its ceiling.
- Hooks use a nonstandard schema and may not load in Kiro IDE (unverified).
- One local commit is unpushed.

**Prioritized Recommendations (highest score gain per effort first):**
1. Push `main`. Upload a public, under-3-minute video to YouTube and link it in README and Devpost. Add the no-affiliation line to the end card.
2. Write `docs/KIRO_USAGE.md` answering the rules' Kiro questions; link it from the README and reuse it in Devpost.
3. Check the hooks load in the IDE; convert to `.kiro.hook` if they do not.
4. Add a `.kiro` walkthrough segment to the video.
5. Draft the Devpost text.
6. Publish the Dev.to post (Bonus Blog) and a `#KiroweenHackathon26` post (Social Blitz) and add both URLs to the submission.
7. Add the clean-Mac install section, MCP venv steps, and a "verified on macOS 27.x" note.
8. Capture one real-agent run that triggers a risk tag.
9. Close the remaining spec tasks and add the error-state screenshot.

**Hackathon Readiness:** Needs Work. The product is ready. The submission package is not. With 11 days left, items 1 to 6 fit in about two working days.
