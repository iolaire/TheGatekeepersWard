# Dev Log

Running notes from the build. Newest entries at the top.

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
- Write `scripts/reset_trigger.sh`

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
