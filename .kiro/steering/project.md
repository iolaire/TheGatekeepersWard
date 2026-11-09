# Gatekeeper's Ward — Project Steering

## What This Project Is

A native macOS menu bar utility and gothic Fortress HUD for Kiroween 2026 hackathon.
**Team:** iolaire & Dharshaneshwaran.
**Submission deadline:** December 4, 2026 at 2:00 PM PT.

**Core purpose:** When an AI coding agent triggers a macOS TCC permission dialog, detect the event via Unified Log streaming and display a SwiftUI Fortress HUD alongside Apple's prompt — showing full process forensics: PID, binary, working directory, command-line args, process lineage tree, and automatic risk tagging for suspicious arguments.

## The Lore

The macOS system is a **fortified castle courtyard**. Child processes are mischievous **wandering spirits** trying to slip through the portcullis gates into protected vaults (`~/Documents`, Contacts, Camera). Gatekeeper's Ward is the **night watch lantern** — spotting phantoms suspended mid-escape while macOS holds the gate shut.

## Tech Stack

- **Language:** Swift 5.9+, macOS 13 (Ventura) minimum target
- **UI:** SwiftUI for the Fortress HUD; AppKit (`NSStatusItem`, `NSPanel`) for menu bar and overlay window
- **Process inspection:** `sysctl(KERN_PROCARGS2)` + `proc_pidinfo(PROC_PIDVNODEPATHINFO)` — no kernel extensions, no restricted entitlements
- **Event detection:** `/usr/bin/log stream` subprocess watching `com.apple.TCC`, parsing NDJSON with regex fallback
- **No SIP bypass · No kernel extensions · No restricted entitlements**

## Project Layout

```
GatekeepersWard/
├── App/               @main entry, AppDelegate, dependency wiring
├── Core/              ProcessInspector, ProcessTree, ProcessSnapshot
├── HUD/               FortressHUDWindow (NSPanel), FortressHUDView, ProcessLineageView, RiskTagView
├── MenuBar/           MenuBarController (NSStatusItem, animated ghost icon)
├── Permissions/       TCCWatcher, TCCEvent
└── Resources/         Icons (ghost variants), color assets (Castle Keep palette)
GatekeepersWardTests/
WardTrigger/           Test harness app (com.gatekeepersward.ward-trigger)
scripts/               run_ward_trigger.sh, reset_ward_trigger.sh, dev utilities
docs/                  pitch.md, architecture.md, devlog.md, Planning/
.kiro/
├── steering/          project.md (this file)
├── specs/             mvp-spec.md (spec-driven development — scored by judges)
└── hooks/             pre-commit build & test hooks
```

## Visual Design — The Castle Keep Palette

| Token | Hex | Role |
|---|---|---|
| Spectral Ectoplasm | `#E0E7FF` / `#C7D2FE` | Ghost figures, translucent glow |
| Kiro Violet | `#8B5CF6` | Portcullis bars, lineage tree nodes, primary headers |
| Torchlight Amber | `#F59E0B` | Suspended status badge, lantern glow, elevated warnings |
| Obsidian Slate | `#0E1013` | Background (frosted acrylic `.ultraThinMaterial`) |
| Mischief Crimson | `#F43F5E` | Suspicious argument highlight (`.pem`, `.env`, `id_rsa`, `curl`, `base64`) |
| Wrought Iron | `#2D3139` | Border / panel edge |

**UI copy:** "Let Spirit Pass" (Allow) / "Lower Portcullis" (Deny). Process status: "Spirit Paused at the Gate".

## Key Design Decisions

- We **inform**, we don't intercept — Apple's TCC dialog retains full control
- `tccd` blocks the child process thread while the dialog is open — the process stays in the Darwin process table, so `sysctl` inspection is always reliable during a prompt (no race condition)
- `NSPanel` must use `styleMask: [.nonactivatingPanel, .borderless]` at `.floating` level — never steal key focus from Apple's dialog
- NDJSON log parser must have a regex fallback on `eventMessage` to handle TCC log wording changes across macOS versions
- Graceful degradation: if the child process has already exited (edge case), show partial info with a note
- Each process node in the lineage tree has a spirit icon with a contextual tool (🔍 for `rg`, 🗝️ for shell scripts)
- Menu bar ghost: idle = floats gently; TCC event fires = perks up, wide eyes, raises lantern

## Hackathon Compliance Requirements

These are judging requirements — not optional:
- Apache 2.0 `LICENSE` file at repo root, unmodified stock text so GitHub detects it (copyright lives in `NOTICE`)
- `.kiro/specs/` populated with formal specs (scores in Technological Implementation 20%)
- `.kiro/hooks/` with active hooks (pre-commit build / test enforcement)
- Property-Based Testing on `KERN_PROCARGS2` buffer parser and `log stream` NDJSON parser
- Demo video ≤3 minutes on a real Mac

## Coding Standards

- Follow Swift API Design Guidelines
- No force-unwrap (`!`) in production paths — use `guard` or `if let`
- Max ~300 lines per file; extract to new types when growing
- Every public type and function has a doc comment (`///`)
- Prefer value types (`struct`) over classes unless reference semantics are needed

## Phase Roadmap

| Phase | Dates | Focus |
|---|---|---|
| 1 | Nov 06–08 | `LICENSE`, `.kiro/specs/`, `Package.swift`, `WardTrigger` test harness |
| 2 | Nov 09–13 | `ProcessInspector` + `TCCWatcher` (console verification) |
| 3 | Nov 14–19 | Fortress HUD (`NSPanel` + SwiftUI) + MenuBar ghost |
| 4 | Nov 20–23 | Real agent testing + edge case hardening |
| 5 | Nov 24–27 | PBT + unit tests + `.kiro/hooks/` |
| 6 | Nov 28–Dec 01 | Demo video + Devpost + blog post |
| 7 | Dec 02–04 | Final polish + submit |

## Planning Docs

- `docs/pitch.md` — hackathon pitch, prize strategy, demo storyboard
- `docs/architecture.md` — full data flow, module breakdown, Castle Keep palette
- `docs/devlog.md` — running day notes and decisions
- `docs/Planning/PlanReview_20261106.md` — detailed strategic review
- `docs/Planning/WhatWeAreBuildingShort.md` — concise technical approach
- `docs/Planning/WhatsNeeded.md` — deliverable checklist and test harness design
