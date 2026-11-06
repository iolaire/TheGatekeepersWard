# Architecture

## Overview

Gatekeeper's Ward is a native macOS menu bar app written in Swift. It operates entirely in userspace — no kernel extensions, no SIP bypass, no restricted Apple entitlements.

The lore: your macOS system is a **fortified castle courtyard**. Unprivileged child processes are mischievous **wandering spirits** trying to slip past the portcullis gates into protected vaults (`~/Documents`, Contacts, Camera). Gatekeeper's Ward is the **night watch lantern** — spotting these phantoms suspended mid-escape while macOS holds the gate shut.

---

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      macOS User Session                          │
│                                                                 │
│  ┌─────────────┐    TCC event     ┌────────────────────────┐    │
│  │  AI Agent   │ ───────────────► │  macOS TCC Dialog      │    │
│  │  (Cursor /  │                  │  "App wants access…"   │    │
│  │  Claude /   │                  └────────────────────────┘    │
│  │  Kiro etc.) │                           │                    │
│  └──────┬──────┘                           │ simultaneously     │
│         │ spawns                           ▼                    │
│  ┌──────▼──────┐   ┌────────────────────────────────────────┐   │
│  │ Child proc  │   │          Gatekeeper's Ward              │   │
│  │ (bash/node/ │   │                                        │   │
│  │  python/rg) │   │  ┌──────────────┐  ┌────────────────┐  │   │
│  └─────────────┘   │  │  TCCWatcher  │  │ ProcessInspect │  │   │
│                    │  │  log stream  │  │ sysctl         │  │   │
│  sysctl            │  │  NDJSON      │  │ KERN_PROCARGS2 │  │   │
│  KERN_PROCARGS2 ◄──│  └──────┬───────┘  └───────┬────────┘  │   │
│                    │         │                   │           │   │
│                    │         └─────────┬──────────┘           │   │
│                    │                   ▼                      │   │
│                    │        ┌──────────────────┐              │   │
│                    │        │  Fortress HUD     │              │   │
│                    │        │  NSPanel floating │              │   │
│                    │        │  SwiftUI view     │              │   │
│                    │        └──────────────────┘              │   │
│                    │                                          │   │
│                    │  ┌──────────────┐  ┌──────────────────┐  │   │
│                    │  │  MenuBar     │  │  Decision Log    │  │   │
│                    │  │  Ghost icon  │  │  (persistent)    │  │   │
│                    │  └──────────────┘  └──────────────────┘  │   │
│                    └────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Modules

### `App/`
`@main` entry point, `AppDelegate`, dependency wiring, and app lifecycle. Owns the top-level object graph.

### `Core/` — Process Inspection Engine

The forensic heart of the app. Given a PID, resolves the full process story using only unprivileged Darwin APIs.

- **`ProcessInspector`** — wraps `sysctl(KERN_PROCARGS2)` to extract binary path, argv, and environment; uses `proc_pidinfo(PROC_PIDVNODEPATHINFO)` for working directory
- **`ProcessTree`** — walks the parent chain via `sysctl(KERN_PROC_PID)` to build the full lineage from AI agent → child shell → command
- **`ProcessSnapshot`** — immutable value type holding everything known about a process at a point in time

```swift
let snapshot = try ProcessInspector.snapshot(pid: 14582)
// snapshot.binaryPath  → "/usr/local/bin/rg"
// snapshot.arguments   → ["rg", "AWS_SECRET", "/Users/dev/Documents"]
// snapshot.parentChain → ["cursor", "node", "zsh", "rg"]
// snapshot.workingDir  → "/Users/dev/Projects/myapp"
```

**Key insight:** when macOS fires a TCC prompt, `tccd` puts the requesting process thread to sleep until the user clicks Allow/Don't Allow. The process stays in the Darwin process table — `sysctl(KERN_PROCARGS2, pid)` will succeed reliably because the process cannot exit while the dialog is active.

### `Permissions/` — TCC Event Watcher

Listens for macOS TCC permission challenge events using the unified log.

- **`TCCWatcher`** — runs `/usr/bin/log stream` as a background subprocess; parses NDJSON lines for events in `subsystem == "com.apple.TCC"`; extracts `clientPID` and `responsiblePID`
- **`TCCEvent`** — model: service key, client PID, responsible PID, timestamp
- Parser supports both structured NDJSON fields and regex fallback on `eventMessage` to handle wording changes across macOS versions (Ventura / Sonoma / Sequoia)

On event: hands PIDs to `ProcessInspector`, fires HUD.

### `HUD/` — Fortress HUD Overlay

SwiftUI overlay that appears alongside the TCC dialog. Non-activating — key focus stays on Apple's native dialog.

- **`FortressHUDWindow`** — frameless `NSPanel`:
  - `styleMask: [.nonactivatingPanel, .borderless]`
  - `level: .floating` (appears over normal windows without stealing focus)
  - Positioned near upper-right, offset from native TCC prompt
- **`FortressHUDView`** — SwiftUI view with The Castle Keep aesthetic
- **`ProcessLineageView`** — animated lineage tree: each process node has a spirit icon with a contextual tool (🔍 for `rg`, 🗝️ for shell scripts)
- **`RiskTagView`** — highlights suspicious arguments in Mischief Crimson (`#F43F5E`): `.pem`, `.env`, `id_rsa`, `curl`, `base64`, `nc`

### `MenuBar/`

- **`MenuBarController`** — manages `NSStatusItem` with animated ghost icon
  - Idle state: ghost floats gently
  - Active TCC event: ghost perks up, wide eyes, raises lantern
- Dropdown: past permission challenges history, preferences, quit

### `WardTrigger/` (Test Harness)

Isolated SPM executable with its own bundle ID (`com.gatekeepersward.ward-trigger`, embedded via a `-sectcreate __TEXT __info_plist` linker flag). Triggers TCC prompts on demand without disrupting the main dev environment.

- Mode 1 (`docs`): Documents folder — read-only `contentsOfDirectory(~/Documents)` probe for `~/Documents/.ward_canary` (directory enumeration is what `tccd` gates; a plain `stat` is not intercepted)
- Mode 2 (`contacts`): Contacts — `CNContactStore.requestAccess(for: .contacts)`
- Mode 3 (`mic`): Microphone — `AVCaptureDevice.requestAccess(for: .audio)`
- Dispatch: `Dispatch.swift` — `runWardTriggerDispatch(arguments:behaviors:)` with closure injection so tests stub the triggers; `main.swift` wires the live implementations
- Companion: `scripts/run_ward_trigger.sh` — wraps the binary in `.build/WardTrigger.app` and launches via LaunchServices so prompts are attributed to WardTrigger's bundle ID instead of the terminal; captured stdout lands in `tmp/ward-trigger.out`
- Companion: `scripts/reset_ward_trigger.sh` — one command to reset TCC permissions for WardTrigger only (and clean `tmp/ward-trigger.out`)

### `Resources/`

- App icon: ghost with lantern variants
- Menu bar icons: ghost idle / ghost alert states
- Color assets: The Castle Keep palette (see below)

---

## Visual Design — The Castle Keep Palette

| Token | Hex | Role |
|---|---|---|
| Spectral Ectoplasm | `#E0E7FF` / `#C7D2FE` | Ghost figures, translucent glow |
| Kiro Violet | `#8B5CF6` | Portcullis bars, lineage tree nodes, headers |
| Torchlight Amber | `#F59E0B` | Suspended status badge, lantern glow, warnings |
| Obsidian Slate | `#0E1013` | Background (frosted acrylic `.ultraThinMaterial`) |
| Mischief Crimson | `#F43F5E` | Suspicious argument highlight |
| Wrought Iron | `#2D3139` | Border / panel edge |

---

## Data Flow

```
unified log event (TCC challenge fires)
        │
        ▼
  TCCWatcher.parse(ndjsonLine)          ← /usr/bin/log stream subprocess
        │
        ▼
  ProcessInspector.snapshot(pid:)       ← sysctl KERN_PROCARGS2
        │
        ▼
  ProcessTree.walk(from: pid)           ← sysctl KERN_PROC_PID chain
        │
        ▼
  FortressHUDWindow.present(snapshot:)  ← NSPanel .floating, non-activating
        │
        ▼
  User sees HUD alongside macOS dialog  → informed Allow / Deny
  ("Let Spirit Pass" / "Lower Portcullis")
        │
        ▼
  DecisionLog.record(event:, decision:) ← persisted history in menu bar
```

---

## Implementation Roadmap

| Phase | Dates | Focus |
|---|---|---|
| 1 | Nov 06–08 | LICENSE, `.kiro/specs/`, `Package.swift`, `WardTrigger` test harness |
| 2 | Nov 09–13 | `ProcessInspector`, `TCCWatcher`, console verification |
| 3 | Nov 14–19 | `FortressHUDWindow`, `FortressHUDView`, `MenuBarController` |
| 4 | Nov 20–23 | Real agent testing (Cursor/Claude/Kiro), edge case hardening |
| 5 | Nov 24–27 | Property-Based Testing, unit tests, `.kiro/hooks/` |
| 6 | Nov 28–Dec 01 | Demo video (≤3 min), Devpost write-up, blog post |
| 7 | Dec 02–04 | Final polish, buffer, submit |

**Deadline:** December 4, 2026 at 2:00 PM PT

---

## Constraints & Non-Goals

- **No SIP bypass** — purely unprivileged userspace
- **No kernel extensions** — zero `KEXT` or `DriverKit`
- **No restricted entitlements** — ships as a standard notarised `.app`
- **No blocking** — we inform; Apple's TCC dialog retains full control
- **macOS 13+ (Ventura)** — minimum target for unified log API stability
- **i18n** — post-MVP only, after fully functional English release

---

## Open Questions

- [ ] Can we reliably time the HUD to appear *before* the user clicks the TCC dialog? (Answer: yes — `tccd` blocks the child process thread until user responds)
- [ ] Exact `log stream` NDJSON field names for `clientPID` / `responsiblePID` across Ventura / Sonoma / Sequoia?
- [ ] Best window position strategy: fixed upper-right vs. dynamically offset near native TCC dialog?
- [ ] Multi-monitor handling — which screen does the TCC dialog appear on?
- [ ] PBT framework: `swift-testing` property tests or a third-party like `SwiftCheck`?
