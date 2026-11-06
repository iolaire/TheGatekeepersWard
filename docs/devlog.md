# Dev Log

Running notes from the build. Newest entries at the top.

---

## 2026-11-06 — Day 2 (evening): WardTrigger shipped end-to-end

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

- **Planning docs (morning)** — added hackathon details (`Overview`, `Rules`, `Schedule`), `PlanReview_20261106.md`, `TestHarnessDesign.md`, and `WhatsNeeded.md`; refreshed `README`, `architecture.md`, `pitch.md`, and the project steering file from the review.
- **Visual identity** — committed the four style explorations under `docs/Planning/Styles/` and the write-up for the chosen direction, *The Castle Keep & The Wandering Spirits*.
- **License change** — the repo now carries an **Apache 2.0** `LICENSE` (README, CONTRIBUTING, and pitch references updated). Earlier notes and `.kiro/steering/project.md` still say MIT; Apache 2.0 is OSI-approved, so it satisfies the open-source detection requirement. Worth reconciling the remaining MIT mentions.
- **Steering library** — seven new steering docs: `darwin-c-interop`, `log-stream-parsing`, `macos-security-boundaries`, `swift-coding-standards`, `swift-memory-safety`, `swiftui-hud-design`, and `testing-strategy`. Plus `docs/Planning/ScoringWell.md` to keep judging criteria in view.
- **Darwin/TCC MCP server** — wrote the `darwin-tcc-mcp-server` spec (requirements, design, tasks) and implemented it under `.kiro/tools/` in Python: SDK locator, header reader/search, C struct parser with a pre-generated known-structs table, and a TCC service registry (`tcc_services.json`). It exposes `get_darwin_struct`, `lookup_tcc_service`, and `search_darwin_headers`, is registered in `.kiro/settings/mcp.json`, and is covered by a pytest suite (including server integration tests). Usage guidance lives in `.kiro/steering/darwin-mcp-usage.md`. This lets us look up `KERN_PROCARGS2` layouts and TCC service names from the real SDK headers instead of memory.
- **Hooks** — `.kiro/hooks/build-test-gate.json` plus `scripts/git-hooks/pre-commit` enforce build and test before commit, which covers the hackathon's active-hooks requirement.
- **Early Phase 2 groundwork** — `ProcArgsParser.swift` (`KERN_PROCARGS2` buffer parser) and `TCCEventParser.swift` (NDJSON parser with regex fallback) landed alongside WardTrigger, with fixtures and PBT coverage, so Phase 2 starts with both parsers already tested.

**Housekeeping:** `.pyc` files from the MCP server tests were committed in `65d4019`; they should be untracked and ignored.

**Next up:** `ProcessInspector` (`sysctl` + `proc_pidinfo`) and `TCCWatcher` (`log stream` subprocess), verified against live WardTrigger prompts.

---

## 2026-11-06 — Day 2: Plan Review & Strategy Lock

**iolaire & Dharshaneshwaran**

Reviewed full plan in `docs/Planning/PlanReview_20261106.md`. Key decisions locked:

**Category:** Targeting **Frankenstein ($5,000)** as primary, with **Best Demo ($1,000)** and **Costume Contest** as secondary. Optional blog/social for bonus credits.

**Deadline confirmed:** December 4, 2026 at 2:00 PM PT. Internal target: submit by December 2 for safety buffer.

**Hackathon compliance gaps identified and actioned:**
- Need `LICENSE` (MIT) at repo root — README links to it but file doesn't exist yet
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
- Add `LICENSE` (MIT) to repo root
- Create `.kiro/specs/mvp-spec.md`
- Initialize `Package.swift` (macOS 13+, no external deps yet)
- Build `WardTrigger` — three modes: filesystem access, AppleEvents, Contacts
- Write `scripts/reset_ward_trigger.sh`

---

## 2026-11-05 — Day 1: Project Setup

**iolaire & Dharshaneshwaran**

- Defined project structure and scaffolded repo
- Wrote initial pitch, architecture overview, and contributing guide
- Set up git with `.gitignore` tuned for Swift/Xcode
- Kiro steering file in place for project context
- Created private GitHub repo, added Dharshaneshwaran as collaborator

---

<!-- Add new entries above this line -->
