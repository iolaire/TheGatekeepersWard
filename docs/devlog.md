# Dev Log

Running notes from the build. Newest entries at the top.

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
