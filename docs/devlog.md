# Dev Log

Running notes from the build. Newest entries at the top.

---
## 2026-11-23 (03:30 UTC) — Hooks converted to the Kiro IDE format

**iolaire (pairing with Kiro)**
The six files in `.kiro/hooks/` used a custom `version: v1` / `PostTaskExec` schema that the Kiro IDE does not load. They are now `*.kiro.hook` files (`when` / `then`):

| Hook | Trigger | Action |
|---|---|---|
| Build and Test Gate | `postTaskExecution` | `runCommand` |
| Castle Keep Palette Check | `fileEdited` on HUD and MenuBar | `runCommand` |
| Swift Standards Lint | `fileEdited` on app and WardTrigger code | `runCommand` |
| Raw Pointer Safety Review | `fileEdited` on Core | `askAgent` |
| Spec-First Nudge | `promptSubmit` | `askAgent` |
| Security Boundary Guard | `preToolUse` on write tools | `askAgent` |

The guard changed from a script that emits a CLI permission decision to an agent prompt carrying the same rules, because the IDE ignores that script output. The script stays in `scripts/hooks/` for the Kiro CLI. The two lint scripts run cleanly with no stdin, which is how the IDE calls them. Not yet confirmed: that each hook shows up and fires in the IDE Hooks panel.

---
## 2026-11-23 (02:47 UTC) — Day 19: Demo video splash card, real-clip scenes, draft render

**iolaire (pairing with KiroCrew)**

Reworked the demo video and refreshed its narration pass.

- Added a 3.5 s silent splash / title card at the very start (`src/scenes/SceneSplash.tsx`): the gate-and-spirits mascot rises, the wordmark lights up, the tagline fades in, then it hands off to Scene 1. It is a fixed-length sequence wired in `src/Main.tsx`, length `SPLASH_FRAMES` in `src/theme.ts`, and carries no narration, so the audio config is unchanged.
- Scenes 2, 3 and 3b now play the real screen recordings as clips (via `ScreenClip`) and hold the last frame, instead of only showing the pair stills. `scripts/prepare-assets.sh` makes 1440p proxies in `public/clips/` for baseline (from 15 s), Ward (from 8 s) and Qoder (from 12 s, 8 s long). Sources are untouched.
- Narration re-generated at 156 wpm (Samantha). Per-scene on-screen reveal timings were scaled to the shorter clips. The scratch cut now runs **2:34** (4628 frames, 154.3 s), including the splash, under the 3:00 limit.
- Added a fast draft render path: `npm run render:draft` renders 960x540 (`--scale=0.5`, CRF 28) to `out/gatekeepers-ward-demo-draft.mp4` for quick iteration; `npm run render` stays full 1920x1080 for finalizing. Both outputs are gitignored.
- `VOICEOVER.md` gained the splash entry and the 2:34 runtime; the folder `README.md` documents the draft/final render split. No Swift code or `.kiro/` files changed.



**iolaire (pairing with Kiro)**

Captured a second before/after set, this time for a Microphone prompt from Qoder (`com.qoder.app`), another AI IDE. The new profile is `scripts/capture/profiles/qoder.profile`, and `scripts/capture/lib/services.tbl` gained a `Microphone` row (plus an `AddressBook` row no profile uses yet). The agent was asked to run a one-line `swift -e` command that calls `AVCaptureDevice.requestAccess(for: .audio)`.

- The Ward capture (`ward_qoder_microphone_pair.png`) shows `Allow "Qoder" to access your microphone?`, `kTCCServiceMicrophone`, the lineage Qoder 44386 → Qoder 44767 → zsh 63090 → swift-frontend 63093, the full `swift-frontend -interpret` command, and the working directory. The baseline shows only Apple's prompt.
- Files tracked in git from `docs/demo/assets/qoder/`: both `prompt.png` shots, `ward_*_hud.png`, `ward_*_pair.png`, both manifests, and the summary. The `flow.mov` videos (baseline 85.7 s, ward 20.6 s) and the 5K `screen.png` shots stay local under the existing `.gitignore` rules.
- The ChatGPT desktop app (`com.openai.codex`) was tried first. Its sandbox blocked the command, so no prompt appeared, and the profile was dropped.
- Contacts was dropped too. Neither ChatGPT nor Qoder declares `NSContactsUsageDescription`, so macOS is not expected to show a Contacts prompt for them.
- `README.md` and `docs/pitch.md` show the Qoder pair as a second example. Both note that the Executed Command is less readable (a `swift -e` one-liner shows up as `swift-frontend -interpret …`), while the lineage Qoder → zsh → swift-frontend still names the source.
- The demo video has a new `scene-03b-qoder` (1:42-1:59) built on the pair still. The scratch cut now runs 2:47 (5024 frames, 167.5 s), still under 3:00.
- The pair crop needs the prompt and the HUD on the same display. Two runs with the prompt on the secondary display gave no `pair.png`; the third run, with both on the main display, did.

---
## 2026-11-23 (02:20 UTC) — Day 19: Remotion demo video draft

**iolaire (pairing with KiroCrew)**

Built a draft demo video in `docs/demo/remotion/` (Remotion 4.0.545, 1920x1080, 30 fps). The scratch cut runs 2:30 (4505 frames, 150.2 s), under the 3:00 limit.

- Five scenes: intro and need, baseline macOS prompt, Gatekeeper's Ward in action, how it works, outro. The spoken copy stresses Potential Impact and states that Apple's finer-grained AI permissions are not released yet.
- Real captures are used for scenes 2 and 3 (`baseline_*_flow.mov`, `ward_*_flow.mov`, `ward_*_pair.png`). The 4K sources are transcoded to 1440p proxies in `public/clips/` (gitignored). Sources are untouched.
- Scratch narration uses macOS `say` (Samantha, 150 wpm), one WAV per scene. Scene length is the measured clip length from `afinfo` plus 0.4 s lead-in and 0.8 s tail, so narration does not clip or overlap.
- `src/audioConfig.ts` switches between scratch audio, per-scene recordings (`public/audio/final/<scene-id>.wav`) and one master file (`public/audio/final-narration.wav`).
- `VOICEOVER.md` has scene IDs, timecodes and visual cues. `README.md` in the same folder explains how to drop in the final recording and re-render.
- Open items: nobody has listened to the scratch voice yet; the repo link on the last scene is a placeholder; if a synthetic voice stays in the final cut, check the contest rules and disclose it. No Swift code or `.kiro/` files changed.

---
## 2026-11-23 (01:30 UTC) — Day 19: Before/after evidence and Potential Impact README

**iolaire (pairing with Kiro)**

Captured real-device before/after evidence of the DeepSeek Harness Desktop Vault permission flow. The files are `baseline_deepseek_harness_desktop_prompt.png` and `ward_deepseek_harness_desktop_pair.png` (the pair is a PNG, not a JPG), both in `docs/demo/assets/deepseek-harness/`. The baseline shows only `"DeepSeek Harness" would like to access files in your Desktop folder.` The Ward capture adds the TCC service (`kTCCServiceSystemPolicyDesktopFolder`), the four-step lineage (DeepSeek Harness 40189 → DeepSeek Harness 40723 → bash 45203 → ls 45204), the command `ls -1 /Users/iolaire/Desktop`, and the working directory.

`README.md` now opens with a "Why Gatekeeper's Ward Matters (Potential Impact)" section. It covers the blind-Allow problem, the gap before Apple ships finer-grained AI IDE permissions, the inform-only safety model, both screenshots, a side-by-side table, and the audience. Build steps, the Apache 2.0 license link and the AI-assisted artwork disclosure are unchanged.

---
## 2026-11-22 — Capture framework: no per-user TCC database on this macOS
**iolaire (pairing with Kiro)**
Real-machine finding on macOS 27.2.1 (build 26B131): Kiro has Full Disk Access (the protected system folder lists), but the user-level `com.apple.TCC` folder under Application Support does not exist, so there is no per-user database to snapshot. `tcc_probe` now returns exit 3 for this case (exit 1 stays for sqlite3 missing or an unopenable file). `setup` and `doctor` report `full-disk-access: unavailable (...; use --no-restore)` and no longer open the pane. `reset`, `prompt` and `run` stop with the same message and still never reset without a snapshot. `--no-restore` is the way forward on this macOS.

## 2026-11-22 (21:55 UTC) — Capture framework: TCC snapshot and restore design

**iolaire (pairing with Kiro)**

Task 22.2 of `permission-capture-framework`. Records the TCC snapshot and restore design and what the property tests found.

- Purpose: a capture run resets permissions so each prompt appears again. Snapshot saves the user's existing TCC rows for the services in scope before the run, and restore puts them back afterwards. After a capture the user's own grants and denials are as they were, and rows the run created are removed.
- Single-file boundary: only `scripts/capture/lib/tccdb.sh` touches the user TCC database. Every other script goes through its snapshot, restore and verify functions. The one exception is the guard hook and its steering rule, which only name the database path in order to block direct access. Restore touches only rows for the declared services and bundle, so rows for other services or clients are left alone.
- Task 15 results: the temporary copy could not be made because the session has no Full Disk Access (see the entry below). The real `access` columns, the floating point check and the real-database step (`tccutil reset`, restore, restart `tccd`) were not run. The design defaults stay: `tcc_columns` reads the column set at run time, and `tccd` is restarted after a restore.
- Bugs found by the property tests:
  - `INSERT OR REPLACE` silently substituted column defaults for values the snapshot had stored as NULL in NOT NULL columns, so a restored row differed from the snapshot. Fixed by using a plain `INSERT`, so a bad row now fails loudly instead.
  - The `kTCCService` prefix mapping (`tcc_db_service`) had to accept names with or without the prefix and never double it. The property test now checks both forms.
  - `cell_literal` mishandled empty blob and empty text cells, which must become `X''` and `''` rather than NULL, and mishandled integers at the int64 limits. Both cases now produce exact literals.
- Pre-commit: `scripts/git-hooks/pre-commit` runs `pytest scripts/capture/tests` as a whole directory, so the new `test_tccdb_*.py`, `test_tcc_*.py` and `test_teardown_guidance.py` files are picked up without edits. It leaves `CAPTURE_PBT_PROFILE` unset, so `conftest.py` loads the fast `dev` Hypothesis profile.

---

## 2026-11-22 (18:25 UTC) — Capture framework: TCC database measurement not taken
**iolaire (pairing with Kiro)**
Task 15 of `permission-capture-framework`: measure TCC database behavior on macOS 27.2.1 (build 26B131), on a temporary copy only.
- The copy could not be made. `cp "$HOME/Library/Application Support/com.apple.TCC/TCC.db"` into a temp directory failed with `No such file or directory`; the `com.apple.TCC` directory is not visible to this session. The most likely cause is that the process running the measurement (the Capture_Host) has no Full Disk Access, so the user database is hidden or unreadable. Nothing was opened for writing.
- Not measured, so the design defaults stay: the `access` table columns (`PRAGMA table_info(access)`), whether any cell holds a real (floating point) value, and whether `sqlite3` can run a delete-then-`INSERT OR REPLACE` transaction on a database of this shape.
- Not measured, by decision: the optional real-database step (`tccutil reset`, restore, `pkill -x -u "$(id -u)" tccd`) was not run, so whether `tccd` reloads after a restore is unknown. The design default (restart `tccd` after restore) stays.
- Full Disk Access: the Capture_Host must be granted Full Disk Access before the snapshot and restore code can read the user database. macOS applies a new Full Disk Access grant only to processes started afterwards, so the Capture_Host must be restarted after the grant.
- Still to do: grant Full Disk Access to the terminal or agent host, restart it, and rerun the copy and `PRAGMA table_info(access)` measurement.
---
## 2026-11-22 (15:00 UTC) — Capture framework: pre-commit test hook and first-capture asset list

**iolaire (pairing with Kiro)**

Task 13.2 of `permission-capture-framework`.

- Purpose: the capture framework triggers each macOS permission prompt in turn and records the prompt and the Ward HUD beside it, so the README, demo video and Devpost page use real screenshots instead of mock-ups.
- `scripts/git-hooks/pre-commit` now also runs `.kiro/tools/.venv/bin/python -m pytest scripts/capture/tests` when that virtualenv exists. Without the virtualenv the step is skipped and the Swift build and tests run as before.
- Assets from the first successful capture (to fill in once it has run):
  - Service captured: _TBD_
  - Prompt screenshot: _TBD_
  - HUD screenshot: _TBD_
  - Combined image: _TBD_
  - Capture date and macOS version: _TBD_
  - Captured by: _TBD_

---

## 2026-11-22 (14:00 UTC) — Capture framework: TCC prompt re-measurement not taken

**iolaire (pairing with Kiro)**

Task 1 of `permission-capture-framework`: re-measure the TCC prompt window on macOS 27.2.1 (build 26B131).

- `scripts/dump_window_list.swift` ran with no TCC prompt on screen and Ward not running, so no prompt owner, layer, size, button labels or Ward menu bar item layer could be measured. Only the menu bar `Window Server` (layer 24) was seen.
- Kept the design defaults in the new `scripts/capture/lib/defaults.sh`: owner `UserNotificationCenter`, layer `8` (last measured on 27.0.1, about 260 x 282 pt), Ward menu bar item layer 24 or higher, allow labels `ok,allow`, deny labels `don't allow,deny`. Each is overridable by an environment variable of the same name.
- Still to do: run the dump while a WardTrigger prompt (folder and removable volume) is up and update the defaults if they differ.

---

## 2026-11-22 (13:30 UTC) — Day 18: Gemini image usage validated

**iolaire**

Closed the open question of whether Gemini-generated images may ship in the project and the submission.

- Google does not claim ownership of Gemini output, so the generated art and its vector conversions can be used as app icons and UI art.
- Conditions: disclose that the art is AI-assisted, keep third-party IP and trademarks out of outputs, and do not use the images to train competing models.
- Kiroween IP rules (sections 4 and 7) are met because the team holds the rights it needs.
- Added `docs/ai-asset-licensing.md` with the terms and conditions, and an "AI-Assisted Artwork" section in the README.
- Mood-board JPG rights settled: all four JPGs in `docs/Planning/Styles/` carry Google C2PA Content Credentials (`trainedAlgorithmicMedia`), so they are Google-generated and can stay in the public repo. Keep the embedded metadata.
- Licence decision: the art follows the repo's Apache 2.0 licence. No separate CC0 or CC BY licence.
- Terms re-checked (2026-11-22): the Google ToS, Gemini Apps image help, the Generative AI Prohibited Use Policy and the Gemini API Additional Terms (effective March 23, 2026, text supplied by iolaire) all match the quotes. One correction: the Google ToS bans using generated content to develop any ML model, not only competing ones.
- Asset inventory added to `docs/ai-asset-licensing.md`. The four JPGs are Google-generated (C2PA). iolaire confirmed all four SVG sprites and their generator scripts came from Gemini, and Kiro wrote only the Swift drawing code. The draft PNGs are renders from that code and the screenshot is a screen capture.
- Source of the images: gemini.google.com (consumer Gemini app, in a notebook). The Google ToS, Prohibited Use Policy and Gemini Apps help apply, not the Gemini API terms. Same ownership result. Nothing further blocks the art. Notebook link saved in `docs/ai-asset-licensing.md`. Notebooks in Gemini Apps sit under the same Google ToS, and no notebook-specific image-rights term was found. A Google reply iolaire pasted agrees, but it is not an official document and cites the retired Generative AI Additional Terms, so it is recorded as supporting only. Nothing blocks the art.

---

## 2026-11-20 (08:00 UTC) — Day 16: Dharshaneshwaran re-runs the hackathon review and fixes the README

**Dharshaneshwaran**

Two docs-only commits arrived through PR #2 (`dev` into `main`). The first re-ran the `/code-review-hackathon` prompt and refreshed `docs/HACKATHON_REVIEW.md`. The second fixed the README items that review flagged.

**Review refresh (`577b50a`)**
- Score is now **33/50**, up from 32/50. Review date 2026-11-20, 14 days to the deadline.
- Closed since the last review: category (Frankenstein), team Representative, `darwin-tcc-mcp-server` spec (36/36), `castle-keep-visual-theme` spec (39/39), and `ward-app` down to 4 open tasks. Tests went from 108 to 166.
- New flags: README still said Swift 5.9 / Xcode 15, the new screenshot was not linked, the README test count was 81 against an actual 166, and four mood-board JPGs in `docs/Planning/Styles/` need a rights check before the repo goes out.
- Remaining gaps are unchanged: demo video, Devpost text, Kiro write-up, and one real-agent run on record.
- The review ran on a Linux machine with no Swift toolchain, so `swift build` and `swift test` were not re-run for it. The 166-test figure rests on the Day 8 entry and a count of `@Test` declarations.

**README fixes (`82ee26e`)**
- Tech Stack: "Swift 5.9+" became "Swift 6 (Swift 6 language mode, strict concurrency)".
- Quick Start: "Xcode 15+" became "Swift 6 toolchain (Xcode 16+ or matching Command Line Tools)". This closes the open decision from Day 8 for now: the README says Swift 6 is required.
- Test count updated from 81 to 166.
- Linked `docs/screenshots/Screenshot.png` in the Castle Keep section.

**Merge notes**
- The Swift 6 wording in `.kiro/steering/project.md` was synced to match. The same README line had been edited on both sides, so iolaire kept the upstream text.
- Still open from the review: the mood-board image rights check, the MCP venv setup missing from the root README, and the stale `GatekeepersWard/Resources/` entry in the README layout.

---

## 2026-11-12 (17:53 UTC) — Day 8: Swift 6 strict concurrency, found with the swift-expert power

**iolaire (pairing with Kiro)**

Installed the `swift-expert` Kiro power (a Swift Concurrency guide) and used it to audit the whole package. The result: the project now builds in Swift 6 language mode with `StrictConcurrency=complete`, and all 166 tests pass.

**How the power was used**

- **Settings first.** The power's rule is to read the build settings before giving any concurrency advice. `Package.swift` showed Swift 5 mode, no strict concurrency flag and no default isolation, on a Swift 6.4.2 toolchain. That meant the compiler was not reporting data-race problems that Swift 6 would.
- **Review against its guardrails.** `TCCWatcher`, `AppDelegate` and `ProcessInspector` were read against the power's checklist: is `@MainActor` justified, are escape hatches documented, are long-lived tasks cancelled. Most of it held up. `TCCWatcher` is an actor with `nonisolated` streams, `AppDelegate` is `@MainActor` because it owns AppKit objects, and both restart tasks are cancelled in `stop()`.
- **Migration loop.** The power's build, fix one category, rebuild, test cycle was followed in three steps: `targeted`, then `complete`, then Swift 6 language mode. The test suite was run after each step.
- **Steering guide.** `swift-general.md` reinforced rules we already follow: Swift Testing over XCTest, Swift Concurrency over Dispatch, and macOS-only APIs. Where it differs from our project steering, the project steering wins.

**What it helped us find and fix**

1. **`AppDelegate` SIGTERM handler (found at `targeted`).** The `RunLoop.main.perform` block is nonisolated but called `NSApp.terminate(nil)`, which is main-actor work. It is now wrapped in `MainActor.assumeIsolated`. That is safe because the block runs on the main run loop. The existing comment about the `.terminateLater` deadlock was kept.
2. **`WardTrigger` globals (found in Swift 6 mode).** `standardOutputSink` and `wardTriggerCatalog` were global values of non-`Sendable` type. `OutputSink` is now `@Sendable`, `TriggerSpec` is `Sendable`, and its `run` closure is `@Sendable`.
3. **`OutputCollector` test helper (found in Swift 6 mode).** It captured a mutable array in a closure. Its lines are now behind an `OSAllocatedUnfairLock` and the class is `Sendable`.
4. **`ProcessInspector` main-thread question, resolved.** The worry was that `sysctl` work in `hudContent(for:)` could run on the main actor. It cannot: `ProcessInspector` is an actor and `hudContent` is one of its methods, so the work runs on the actor's executor and `AppDelegate` only awaits it. No change needed.

**Package changes**

- `StrictConcurrency=complete` on the `GatekeepersWard` target.
- `swiftLanguageVersions: [.version("6")]` for the whole package. Tools version 5.9 has no `.v6` shorthand, so `.version("6")` is used. The tools version stays at 5.9.

**Noted, not changed**

- `StreamReader` in `TCCWatcher` is still `@unchecked Sendable`. Its safety reason is documented (`FileHandle` runs the readability handler serially). The power asks for a removal plan: switch to `Mutex` once the deployment target reaches macOS 15 (it is macOS 13 now).
- `Task.sleep(nanoseconds:)` could become `Task.sleep(for:)`. This is style only.
- `errno` is read inside a log call in `ProcessInspector.processArguments`. Copying it to a local first would be stricter.

**Open**

- Swift 6 mode now requires a Swift 6 toolchain to build the package. If judges may use Swift 5.9 or 5.10, we should decide whether to keep it. The fallback is to drop `swiftLanguageVersions` and keep `StrictConcurrency=complete`.
- Not verified: the new strict flag was confirmed to take effect at `targeted` (it produced a warning), but the `complete` build was clean, so I did not see it flag anything. The Swift 6 build did find real errors, which shows checking is on.
- Nothing is committed yet.

---

## 2026-11-10 (21:08 UTC) — Day 6: The Ward says so when it cannot watch

**iolaire (pairing with Kiro)**

Closed ward-app task 8.5b. Before this, a broken `/usr/bin/log` made the Ward retry in the background while the menu bar ghost looked healthy, so a user could believe they were protected when nothing was being watched.

- **Status stream.** `TCCWatcher` now publishes `TCCWatcherStatus` (`.running` or `.failing(failures:retryIn:)`) on a second stream that keeps only the newest value. A launch that throws is reported at once. A single exit (for example after sleep) restarts quietly, and the second failure in a row is reported. A restarted subprocess must stay alive for 5 s before the status goes back to running, so one that dies straight away cannot make the icon flicker.
- **What the user sees.** A crimson `!` badge on the menu bar icon (in the empty top-left corner), a tooltip and accessibility label that say the Ward is not watching and when it will try again, and a disabled notice at the top of the menu. A prompt alert still takes over the icon while it lasts, and the badge returns afterwards if the problem remains.
- **Tests caught two placement bugs.** The first badge position had its ring past the canvas edge and also covered the cloaked spirit's right eye. The canvas-fit test and the existing eye-contrast test both failed, so the badge moved to the top-left corner.
- **A real failure test.** `TCCWatcher` takes the `log` binary as an optional initialiser argument, and a test points it at a missing path and checks that a failing status arrives.
- **Not done.** I have not seen the badge in a live run, because that needs `/usr/bin/log` to fail on a real Mac. The decision logic, the wording, the icon pixels and a real failed launch are all tested.

---

## 2026-11-10 (20:57 UTC) — Day 6: First live test, four fixes

**iolaire (pairing with Kiro)**

First run of the new HUD and icon on a real Mac, with four notes back. All four are in the spec as task 9.

- **Menu bar icon too fine.** At its real size the detail was too small. Compact detail now has a 1.4 pt outline, eyes about 1.5 times larger, a longer bolder smile, and no gloss, rim light or sparkle highlight. The thicker outline was clipped at the canvas edge at first, so the two frames were moved and scaled to leave room.
- **Alert pulse.** The two alert frames now alternate between the normal palette and an inverted one (dark bodies, light outline and features) every 0.5 s, with the lantern raised and lowered. A test samples a point inside each body to check the flip.
- **Command box grows.** The 2-line limit is gone. The command shows up to 12 lines and the card grows with it. The old 640 pt cap became a 900 pt hard stop, and typical content is held to 720 pt by a test.
- **Plain-language request.** People do not know the service keys, so the HUD now shows the sentence Apple's dialog shows, such as `Allow “WardTrigger” to access your microphone?`, and under it the app's own reason. Both come from the app's `Info.plist` (`CFBundleDisplayName` and the `NS…UsageDescription` keys), which is read straight from disk with no extra permission. The app named is the responsible app when it differs from the process that asked. The raw service key stays, small and dim. A first guess of reading Apple's dialog text from the window list was dropped because window titles need Screen Recording permission.
- **Still open.** Checking all of this live again, a clearer title than "TCC EVENT DETECTED" for people who do not know the term, and the faint banding in the solo spirit.

---

## 2026-11-10 (20:14 UTC) — Day 6: Castle Keep visual theme, characters and HUD

**iolaire (pairing with Kiro)**

New spec `.kiro/specs/castle-keep-visual-theme` (requirements, design, tasks). It closes ward-app task 8.9 and restyles the HUD and the menu bar icon to match the reference mock.

- **Palette.** `#C7D2FE` is now a named role (`ectoplasmShade`). Three colours from the chosen SVGs joined the palette: Spirit Ink `#2E1065`, Midnight Violet `#3B185F` and Blush Pink `#F472B6`. The emoji header is gone. The palette hook allows them, and a `palette-ok` marker exempts a line (used once, to quote Apple's own "Allow" button name).
- **Characters.** Two tries at hand-built ghosts (chubby ghost plus skull spirit) were replaced by ports of `solo_spirit.svg` and `cloaked_spirit.svg`. The cloak is 22% wider, leans right with a curled hem, and loses its three vertical drape lines. `GhostGeometry` keeps the SVG coordinates as written, and one AppKit renderer (`FigureRenderer`) draws them at two detail levels.
- **Shading.** Full detail adds a darker lavender interior, a soft top light, a violet hem bounce, an inner rim light, two highlights, a violet aura and a translucent fading tail. Compact detail (menu bar) stays opaque so the icon looks the same on light and dark bars.
- **Menu bar icon.** The solo spirit sits in front of the cloaked spirit in a 24 by 22 pt image with a new lantern. The eyes are drawn opaque instead of cut out, because cut-out eyes vanished on a light bar. The old pixel tests drew at one pixel per point and passed without checking the right half of the icon; they now draw at full pixel size.
- **HUD.** A 400 pt card: gate banner (brick wall, violet portcullis, torches, three bobbing spirits, sparkles), neon title with the ghost pair, amber audit banner, indented lineage tree, risk legend chips, command box, and two non-interactive instruction pills ("Lower Portcullis" and "Let Spirit Pass"). The Ward still only informs. The window drops its view tree on dismiss so the banner animation stops.
- **Size.** A new test measures the unclamped height (the old size check read a value already clamped to the cap). The worst case first came out at 704 pt, so the master app moved beside the Lineage heading, lineage shows five rows, and the command shows two lines. All three test cases now stay under 640 pt.
- **Review drafts.** `WARD_RENDER_DRAFTS=1 swift test --filter ArtDraftRenderer` writes PNGs to `docs/Planning/Styles/drafts/` (characters, pair, menu bar poses, HUD). Normal runs write nothing.
- **Still open.** Checking the icon and HUD on a real Mac (spec tasks 4 and 8), and the faint banding in the solo spirit's lower third.

---

## 2026-11-09 (17:40 UTC) — Day 5: Category and Team Representative decided

**iolaire (pairing with Kiro)**

Closing two items from the submission review.

- **Category: Frankenstein only.** Devpost takes one category, so Costume Contest is dropped as a secondary target. The gothic Castle Keep theme stays, but the pitch now frames it as support for the Frankenstein story. This supersedes the "Frankenstein primary, Costume Contest secondary" line in the Nov 6 Plan Review entry below. `README.md` already said Frankenstein; `docs/pitch.md` was updated to match.
- **Team Representative: Iolaire McFadden.** Recorded in the README Team section. The Devpost submission form needs the same name.

---

## 2026-11-09 (17:15 UTC) — Day 5: HUD now sits beside Apple's alert

**iolaire (pairing with Kiro)**

Spec: `.kiro/specs/hud-placement-and-menubar-theme` (commit `670cf4d`). Until now the HUD always opened in the top-right corner, which could be far from Apple's dialog. It now opens 10 pt to the right of the alert, top-aligned with it.

- **Finding the alert without extra permissions.** `AlertLocator` polls the window server list every 100 ms for up to 1 s and hands each snapshot to `AlertMatcher`, a pure function that picks the window by owner name (`UserNotificationCenter`), layer (8) and non-empty bounds. It never reads window titles, so there is no Accessibility or Screen Recording prompt. The values come from the live capture in the 15:48 UTC entry.
- **Where it goes.** `PlacementCalculator` is a pure type. It flips the window server's top-left coordinates into AppKit's bottom-left space, puts the HUD 10 pt right of the alert, flips to the left side if the right would overflow, and clamps to the visible frame of the screen holding the alert centre. A HUD larger than the screen aligns to the top-left.
- **No jump.** The panel starts at alpha 0, waits for the locate result (or the 1 s timeout), moves, then fades in over 0.2 s (instantly under Reduce Motion). If the alert is not found it uses the old top-right position. A stale locate task is cancelled on the next `present` or on `dismiss()`.
- **Focus rules unchanged.** The panel is still `.nonactivatingPanel` + `.borderless` at `.floating`, shown with `orderFrontRegardless()`, and never key or main.
- **Menu bar ghost.** `GhostIcon` is now drawn in full colour in the Castle Keep palette (ectoplasm gradient body, Kiro Violet outline, Torchlight Amber lantern), not a black template. The tint on the menu bar button was removed so the colours are not altered. It renders identically under aqua and darkAqua.
- **Bigger ghost.** The icon was also enlarged to 22 x 22 pt; see the 17:13 UTC entry below.
- **Tests.** Property tests for the placement geometry (adjacency, left flip, containment, oversized HUD) and for alert matching, unit tests for `AlertLocator` with an injected window list, `GhostIcon` pixel checks and `FortressHUDWindow` style checks. 108 Swift tests in 17 suites pass.
- **Review re-run.** `docs/HACKATHON_REVIEW.md` was refreshed at `670cf4d`: 32/50 (was 30/50), Needs Work. The gap is submission material (video, write-up, README screenshots, a recorded run with a real agent), not the product. The review also found README drift: it says 81 tests (now 108), still lists an empty `Resources/` folder, and lacks the MCP venv setup steps.
- **Not yet verified by eye on a real Mac:** the placement beside a live dialog and the larger ghost. Multi-display behaviour is the open item 8.7 in the `ward-app` spec.

---

## 2026-11-09 (17:13 UTC) — Day 5: Bigger menu bar ghost

**iolaire (pairing with Kiro)**

- The menu bar ghost was hard to see at 18 x 18 pt. `GhostIcon` now renders on a 22 x 22 pt canvas.
- The artwork is still authored on the original 18 pt grid. A single affine transform (translate, scale 1.3, translate) scales it up, so the paths, eyes and lantern did not need to change. The ghost now fills about 15 x 17 pt of the menu bar height.
- The ghost is still full-colour and non-template, so it looks the same on light and dark menu bars.
- `GhostIconTests` updated for the 22 pt canvas and the transformed eye positions. All `GhostIcon` tests pass and `swift build` is clean.
- Not yet checked by eye in the running app. The knobs are `canvas` (22) and `scale` (1.3) at the top of `GhostIcon.swift`. The menu bar is about 24 pt tall, so 22 is near the practical limit.

---

## 2026-11-09 (15:48 UTC) — TCC alert window: owner and layer recorded

**iolaire (pairing with Kiro)**

Task 1.1 of `hud-placement-and-menubar-theme`: find out how the window server describes Apple's TCC dialog, so the HUD can be placed beside it without guessing.

- Added `scripts/dump_window_list.swift`. It prints owner name, layer and CG bounds from `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`. It never reads `kCGWindowName`, so no Screen Recording permission is needed. Pass an optional owner substring to filter, for example `swift scripts/dump_window_list.swift notification`.
- The first run had no dialog on screen, so nothing was recorded. A second run, taken while a WardTrigger prompt was up, found the alert.

**Recorded values (macOS 27.0.1, build 26A434, captured with a live WardTrigger dialog)**

| Field | Value |
|---|---|
| Owner name | `UserNotificationCenter` |
| Layer | `8` |
| Size | about 260 x 282 pt |

These are the defaults in `AlertLocator` (`defaultOwnerName`, `defaultLayer`). They are only verified on macOS 27; other versions may name the owner differently, which is why the HUD falls back to the top-right corner when no match is found.

**Observed for reference (no dialog present):** `Notification Center` owns layer -2147483601 windows (a notification banner), `Dock` is layer 20, menu bar `Window Server` is layer 24, regular app windows are layer 0.

---

## 2026-11-09 (15:34 UTC) — Day 5: Review follow-ups fixed (prompt tracking, restart backoff)

**iolaire (pairing with Kiro)**

Fixed most of the open follow-ups from the Dharshaneshwaran-branch review (commit `f2c2567`, `.kiro/specs/ward-app/tasks.md` section 8).

- **`PromptTracker`** (new, `App/PromptTracker.swift`). A pure, synchronous type that tracks open prompts by `msgID`. The HUD shows the newest prompt. When it is answered the previous one comes back, and only when none are left does the HUD hide and the ghost go idle. Before this, concurrent prompts replaced each other. Legacy-wording prompts with no `msgID` get a private id, so they no longer interfere with others.
- **Ghost alert no longer sticks.** `FortressHUDWindow.onAutoDismiss` ends the ghost alert and calls `PromptTracker.expire()` when the 30 s HUD timeout fires.
- **Restart backoff.** `TCCWatcher.restartDelay(afterFailures:)` doubles the delay from 2 s up to 60 s, and resets after the subprocess has run steadily for 30 s. `log stream` stderr is now drained and logged (first 500 bytes per read), so a failing subprocess leaves a trace.
- **Non-blocking shutdown.** `applicationShouldTerminate` returns `.terminateLater` while the watcher stops, instead of waiting on a semaphore on the main thread.
- **`Package.swift`** only adds the Command Line Tools plugin path when it exists, and the root-owned-process test is skipped when running as root.
- New tests: `PromptTrackerTests` and `TCCWatcherRestartTests`. `docs/architecture.md` and the README were updated to match the as-built layout.

**Still open** (kept in the spec on purpose): legacy-wording prompts still end only on the 30 s timer, because no Ventura or Sonoma result wording has been captured (8.3). `AUTHREQ_PROMPTING` arriving before its attribution is deferred, since no macOS 27 capture shows that order (8.4). A visible UI state when `log stream` cannot start (8.5b), multi-display behaviour (8.7), the Spectral Ectoplasm secondary tone (8.9) and a two-prompt manual test (8.10) are also open.

The 14:06 UTC entry below lists these items as open follow-ups; that was true when it was written.

---

## 2026-11-09 (14:06 UTC) — Day 5: Dharshaneshwaran's branch meets main

**Dharshaneshwaran**

While iolaire was adding eight triggers to WardTrigger on `main`, the `dev` branch was still on the three-service parser. Dharshaneshwaran merged `main` into `dev` and found the HUD no longer compiled: `TCCService` had gained cases for Downloads, Calendar, Reminders, Photos, Camera and Screen Capture, and the HUD's vault-name `switch` is exhaustive. Dharshaneshwaran added the six vault names (`2e1b562`), so every WardTrigger service now gets its own lore copy in the HUD instead of "Unknown Vault".

**Integration (iolaire, with Kiro).** Reviewed `origin/dev` before merging: clean build, 70 tests passing, every file under 300 lines, no force-unwraps. The one gap was process, not code: the inspector, watcher, HUD and menu bar had no spec. We wrote `.kiro/specs/ward-app` (13 requirements, a design, and a task list that records the review findings as open follow-ups), then merged `dev` into `main` with `--no-ff` so Dharshaneshwaran's five commits stay in the history under that name. Manual smoke test with WardTrigger (task 7 in the spec) done after the merge.

**Open follow-ups from the review** (all in `.kiro/specs/ward-app/tasks.md`, section 8): the ghost keeps its alert pose if the HUD auto-dismisses without a matching result; concurrent prompts replace each other; legacy-wording prompts only dismiss on the 30 s timer; the watcher restart loop has no backoff.

**State:** 70 Swift tests pass on merged `main`. Not pushed yet.

---

## 2026-11-09 (13:56 UTC) — Day 5: WardTrigger grows to 11 services

**iolaire (pairing with Kiro)**

WardTrigger only covered three TCC services (Documents, Contacts, Microphone). The agents we care about trip over more than that, so we checked `docs/Planning/WhatWeAreLookingFor(TCC).md` and added eight triggers: `desktop`, `downloads`, `calendar`, `reminders`, `camera`, `photos`, `events` (Automation, via an Apple event to Finder, the same thing `osascript` does) and `screen` (Screen Recording). All eleven were fired by hand on a real Mac and the prompts appear.

**Spec first.** The `ward-trigger` spec gained Requirement 13, a design section and task 12 before any code was written. All 41 tasks are ticked, including the manual check on a real Mac.

**Table-driven dispatch.** The three-way `switch` would not scale to eleven triggers. `TriggerCatalog.swift` now holds one list (`name`, TCC service key, usage summary, function). Dispatch, the usage text and the tests all read from it, so the usage output cannot drift from what actually dispatches. `WardTriggerBehaviors` swapped its per-trigger closures for a `triggers` dictionary; the existing stub-injection tests were adapted. The new triggers live in `FolderTriggers.swift`, `PrivacyTriggers.swift` and `AutomationTriggers.swift` (all under 90 lines).

**Trigger gotchas:**

- **Folders:** `desktop` and `downloads` share one read-only directory-listing helper with `docs`. Listing is the gated operation, not `stat`.
- **Calendar and Reminders:** use the full-access EventKit calls on macOS 14+ and the legacy ones before that. Both key families went into the plist.
- **Screen:** `CGRequestScreenCaptureAccess()` returns immediately, so the process polls for up to 60 seconds to stay alive and inspectable while the dialog is up. A timeout is not an error, since macOS may want an app restart after a grant.
- **Events:** `NSAppleScript` blocks while the dialog is displayed, so no semaphore is needed. Error `-1743` means TCC denied it.

**Parser follow-through.** `TCCService` gained named cases for Downloads, Calendar, Reminders, Photos, Camera and Screen Capture (`AppleEvents` already existed). A test fails if any WardTrigger catalog key falls through to `.unknown`, which keeps the harness and the parser in step. Unknown keys still round-trip, so nothing is dropped.

**Launcher output moved to the boot drive.** The old relay copied a staged log into the repo's `tmp/` from a background subshell, and it was unreliable on `/Volumes/Gold`: it raced the app start-up and could miss a fast trigger. `scripts/run_ward_trigger.sh` now points `open --stdout` straight at `$TMPDIR/ward-trigger.out` (per-user temp dir on the boot volume) and there is no relay. We confirmed `open --stdout` appends, so each run adds a timestamped header and its output to the same file, and `scripts/reset_ward_trigger.sh` clears it along with the TCC grants. The reset script now covers all 11 services. This supersedes the `tmp/ward-trigger.out` note in the Day 2 entry below.

**Also landed this morning:**

- Restored the stock Apache 2.0 `LICENSE` so GitHub detects it, with the copyright in `NOTICE`.
- Fixed a flaky stdout-capture test by injecting an output sink (still no reproduction of the original failure).
- Added six Kiro hooks tied to the steering docs: build/test gate, Swift standards lint, Castle Keep palette check, security-boundary guard (PreToolUse), raw-pointer review and a spec-first nudge.
- Ran the submission review into `docs/HACKATHON_REVIEW.md`: 19/50 today, low because the inspector, watcher, HUD and menu bar are still unbuilt.

**State:** 27 Swift tests and 55 Python tests pass. The code is committed to local `main` (`82695ec`) but not pushed yet.

**Next up:** specs for `ProcessInspector` and `TCCWatcher`, then Phase 2 against live WardTrigger prompts. Open question: confirm in the `com.apple.TCC` log stream which service keys the new triggers actually emit, since only the Documents, Contacts and Microphone wording has been captured so far.

---

## 2026-11-08 (08:52 UTC) — Day 4: Phase 2 and 3 land on the dev branch

**Dharshaneshwaran**

The whole runtime pipeline went in on a separate `dev` branch, in three commits across the morning (07:27 and 08:52 UTC). It was not visible on `main` until the Nov 9 merge, which is why the Day 5 notes below still call the inspector, watcher and HUD unbuilt.

**macOS 27 changes the TCC log shape.** On macOS 27.0.1 the `AUTHREQ_PROMPTING` line names only the responsible app (Zed, Cursor), not the child process that is actually asking. The child's PID sits in an earlier `AUTHREQ_ATTRIBUTION` line carrying the same `msgID`. `TCCRequestCorrelator` remembers each attribution and attaches its PID to the matching prompt, once, with oldest-first eviction at 256 entries. Without it the HUD would show the parent and miss the spirit. A new pattern D in `TCCEventParser` reads the service and responsible PID from the new wording.

**Direct requests have no accessing block.** Contacts and Microphone requests made straight by an app log only `requesting={...}`. The correlator now falls back to the requesting PID as the client. The real lines from the live Mac went into the fixtures as a test.

**What the main commit adds** (`798f4f9`):

- **`TCCWatcher`**: runs `log stream` (NDJSON, `com.apple.TCC`), rebuilds lines across chunk boundaries with `LineBuffer`, restarts the subprocess after 2 s if it dies, and emits `.prompt` and `.resolved` events. A result with `authValue=2` means allowed.
- **`ProcessInspector`**: path, argv, working directory and lineage through `sysctl(KERN_PROCARGS2)` and `proc_pidinfo`, read-only. It degrades to an "exited" or "denied" snapshot instead of failing.
- **`RiskTagger`**: flags credential files, secret words and network or encoding tools. Short tool names are matched as whole words, so `nc` does not fire inside `since`.
- **Fortress HUD**: a non-activating floating `NSPanel` with a SwiftUI card. Lineage wraps as chips, the spirit is highlighted, risk tags are crimson, and the card dismisses itself after 30 s or when its prompt resolves. Reduce Motion is respected.
- **Menu bar ghost**: drawn in code (SwiftPM cannot compile asset catalogs). Idle has half-closed eyes; a prompt wakes it with a raised lantern and a blink. The menu keeps the last 10 spirits.
- **App shell**: `GatekeepersWardApp` target and `scripts/run_ward.sh` (build, wrap in an `.app`, ad hoc sign, launch). SIGTERM goes through `NSApp.terminate` so a `pkill` cannot orphan the `log stream` child.

**Verified live** on macOS 27.0.1 with WardTrigger, and from a Kiro CLI session in Zed. 70 Swift tests: the new unit suites cover the inspector, tagger, HUD content, layout, correlator and the stream pipeline, including a random-chunking property test.

**Decision:** the HUD informs and has no buttons. "Let Spirit Pass" and "Lower Portcullis" appear as text, because Apple's dialog keeps control.

---

## 2026-11-06 (20:01 UTC) — Day 2: WardTrigger shipped end-to-end

**iolaire (pairing with ZCode)**

Implemented the full `.kiro/specs/ward-trigger` spec — all 26 tasks ticked, 24 swift-testing tests passing (5 PBT properties over the `KERN_PROCARGS2` and NDJSON parsers, dispatch stub-injection tests, and a binary smoke test). SPM package live at the repo root: `GatekeepersWard` library + `WardTrigger` executable with `com.gatekeepersward.ward-trigger` embedded in the Mach-O via `-sectcreate`.

**The hard-won part: actually making TCC prompt.** Five layers had to be right, each failing silently before it:

1. **Attribution** — a terminal child inherits the terminal's TCC identity, so `swift run WardTrigger docs` never prompts. Fixed by wrapping the binary in `.build/WardTrigger.app` and launching via LaunchServices (`scripts/run_ward_trigger.sh`); WardTrigger becomes its own responsible process.
2. **Usage-description keys** — without `NSxxxUsageDescription` in the plist, `tccd` auto-denies with no dialog (mic callback fires instantly with `granted=false`).
3. **Code-sealed bundle** — `tccd` refuses to prompt for an unsealed `.app`; `codesign --force --sign -` fixes it.
4. **The gated operation** — folder TCC intercepts directory *enumeration*, not `stat`. `triggerDocuments` now lists `~/Documents` looking for the canary; a `stat` of `~/Documents/.ward_canary` sails through ungated and looks like "already granted". (Side discovery: Terminal itself holds a standing Documents denial on this machine.)
5. **Foreground presentation** — folder-access prompts are suppressed for background agents; `LSUIElement=false` was required for the Documents dialog. Mic/Contacts prompt either way.

**Tooling notes:** `open --stdout` rejects paths on external volumes (`/Volumes/Gold`) — output is staged on the system volume and relayed to `tmp/ward-trigger.out`; `reset_ward_trigger.sh` cleans it. Recurring `-10810` from `open` after re-signing is stale LaunchServices registration — `lsregister -f .build/WardTrigger.app` fixes it. Grants bind to the ad-hoc signature, so a rebuild re-arms prompts (or needs a reset).

**Naming decision:** both helper scripts renamed to `run_ward_trigger.sh` / `reset_ward_trigger.sh` for clarity. This is a deliberate deviation from Requirement 7.2, which pins the reset script at `scripts/reset_trigger.sh`; the spec documents under `.kiro/specs/ward-trigger/` are frozen and keep the original path.

All findings recorded in `.kiro/steering/testing-strategy.md` §5 so Phase 2 (`TCCWatcher`/`ProcessInspector`) verification uses `scripts/run_ward_trigger.sh` from day one.

**Also shipped today (rest of Day 2):**

- **Planning docs** — added hackathon details (`Overview`, `Rules`, `Schedule`), `PlanReview_20261106.md`, `TestHarnessDesign.md`, and `WhatsNeeded.md`; refreshed `README`, `architecture.md`, `pitch.md`, and the project steering file from the review.
- **Visual identity** — committed the four style explorations under `docs/Planning/Styles/` and the write-up for the chosen direction, *The Castle Keep & The Wandering Spirits*.
- **License change** — the repo carries an **Apache 2.0** `LICENSE`. On Nov 9 it was restored to the unmodified stock text (the appended copyright lines made GitHub report "Other"); the copyright line now lives in `NOTICE`. `.kiro/steering/project.md` and older planning notes were updated to match.
- **Steering library** — seven new steering docs: `darwin-c-interop`, `log-stream-parsing`, `macos-security-boundaries`, `swift-coding-standards`, `swift-memory-safety`, `swiftui-hud-design`, and `testing-strategy`. Plus `docs/Planning/ScoringWell.md` to keep judging criteria in view.
- **Darwin/TCC MCP server** — wrote the `darwin-tcc-mcp-server` spec (requirements, design, tasks) and implemented it under `.kiro/tools/` in Python: SDK locator, header reader/search, C struct parser with a pre-generated known-structs table, and a TCC service registry (`tcc_services.json`). It exposes `get_darwin_struct`, `lookup_tcc_service`, and `search_darwin_headers`, is registered in `.kiro/settings/mcp.json`, and is covered by a pytest suite (including server integration tests). Usage guidance lives in `.kiro/steering/darwin-mcp-usage.md`. This lets us look up `KERN_PROCARGS2` layouts and TCC service names from the real SDK headers instead of memory.
- **Hooks** — `.kiro/hooks/build-test-gate.json` plus `scripts/git-hooks/pre-commit` enforce build and test before commit, which covers the hackathon's active-hooks requirement.
- **Early Phase 2 groundwork** — `ProcArgsParser.swift` (`KERN_PROCARGS2` buffer parser) and `TCCEventParser.swift` (NDJSON parser with regex fallback) landed alongside WardTrigger, with fixtures and PBT coverage, so Phase 2 starts with both parsers already tested.

**Housekeeping:** `.pyc` files from the MCP server tests were committed in `65d4019`; they should be untracked and ignored.

**Next up:** `ProcessInspector` (`sysctl` + `proc_pidinfo`) and `TCCWatcher` (`log stream` subprocess), verified against live WardTrigger prompts.

---

## 2026-11-06 (14:32 UTC) — Day 2: Plan Review & Strategy Lock

**iolaire & Dharshaneshwaran**

Reviewed full plan in `docs/Planning/PlanReview_20261106.md`. Key decisions locked:

**Category:** Targeting **Frankenstein ($5,000)** as primary, with **Best Demo ($1,000)** and **Costume Contest** as secondary. Optional blog/social for bonus credits.

**Deadline confirmed:** December 4, 2026 at 2:00 PM PT. Internal target: submit by December 2 for safety buffer.

**Hackathon compliance gaps identified and actioned:**
- Need `LICENSE` (MIT at the time; now Apache 2.0) at repo root — README links to it but file doesn't exist yet
- Need `.kiro/specs/` populated — judges check for spec-driven development
- Need `.kiro/hooks/` with active hooks (pre-commit build/test)
- Need Property-Based Testing on the `KERN_PROCARGS2` buffer parser and log parser

**Visual direction locked — The Castle Keep & The Wandering Spirits:**
- Obsidian background `#0E1013`, Kiro Violet `#8B5CF6`, Torchlight Amber `#F59E0B`, Mischief Crimson `#F43F5E`
- Each process in the lineage tree gets a spirit icon with a contextual tool (🔍 for `rg`, 🗝️ for shells)
- Menu bar: animated ghost (idle = floats gently; active TCC event = perks up, raises lantern)
- Action copy: "Let Spirit Pass" / "Lower Portcullis"

**Architecture insight confirmed:**
- `tccd` blocks the child process thread while the TCC dialog is open — the process stays in the Darwin process table, so `sysctl(KERN_PROCARGS2, pid)` is always reliable during a prompt. No race condition to worry about.

**WardTrigger test harness is the right first step** — must build this before touching the main app so we:
1. See exact real-world `log stream` NDJSON output on our machines
2. Can reset permissions for WardTrigger only without wiping main dev tools
3. Get a millisecond feedback loop during Core development
4. Have repeatable demo triggers for the video

**Phase roadmap confirmed:**

| Phase | Dates | Focus |
|---|---|---|
| 1 | Nov 06–08 | LICENSE, `.kiro/specs/`, `Package.swift`, `WardTrigger` |
| 2 | Nov 09–13 | `ProcessInspector` + `TCCWatcher` (console output) |
| 3 | Nov 14–19 | Fortress HUD + MenuBar ghost |
| 4 | Nov 20–23 | Real agent testing + edge case hardening |
| 5 | Nov 24–27 | PBT + unit tests + `.kiro/hooks/` |
| 6 | Nov 28–Dec 01 | Demo video + Devpost write-up + blog post |
| 7 | Dec 02–04 | Final polish + submit |

**Next up (Phase 1):**
- Add `LICENSE` (MIT at the time; now Apache 2.0) to repo root
- Create `.kiro/specs/mvp-spec.md`
- Initialize `Package.swift` (macOS 13+, no external deps yet)
- Build `WardTrigger` — three modes: filesystem access, AppleEvents, Contacts
- Write `scripts/reset_ward_trigger.sh`

---

## 2026-11-05 (16:43 UTC) — Day 1: Project Setup

**iolaire & Dharshaneshwaran**

- Defined project structure and scaffolded repo
- Wrote initial pitch, architecture overview, and contributing guide
- Set up git with `.gitignore` tuned for Swift/Xcode
- Kiro steering file in place for project context
- Created private GitHub repo, added Dharshaneshwaran as collaborator

---

<!-- Add new entries above this line -->
