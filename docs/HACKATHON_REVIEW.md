# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: 2026-11-20
Days until deadline (Dec 4, 2026 2:00 PM PT): 14

Scope note: reviewed at commit `20f0d42` on `main`. `git fetch` then `git status -sb` shows `main...origin/main` with nothing ahead or behind; 34 commits, first on 2026-11-05. This review ran on a **Linux** machine with no Swift toolchain, so `swift build` and `swift test` could not be executed here (the package is macOS-only: AppKit, `platforms: [.macOS(.v13)]`). What was verified directly: `gh repo view` (visibility, license), `git` history and `.kiro` tracking, all 6 hook JSON files parse, README/docs contents, force-unwrap and file-size scans, spec task counts, and the MCP server's Python suite in a fresh venv (**41 passed, 12 skipped, 3 failed** — the 3 failures are `test_sdk_locator` fallback tests that hard-require `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`, a macOS path; they are environment failures on Linux, not product defects, but they were therefore not proven passing here). Swift test status rests on the devlog Day 8 claim (2026-11-12: "all 166 tests pass" after the Swift 6 migration), corroborated statically by exactly 166 `@Test` declarations in `GatekeepersWardTests/`. The previous review ran the Swift suite on macOS 27.0.1 at `670cf4d`; that evidence is 5 commits old. No demo video, Devpost text, Kiro write-up, blog or social post exists yet, so Presentation is scored on what is observable.

## Overall Score: 33/50

Up 0.5 from the 32/50 snapshot at `670cf4d` (2026-11-09). Since then: the Castle Keep visual theme landed as a full spec-then-code cycle (`castle-keep-visual-theme`, 39/39 tasks), the MCP spec closed its last 2 tasks (36/36), ward-app dropped from 9 open tasks to 4, tests grew 108 → 166, a Kiro **power** (`swift-expert`) was used to drive the Swift 6 strict-concurrency migration, and the first live run on a real Mac produced four concrete fixes. Product quality is up; submission material (video, write-up, Devpost text, README screenshots) is unchanged and remains the whole remaining gap.

## Stage One: Category and Kiro Fit

**Pass.** Chosen category: **Frankenstein**, decided and recorded (devlog 2026-11-09 "Category and Team Representative decided": Costume Contest dropped as secondary; `docs/pitch.md` updated; README line 108 states Frankenstein). Kiro use is substantial and visible in `.kiro/`: **5 specs** (`ward-trigger` 41/41, `castle-keep-visual-theme` 39/39, `hud-placement-and-menubar-theme` 22/22, `darwin-tcc-mcp-server` 36/36, `ward-app` 39 done / 4 open), 9 steering files, 6 hooks, a custom MCP server, a committed review prompt, and now documented **power** usage (devlog Day 8: `swift-expert` audited the package and drove the Swift 6 migration, finding three real issues). Darwin `sysctl`/`proc_pidinfo`, unified log streaming, SwiftUI/AppKit and AI-agent workflows remain stitched together — the Frankenstein fit is genuine.

## Hard Requirements

| Requirement | Status | Evidence |
|---|---|---|
| Public GitHub repo | Pass | `gh repo view --json visibility,licenseInfo` on 2026-11-20: `visibility: PUBLIC`, `https://github.com/iolaire/TheGatekeepersWard`, default branch `main` |
| License detected by GitHub | Pass | `licenseInfo.key: apache-2.0`; `LICENSE` (11,358 bytes) at root; copyright in `NOTICE` |
| `/.kiro` committed, not ignored | Pass | `git ls-files .kiro` = 58 files (hooks, prompt, settings, 5 specs, 9 steering, tools). `.gitignore` excludes only `.kiro/sessions/` and `.kiro/tools/.venv/`; `git check-ignore` confirms steering/specs/hooks/prompts not ignored |
| Source, assets, run instructions | **Pass with gaps** | Scripts present and executable (`scripts/run_ward.sh`, `run_ward_trigger.sh`, `git-hooks/pre-commit`). **Cannot re-verify `swift build`/`swift test` on this Linux reviewer machine** (see scope note). README drift has grown: line 86 says "81 tests" (actual: 166 `@Test`, devlog claims 166 pass); line 71 lists `GatekeepersWard/Resources/` which does not exist; line 56/80 say "Swift 5.9+ / Xcode 15+" but commit `20f0d42` set `swiftLanguageVersions: [.version("6")]`, so a **Swift 6 toolchain (Xcode 16+) is now required** — devlog Day 8 flags this as an open decision; root README still has no MCP venv setup (documented only in `.kiro/tools/README.md`) |
| Built in Submission Period | Pass | First commit 2026-11-05 (`70a9194`), 34 commits, none before Oct 30. No pre-existing code to disclose |
| Runs as depicted | Partly verified | Devlog Day 6 (2026-11-10): first live run of HUD + icon on a real Mac, four issues found and fixed. Swift 6 build + 166 tests claimed passing 2026-11-12 (not re-run here). Still open by the repo's own account: `ward-app` 8.7 (multi-display placement), 8.10 (two concurrent prompts live, timeout, clean quit), castle-keep tasks 4/8 (icon and HUD eye-check), and Day 5's "placement beside a live dialog not yet verified by eye" |
| Demo video (<3 min, public YouTube) | **Missing** | Nothing in repo or README links to a video; `docs/pitch.md` checklist item "Demo video ≤3 minutes" unchecked; plan schedules it Phase 6 (Nov 28 – Dec 01) |
| Text description | **Missing** | README covers the content; no Devpost text written (`find` for write-up/devpost/submission files returns nothing) |
| Kiro write-up | **Missing** | Raw material is now rich: 5 specs, 9 steering, 6 hooks, MCP server, PBT, devlog with a power-usage story (Day 8) and a natural spec-first (`castle-keep`, `hud-placement`) vs spec-later (`ward-app`) comparison — none of it assembled |
| Category | Pass | Frankenstein (README, pitch, devlog Day 5; Costume Contest explicitly dropped) |
| Team of 3 or fewer, one Representative | Pass (confirm on form) | 2 members (README Team). **Fixed since last review:** Representative = Iolaire McFadden, recorded in README line 114. Must match the Devpost form exactly |
| English | Pass | All repo materials in English |
| Third-party IP | Pass (check) | Swift package has no external dependencies. Python `requirements.txt`: `mcp` (MIT), `pycparser` (BSD-3-Clause), `hypothesis` (MPL-2.0), `pytest` (MIT) — all permissive, but licenses are not stated anywhere in the repo. **New finding:** four mood-board JPGs (2.6–4.4 MB) sit in `docs/Planning/Styles/` (`Darwin's Beagle & The Specimen Cabinet.jpg`, `Phosphor Morgue.jpg`, etc.) — confirm the team has the right to redistribute them in a public repo, or remove them before submission |

## Stage Two Scoring

### Potential Impact (7/10)
- **Justification:** The pain is still real and well stated in the README, and the pipeline is complete: `TCCWatcher.swift` (294 lines) streams `log stream`, `TCCEventParser` + `TCCRequestCorrelator` match prompts and PIDs, `ProcessInspector` reads argv/cwd/lineage, `RiskTagger` flags suspicious arguments, `FortressHUDView` presents them. New since the last review: a plain-language request line (Day 6 — the HUD now shows the sentence Apple shows, read from `Info.plist`, instead of a raw service key), a "not watching" crimson badge with retry timing when `log stream` fails (task 8.5b, closes an honesty gap), and accessibility labels on the badge.
- **Strengths:** Honest scope ("we inform, we don't intercept"; HUD has no buttons). Zero entitlements. Reduce Motion handled; `AlertLocator` finds Apple's dialog without Screen Recording or Accessibility permission; `PromptTracker` handles concurrent prompts.
- **Gaps:**
  - Still only exercised with WardTrigger and one Kiro CLI session in Zed (devlog Day 4). **No recorded run with Cursor or Claude Code** — the single fastest way to move this score.
  - Verified on macOS 27.0.1 only; the "macOS 13+" target is unbacked (task 8.3 needs a Ventura/Sonoma capture).
  - Multi-display placement unchecked (8.7); two-prompt/timeout live run unchecked (8.10).
  - Install story is still "build from source" with no first-run guidance — and the build instructions themselves are now stale (Swift 6 toolchain requirement, below).
- **Improve:** Record one run with Cursor or Claude Code and close 8.10 (~half a day with the demo harness ready) → 8. Add a short "Install on a clean Mac" section → 8.5.

### Technological Implementation (8.5/10)
Strongest and fastest-improving area. New since `670cf4d`: a fifth spec written **before** its code (`castle-keep-visual-theme`, 39/39), the MCP spec closed (36/36), `ward-app` down to 4 open tasks, tests 108 → 166, and a documented Kiro **power** workflow — `swift-expert` audited build settings first, then drove `targeted` → `complete` → Swift 6 language mode, catching a real main-actor bug in `AppDelegate`, non-`Sendable` globals in `WardTrigger`, and a capture-in-closure bug in `OutputCollector` (devlog Day 8). That is the "powers" question in the rules answered with evidence.

| Kiro feature | Present? | Evidence | Gap |
|---|---|---|---|
| Specs | Yes, 5 | `ward-trigger` 41/41, `castle-keep-visual-theme` 39/39, `hud-placement` 22/22, `darwin-tcc-mcp-server` 36/36, `ward-app` 39/43 (open: 8.3, 8.4, 8.7, 8.10). `castle-keep` and `hud-placement` were specced before their code (devlog) — a clean counter-example to `ward-app` (written after the code, devlog says so) | The spec-driven vs vibe-coding comparison is now *evidenced in the history* but still not written up. `ward-app` lacks `.config.kiro` (only spec missing one) |
| Steering | Yes, strong | 9 files; 8 carry `inclusion:` frontmatter (7 `auto`, `darwin-mcp-usage` `manual`); `project.md` has none. Code matches it: no force-unwrap found in `GatekeepersWard/`, `GatekeepersWardApp/` or `WardTrigger/`; largest file 301 lines (`GhostGeometry.swift`, 1 line over the steering's 300-line limit — trivial) | Show 2–3 concrete cases where steering changed output (write-up) |
| Hooks | Yes, 6 | All 6 JSON files parse with valid triggers/matchers; helpers in `scripts/hooks/`; opt-in `scripts/git-hooks/pre-commit` runs `swift build` + `swift test --skip integration` | Still no recorded case of a hook catching something **inside Kiro**; pre-commit requires manual `ln -sf` install; no CI (`.github/workflows` absent), so nothing enforces build/test on push |
| MCP | Yes | `darwin-tcc-docs` in `.kiro/settings/mcp.json` (`disabled: false`); pytest run here in a fresh venv: 41 passed, 12 skipped, 3 macOS-SDK-path failures on Linux (environment, not defect); requirements pinned (`mcp==1.30.0`, `pycparser`, `hypothesis`, `pytest`) | No documented case of it preventing a wrong struct layout or service name; venv still gitignored and absent from the root README, so judges must find setup themselves |
| Property-based testing | Yes | 166 `@Test` declarations (KERN_PROCARGS2 buffer, NDJSON round trip, extractor never traps, chunked-stream equivalence, placement geometry, alert matching, ghost pixel/geometry); Hypothesis on the Python side | No record that PBT found a real bug — if it ever did, write it up |
| Custom agents / powers | **Powers: yes.** Agents: no | `swift-expert` power used Day 8 with concrete findings (see above). No custom agents in repo | State in the write-up why no custom agents; the rules ask directly which powers were leveraged |
| IDE vs CLI vs Web vs Crew | Not documented | Devlog: Kiro CLI session in Zed; "pairing with Kiro" throughout | One paragraph on what was used and where |
| Experimentation | Strong | Devlog (dated, decisions + dead ends), Day 6 four-fix live-test loop, Day 8 migration loop, macOS 27 `msgID` attribution fix (`8de0079`), dropped window-title approach (would have needed Screen Recording) | Gather dead ends and course corrections in one place for the write-up |
| Required write-up | **No** | | Missing — hard requirement |

### Design (7.5/10)
- **Justification:** Materially stronger than the 7 at `670cf4d`. The Castle Keep theme is no longer a plan but a shipped, spec-driven implementation: gate banner with torches and portcullis (`GateScene.swift`), vector spirits ported from the chosen SVGs (`GhostGeometry.swift`, `FigureRenderer.swift`), neon title, audit banner, lineage tree, risk legend chips, command box, and two non-interactive instruction pills (`FortressHUDView` and friends), all under the palette hook (`castle-keep-palette-check`, with a documented `palette-ok` exemption used once for Apple's own "Allow" string). The emoji header was replaced by a vector ghost pair (8.9 closed). First live test on a real Mac (Day 6) found and fixed four real issues: icon legibility at 1 pt detail, an alert pulse, unbounded command growth (now 12-line/900 pt cap, 720 pt typical enforced by test), and plain-language request text. The "not watching" failure state (8.5b) is exactly the honest error-state polish this criterion wants. Geometry, pixel and size-budget behaviour is tested (worst-case HUD height clamped and asserted under 640 pt).
- **Gaps:**
  - **No screenshot or GIF in the README** — `docs/screenshots/Screenshot.png` (938 KB) exists but is referenced by nothing (`grep` finds no links); judges still cannot see the design without running it. This is now a one-line fix, not a content problem.
  - The README ASCII mock (lines 36–48) predates the 400 pt gate-banner HUD and may no longer match what renders.
  - Eye-checks still open: castle-keep tasks 4/8, placement beside a live dialog (Day 5), multi-display (8.7).
  - Known polish items by the repo's own account: faint banding in the solo spirit's lower third; "TCC EVENT DETECTED" title is jargon (Day 6 notes a clearer title as open).
- **Improve:** Embed `Screenshot.png` + one HUD shot in the README and tidy the ASCII mock → 8.5. Close the eye-checks with a 10-minute live pass → 9.

### Innovation / Idea (8/10)
- **Justification:** Unchanged and still defensible: no known tool correlates a TCC prompt to the exact child process, its argv and its lineage *while the dialog is on screen* (Little Snitch/Santa/Objective-See block or log at system level; hand-run `log stream` shows no process forensics). The macOS 27 `AUTHREQ_ATTRIBUTION` → `AUTHREQ_PROMPTING` `msgID` join is original, non-obvious work, reported honestly. Zero entitlements, no SIP bypass. The Frankenstein fit is now even more concrete: 20-year-old `sysctl` + unified log + SwiftUI + agentic IDE workflows + a gothic theme that explains the function, with a Kiro power guiding the Swift 6 migration.
- **Gaps:** The novelty only lands publicly once the video shows the real prompt and HUD side by side with a recognisable agent. The "novelty vs existing tools" comparison was not web-checked in this review (same caveat as before).

### Presentation (2/10)
- **Justification:** Nothing that is scored here has shipped since the last review. No video (pitch checklist still unchecked; plan puts it Nov 28 – Dec 01), no Devpost text, no Kiro write-up, no blog or social post. README gained a screenshot *file* but embeds none, still claims 81 tests, and still omits MCP setup and the Swift 6 toolchain reality.
- **Strengths:** The raw material keeps improving: a full storyboard with timecodes and narration (`docs/pitch.md` "Demo Flow (≤3 Minutes)"), a demo path that works (`scripts/run_ward.sh`, then `scripts/run_ward_trigger.sh docs rg ...`), rendered HUD/menu-bar drafts (`docs/Planning/Styles/drafts/`, reproducible via `WARD_RENDER_DRAFTS=1 swift test --filter ArtDraftRenderer`), and now a real screenshot ready to embed.
- **Gaps:** Everything that is scored here: video under 3 minutes on YouTube, Kiro walkthrough, Devpost text.
- **Improve:** Script and record the video; embed the screenshots; write the text. This remains the biggest available gain (up to +6) and gates Best Demo.

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
- Working end-to-end pipeline from TCC log event to process forensics to HUD, built with zero entitlements, now with honest failure states (the "not watching" badge) and plain-language prompt text.
- 166 Swift tests claimed passing under Swift 6 language mode with `StrictConcurrency=complete` (devlog Day 8; statically corroborated: exactly 166 `@Test` declarations); Python suite green on macOS per prior review, re-run here on Linux with only macOS-path failures.
- Broad, real Kiro usage now covering every feature the rules name: 5 specs (two written before their code), 9 steering files, 6 valid hooks, a custom MCP server, property-based testing, and a documented **power** (`swift-expert`) that found real concurrency bugs.
- A spec-first design cycle (`castle-keep-visual-theme`) that produced a shipped theme, a first live Mac test that surfaced four real fixes, and an honest devlog that records dead ends and open items.
- Decisions closed since the last review: category (Frankenstein only), Team Representative (Iolaire McFadden), secondary tone (8.9), watcher-failure UX (8.5b).

**Critical Issues (disqualification or major score risk):**
- No demo video, Devpost text or Kiro write-up. These are hard requirements (video, text description, write-up are each separately required) and they cover a whole scoring criterion; 14 days remain and the plan schedules the video for Nov 28 – Dec 01, leaving almost no buffer.
- Build instructions may no longer match the code: README promises Swift 5.9+/Xcode 15+, but `20f0d42` put the package in Swift 6 language mode, which needs a Swift 6 toolchain. A judge following the README could fail to build — the "runs as depicted / instructions work" requirement.
- "Runs as depicted" is still only partly verified by the repo's own account: multi-display (8.7), two-prompt live run (8.10), and the visual eye-checks (castle-keep 4/8) are open.
- The macOS 13+ support claim still has no evidence; only macOS 27.0.1 has been captured (8.3).
- The one screenshot in the repo is referenced nowhere; README shows no design at all.
- ~~Third-party mood-board JPGs (up to 4.4 MB) are committed to a public repo — confirm redistribution rights.~~ Resolved 2026-11-22: the JPGs are Google-generated (C2PA metadata) and redistributable; see `docs/ai-asset-licensing.md`.

**Prioritized Recommendations (highest score gain per effort first):**
1. **Script and record the demo video** (≤3:00, public YouTube): real prompt and HUD side by side with a recognisable agent (a Cursor/Claude Code run doubles as the missing Potential Impact evidence), a short `.kiro` walkthrough, use the storyboard already in `docs/pitch.md`. Up to +6, and gates Best Demo.
2. **Write the Kiro write-up and Devpost text** from the raw material: the `swift-expert` power story, spec-first (`castle-keep`, `hud-placement`) vs spec-later (`ward-app`) comparison, hooks, MCP, PBT, and why no custom agents — the rules ask these questions verbatim. Hard requirement, ~+1–2 directly and it feeds the video narrative.
3. **Embed the screenshots** (`docs/screenshots/Screenshot.png` + one HUD shot) in the README and refresh the ASCII mock to match the 400 pt HUD: cheapest Design point on the board (~10 minutes → +1).
4. **Run one real agent (Cursor or Claude Code) against the HUD**, close `ward-app` 8.10 and the eye-checks, log the macOS version: → Potential Impact 8 and removes the biggest "runs as depicted" doubt.
5. **Truth-up the README**: 166 tests, drop the nonexistent `Resources/` line, require Swift 6 toolchain (Xcode 16+) or decide to keep `swiftLanguageVersions` 5.9-compatible, add MCP venv setup, add a "Known limits: tested on macOS 27.0.1 only" note. Protects the hard-requirement table.
6. **Bonus prizes**: publish the blog post (written for Kiroween 2026) and the `#KiroweenHackathon26` social post. Capture one real hook catch and one MCP-server save for the Technological Implementation story. Confirm the mood-board JPG rights.

**Hackathon Readiness:** Needs Work
