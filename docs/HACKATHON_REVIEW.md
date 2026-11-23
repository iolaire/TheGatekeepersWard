# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-23 (UTC)
Days until deadline (Dec 4, 2026 2:00 PM PT): 11

Scope: local `main` at `79d96b8` plus uncommitted edits to `README.md`, `docs/devlog.md` and `docs/pitch.md` (the new "Potential Impact" section). `origin/main` is at `ca21dd3`, so one commit and these edits are **not pushed**. Reviewed on macOS with the repo's Swift 6 toolchain. Verified here: `swift build` completes, `swift test` passes (166 tests in 23 suites), `gh repo view` reports a public repo with `apache-2.0` detected.

## Overall Score: 35/50

Up from 34/50 earlier today. The gain comes from real before/after evidence with a third-party agent (DeepSeek Harness) and a README that now argues impact. The three required submission artifacts (demo video, Devpost text, Kiro write-up) still do not exist.

| Criterion | Score |
|---|---|
| Potential Impact | 7.5 |
| Technological Implementation | 8.5 |
| Design | 8 |
| Innovation / Idea | 8 |
| Presentation | 3 |
| **Total** | **35 / 50** |

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: **Frankenstein** (README "Hackathon Category", `docs/pitch.md`, devlog 2026-11-09 decision). The fit is genuine: `sysctl(KERN_PROCARGS2)` and `proc_pidinfo` from the old POSIX layer, Unified Log NDJSON streaming, SwiftUI/AppKit, and agentic IDE workflows, stitched into one tool. Kiro use is deep and spread across features (see the table under Technological Implementation), so the "insufficient use of Kiro" risk is low, provided the write-up makes it visible to judges.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view`: `visibility: PUBLIC`, `github.com/iolaire/TheGatekeepersWard` |
| License at root, detected by GitHub | Pass | `licenseInfo.key: apache-2.0`; stock `LICENSE` (11,358 bytes), copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro` lists 6 hooks, prompts, `settings/mcp.json`, 6 spec folders, 9 steering files, MCP tool source. `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/` |
| Source, assets, build and run instructions | Pass, with gaps | `swift build` and `swift test` succeed. README Quick Start covers `swift build`, `swift test`, `scripts/run_ward.sh`. Gaps: no clean-Mac first-run section; MCP venv setup is not in the root README (the venv is gitignored) |
| Built in Submission Period | Pass | First commit `b55c3b7` on 2026-11-05; 41 commits, none before Oct 30. Two authors (iolaire 34, Dharshaneshwaran 7). No pre-existing code to disclose |
| Runs as depicted | Partly verified | Build and tests pass. Before/after capture exists in `docs/demo/assets/deepseek-harness/` (manifests, prompt and pair screenshots). `ward-app/tasks.md` still has 5 unchecked tasks. Only one macOS version is evidenced |
| Demo video, under 3 min, public YouTube | **Missing** | No link anywhere in README or `docs/pitch.md`. Planned for Nov 28 to Dec 1. Two 91 MB and 103 MB flow recordings exist locally (gitignored) and could seed it |
| Text description of features | **Missing** (partly covered) | README describes features well. No Devpost text drafted |
| Write-up on how Kiro was used | **Missing** | Raw material exists (specs, steering, hooks, MCP, PBT, `swift-expert` power in devlog Day 8) but nothing answers the rules' questions in one place |
| Category selected | Pass | Frankenstein |
| Team of 3 or fewer, one Representative | Pass | 2 members; Representative Iolaire McFadden (README "Team", memory and devlog 2026-11-09). Must match the Devpost form |
| English | Pass | All materials in English |
| Third-party IP, dependencies licensed | Pass, with two items to confirm | No external Swift dependencies. Python deps (`mcp`, `pycparser`, `hypothesis`, `pytest`) are permissive. AI art provenance is documented in `docs/ai-asset-licensing.md`. **New risk:** the README and capture assets show the "DeepSeek Harness" name and window, and the video rule bars third-party trademarks. See Critical Issues |

## Stage Two Scoring

### Potential Impact (7.5/10)

**Justification.** The problem is real and specific: AI agents trigger TCC prompts that name the app and say nothing about the command. The pipeline is complete: `TCCWatcher` streams `log stream`, `TCCEventParser` and `TCCRequestCorrelator` attribute the prompt to a PID, `ProcessInspector` reads argv, cwd and lineage, `RiskTagger` flags `.pem`, `.env`, `curl`, `base64`, and `FortressHUDView` shows it. The new README section ("Why Gatekeeper's Ward Matters") is the strongest impact evidence so far: a same-machine baseline versus Ward comparison on a real prompt, showing the lineage `DeepSeek Harness → DeepSeek Harness → bash → ls` and the command `ls -1 /Users/iolaire/Desktop`. Scope is honest ("we inform, we don't intercept"), and the table states who decides. It also admits Apple is working on finer-grained permissions, which a judge will respect.

**Strengths**
- Before/after table with real values answers "would someone actually use it".
- Handles concurrent prompts and locates Apple's dialog without Screen Recording or Accessibility permission.
- Reduce Motion respected; status badge has accessibility labels.

**Areas for improvement** (ranked by points per hour)
1. Replace personal paths in README and screenshots (`/Users/iolaire/Desktop`, `/Volumes/Gold/Vegrún`) or add a line saying they are from the author's machine. 15 minutes; polish.
2. Add an "Install on a clean Mac" section: toolchain, `scripts/run_ward.sh`, what the app asks for, how the HUD appears. 1 hour; +0.5.
3. State "verified on macOS 27 only" next to the "macOS 13+" claim, or test an older Mac. 15 minutes for the honest line.
4. Show one risky command (for example `curl` on a `.pem`) in the real-agent capture, so the risk tags appear in the before/after story. 1 to 2 hours; +0.5 to +1.
5. Close the multi-display and two-prompt items in `ward-app/tasks.md`. 2 hours.

### Technological Implementation (8.5/10)

**Justification.** This is the strongest criterion. Specs were written before code for `castle-keep-visual-theme`, `hud-placement-and-menubar-theme` and `permission-capture-framework`, and after code for `ward-app`, which gives a spec-first versus spec-later comparison. Steering visibly shaped the code: a scan of `GatekeepersWard/`, `GatekeepersWardApp/` and `WardTrigger/` found no force-unwraps, and the largest files are 301 and 294 lines against a 300-line standard. The `swift-expert` power drove the Swift 6 strict-concurrency migration (commit `20f0d42`, devlog Day 8). A custom MCP server (`.kiro/tools/mcp_darwin_server.py`) was built and specced for Darwin header and TCC lookups.

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes, 6 | `ward-trigger` 41 done, `castle-keep-visual-theme` 39, `hud-placement-and-menubar-theme` 22, `darwin-tcc-mcp-server` 36, `permission-capture-framework` 109, `ward-app` 39 done and 5 open. Each has requirements, design, tasks | No written spec-driven vs vibe comparison. `ward-app` has no `.config.kiro` |
| Steering | Yes, 9 files | Darwin interop, memory safety, TCC boundaries, log parsing, HUD design, testing, coding standards, MCP usage, project | Write up 2 or 3 cases where steering changed output |
| Hooks | Yes, 6 | `build-test-gate`, `castle-keep-palette-check`, `raw-pointer-review`, `security-boundary-guard`, `spec-first-nudge`, `swift-standards-lint` | Files use a `{"version":"v1","hooks":[{"trigger":"PostTaskExec",...}]}` shape. I could not confirm the Kiro IDE loads this shape; no hook run is recorded. Open the Hooks panel and confirm each appears. No CI (`.github/` absent) |
| MCP | Yes | `darwin-tcc-docs` in `.kiro/settings/mcp.json`; own spec 36/36; Python tests under `.kiro/tools/tests/` | Venv is gitignored and root README has no setup steps, so judges cannot start the server. No documented case where it prevented a mistake |
| Property-based testing | Yes | 166 tests pass. Property suites cover the `KERN_PROCARGS2` parser (`ParseProcArgsBufferTests`), the NDJSON parser (`TCCEventParserTests`, `TCCWatcherPipelineTests`), placement and alert matching. Hypothesis on the Python side | No record that PBT found a real bug. Write it up if it did |
| Powers | Yes | `swift-expert`: strict-concurrency audit, found a main-actor bug, non-`Sendable` globals and a closure-capture bug | None |
| Custom agents | No | None in repo | Say why not in the write-up |
| IDE vs CLI vs Web vs Crew | Not documented | Devlog mentions a Kiro CLI session | One paragraph on which surfaces were used and where each helped |
| Experimentation | Strong | Dated devlog with dead ends (window-title approach dropped for needing Screen Recording; several "measurement not taken" capture entries), live-test fix loop (Day 6), macOS 27 `msgID` attribution fix `8de0079` | Collect in one section of the write-up |
| Required write-up | No | | Hard requirement, not started |

**Areas for improvement**
1. Write the Kiro write-up, answering each question in the rules. 2 to 3 hours; protects Stage One and lifts this to 9+.
2. Confirm the six hooks load in Kiro IDE; convert to the IDE's native format if they do not. 30 to 60 minutes. If they are inert, "active hooks" is a compliance gap.
3. Add a GitHub Actions workflow running `swift build` and `swift test` on a macOS runner. 30 minutes.
4. Show one hook or PBT run catching something, in the devlog or video. 30 minutes.

### Design (8/10)

**Justification.** A coherent product, not a proof of concept: menu bar ghost with idle and alert poses, a non-activating floating HUD placed beside Apple's dialog, vector spirit sprites per lineage node, risk legend, and distinct states (watching, not watching, process exited, concurrent prompts). `FortressHUDWindowTests` asserts the panel's style mask, level, and key and main flags, so it never steals focus. The palette is enforced by a hook and tests. The pair screenshot (`ward_deepseek_harness_desktop_pair.png`) shows the HUD beside Apple's prompt and demonstrates the intent clearly.

**Strengths**
- Palette and copy ("Spirit Paused at the Gate", "Answer in Apple's dialog") are consistent and tested.
- The theme maps to function: lineage rows are spirits, the gate is the permission.

**Areas for improvement**
1. Add 2 or 3 more screenshots or a short GIF (risk-tagged command, "not watching", process exited). 1 hour; +0.5 Design and Presentation.
2. Hand-check contrast of body text on the frosted material and note the result.
3. Finish the open items in `ward-app/tasks.md` (multi-display).

### Innovation / Idea (8/10)

**Justification.** Little Snitch, Santa and Objective-See tools cover network, binary authorization and persistence. None surface "which agent command is behind this TCC prompt" while Apple's dialog is up. Combining `KERN_PROCARGS2`, `proc_pidinfo`, Unified Log streaming and a themed HUD, with zero entitlements and no SIP bypass, is a clear Frankenstein stitch. The observation that `tccd` blocks the child, so `sysctl` is reliable during the prompt, is a good design insight.

**Areas for improvement**
1. Add a short comparison table against existing tools to the README or pitch. 30 minutes; +0.5.
2. Lead the video with the agent angle (the opaque prompt), not the ghost.

### Presentation (3/10)

**Justification.** The README is now clear and carries real before/after images, and `docs/pitch.md` has a storyboard. The artifacts judges weigh most are still absent: demo video, Devpost text and Kiro write-up. Score reflects only the README, screenshots and pitch.

**Areas for improvement** (highest value first)
1. **Demo video, under 3:00, public on YouTube.** Suggested shape: 0:00 to 0:20 problem; 0:20 to 1:30 real agent triggers a prompt, Apple's dialog and the HUD side by side; 1:30 to 2:20 `.kiro` walkthrough (specs, steering, hooks, MCP, PBT); 2:20 to 2:50 impact. No music, or original music only. Blur or avoid third-party product names and logos. 4 to 6 hours; +4 to +5.
2. **Devpost text** (problem, audience, features, how Kiro was used). 2 hours; +1.
3. **README additions:** video link, MCP setup note, "Verified on" line, link to the write-up.

## Code Quality

- `swift build` completes; `swift test` passes 166 tests in 23 suites. Build prints `ld` search-path warnings from the Command Line Tools install; they are harmless.
- No force-unwraps found in the three production directories. Largest file `GatekeepersWard/HUD/Art/GhostGeometry.swift` is 301 lines.
- Graceful degradation is implemented and spec'd (process exited, regex fallback on `eventMessage`, restart backoff, "not watching" badge).
- Doc-comment coverage was not audited line by line; a hook is meant to check it.
- No secrets found. The 91 MB and 103 MB `.mov` files are gitignored and not tracked. Largest tracked files are mood-board JPGs (about 2.5 to 3.2 MB) and two HUD PNGs (about 1 to 1.4 MB).

## Bonus Prize Eligibility

| Prize | Eligible? | Missing items |
|---|---|---|
| Best Demo | Possible | Needs the video and a top 10% overall score |
| Bonus Blog Prize | Not yet | No post. Needs a public third-party post, published in the Submission Period, saying it was written for Kiroween 2026, URL in the submission |
| Social Blitz Prize | Not yet | No post. Must start with `#KiroweenHackathon26`, state a favorite thing about Kiro and how it changed development, URL in the submission |
| Best Ghost of Kiroween Past | Unknown | Only if a team member registered for Kiroween 2025; team to confirm |
| Best Student Project | Unknown | Only if every member is a student; needs LinkedIn, student emails, year, degree, school |
| Best Startup Project | Unknown | Only if a founder; needs LinkedIn and startup website |
| Best Kiro Crew App | No | Needs a separate public repo created in the Submission Period; none exists |

A project can win one Overall or Category prize, not both, but any number of bonus prizes.

## Summary

**Top Strengths:**
- Working end-to-end product: builds, 166 tests pass, and a real before/after capture against a third-party agent.
- Broad, specific Kiro use: 6 specs, 9 steering files, 6 hooks, a custom MCP server with its own spec and tests, PBT, and the `swift-expert` power with real findings.
- Honest, zero-entitlement architecture and a theme that maps to function.
- Clean licensing and timeline: Apache 2.0 detected by GitHub, all commits inside the Submission Period.

**Critical Issues (disqualification or major score risk):**
- No demo video. Missing video is a disqualification risk and caps Presentation.
- No Kiro write-up and no Devpost text. Both are required submission items.
- One commit and the new README, devlog and pitch edits are unpushed; the public repo does not show the impact section yet.
- Hooks may be inert: the file shape (`version: v1`, `PostTaskExec`) was not confirmed against what Kiro IDE loads. The "active hooks" requirement depends on this.
- Third-party trademark exposure: the README and capture assets show the "DeepSeek Harness" name and window. The README text is likely fine, but the video rule bars third-party trademarks. Decide whether to blur it, or use WardTrigger plus a generic shell agent on screen.
- "macOS 13+" is claimed but only one macOS version is evidenced.

**Prioritized Recommendations (highest score gain per effort first):**
1. Commit and push `main` with the README, devlog and pitch edits (5 minutes).
2. Confirm the six hooks load in Kiro IDE; fix the format if not (30 to 60 minutes; protects a compliance item).
3. Record and upload the demo video, using the existing capture flow as a base (4 to 6 hours; +4 to +5).
4. Write the Kiro write-up and Devpost text from the devlog, answering each question in the rules (3 to 4 hours; +1 to +1.5).
5. Add an MCP venv setup note, a clean-Mac install section and a "verified on macOS 27" line to the README (1 hour; +0.5 Impact).
6. Add a macOS GitHub Actions build-and-test workflow (30 minutes).
7. Add the existing-tools comparison table and two or three more screenshots (1.5 hours; +0.5 to +1).
8. Publish a short blog post and a `#KiroweenHackathon26` post for the two bonus prizes (1 to 2 hours; bonus only).

**Hackathon Readiness:** Needs Work. The product and Kiro usage are ready. The submission cannot be filed until the video, text description and write-up exist. With 11 days left, the pitch plan (video Nov 28 to Dec 1, submit by Dec 2) is feasible if it starts on schedule.
