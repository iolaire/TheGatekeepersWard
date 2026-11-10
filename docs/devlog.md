# Dev Log

Running notes from the build. Newest entries at the top.

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
