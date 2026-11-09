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

- **`ProcessInspector`** — an actor wrapping `sysctl(KERN_PROCARGS2)` (parsed by `ProcArgsParser`) for argv, `proc_pidpath` for the binary, and `proc_pidinfo(PROC_PIDVNODEPATHINFO)` for the working directory. It also walks the parent chain (`KERN_PROC_PID`, depth-capped, loop-safe) to build the lineage from AI agent → child shell → command; there is no separate `ProcessTree` type
- **`ProcessSnapshot`** — immutable value type holding everything known about a process at a point in time, with `exitedBeforeInspection` and `inspectionDenied` flags for graceful degradation
- **`RiskTagger`** — flags credential files, secret-path words, and network or encoding tools in argv

```swift
let snapshot = await ProcessInspector.shared.snapshot(pid: 14582)
// snapshot.executablePath   → "/usr/local/bin/rg"
// snapshot.arguments        → ["rg", "AWS_SECRET", "/Users/dev/Documents"]
// snapshot.lineage          → [cursor, node, zsh, rg]   (ProcessNode values, oldest first)
// snapshot.workingDirectory → "/Users/dev/Projects/myapp"
```

**Key insight:** when macOS fires a TCC prompt, `tccd` puts the requesting process thread to sleep until the user clicks Allow/Don't Allow. The process stays in the Darwin process table — `sysctl(KERN_PROCARGS2, pid)` will succeed reliably because the process cannot exit while the dialog is active.

### `Permissions/` — TCC Event Watcher

Listens for macOS TCC permission challenge events using the unified log.

- **`TCCWatcher`** — an actor that runs `/usr/bin/log stream` as a background subprocess for `subsystem == "com.apple.TCC"` and publishes `.prompt` and `.resolved` events on an `AsyncStream`. It restarts the subprocess with backoff (2 s, doubling to 60 s) and logs its stderr
- **`LineBuffer`** — rebuilds whole lines from stdout chunks of any size
- **`TCCEventParser`** (`extractTCCEvent`) — decodes the NDJSON line and falls back to regex on `eventMessage`. Defines `TCCEvent` (service key, client PID, responsible PID) and `TCCService`. Handles the Ventura and Sonoma wordings plus the macOS 27 `AUTHREQ_*` wording
- **`TCCRequestCorrelator`** — on macOS 27 the prompt line names only the responsible app, while the child that is asking appears in an earlier `AUTHREQ_ATTRIBUTION` line with the same `msgID`. The correlator joins them so the HUD shows the child
- **`TCCEventPipeline`** — pure line-in, event-out step that ties these together (`.resolved` when an `AUTHREQ_RESULT` arrives)

On a prompt: `AppDelegate` hands the PIDs to `ProcessInspector`, builds `HUDContent` and shows the HUD.

### `HUD/` — Fortress HUD Overlay

SwiftUI overlay that appears alongside the TCC dialog. Non-activating — key focus stays on Apple's native dialog.

- **`FortressHUDWindow`** — frameless `NSPanel`:
  - `styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]`
  - `level: .floating` (appears over normal windows without stealing focus); never key or main
  - Positioned at the top-right of the main screen; hides itself after 30 s if no result arrives
- **`HUDContent`** — view-model: the prompt, the inspected spirit, the master app, risk tags, and a status ("Spirit Paused at the Gate", "Suspicious Spirit", "Slipped Through", "Origins Are Veiled"). Also holds the vault names and the process-to-icon table (SF Symbols, for example a magnifier for `rg` and a key for shells)
- **`FortressHUDView`** — SwiftUI view with The Castle Keep aesthetic. It contains two subviews, not separate files:
  - **`ProcessLineageView`** — the lineage as wrapping chips (laid out by `FlowLayout`) with the spirit highlighted
  - **`RiskTagView`** — highlights suspicious arguments in Mischief Crimson (`#F43F5E`)
- **`CastlePalette`** — the palette as code constants
- The HUD informs only. "Let Spirit Pass" and "Lower Portcullis" appear as text; Apple's dialog decides

### `App/` — prompt tracking

`AppDelegate` owns a `PromptTracker`, which keeps every open prompt by `msgID`. The HUD shows the newest; answering it brings the previous one back; the HUD hides and the ghost goes idle only when none are left.

### `MenuBar/`

- **`MenuBarController`** — manages `NSStatusItem` with the ghost icon
  - Idle state: sleepy eyes, no lantern
  - Active TCC event: wide eyes, lantern raised and lowered every 0.8 s
- **`GhostIcon`** — the ghost is drawn in code as a template image
- Dropdown: the last 10 spirits with relative times, Clear History, About, Quit

### `WardTrigger/` (Test Harness)

Isolated SPM executable with its own bundle ID (`com.gatekeepersward.ward-trigger`, embedded via a `-sectcreate __TEXT __info_plist` linker flag). Triggers TCC prompts on demand without disrupting the main dev environment.

- Mode 1 (`docs`): Documents folder — read-only `contentsOfDirectory(~/Documents)` probe for `~/Documents/.ward_canary` (directory enumeration is what `tccd` gates; a plain `stat` is not intercepted)
- Mode 2 (`contacts`): Contacts — `CNContactStore.requestAccess(for: .contacts)`
- Mode 3 (`mic`): Microphone — `AVCaptureDevice.requestAccess(for: .audio)`
- Dispatch: `Dispatch.swift` — `runWardTriggerDispatch(arguments:behaviors:)` with closure injection so tests stub the triggers; `main.swift` wires the live implementations
- Companion: `scripts/run_ward_trigger.sh` — wraps the binary in `.build/WardTrigger.app` and launches via LaunchServices so prompts are attributed to WardTrigger's bundle ID instead of the terminal; captured stdout lands in `$TMPDIR/ward-trigger.out`
- Companion: `scripts/reset_ward_trigger.sh` — one command to reset TCC permissions for WardTrigger only (and clean `$TMPDIR/ward-trigger.out`)

### `Resources/`

Currently empty by design. SwiftPM cannot compile asset catalogs, so the ghost icon (`GhostIcon`) and the palette (`CastlePalette`) are code. An app icon for the `.app` bundle is still to do.

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
  /usr/bin/log stream → LineBuffer      ← whole NDJSON lines
        │
        ▼
  TCCEventPipeline                      ← TCCEventParser + TCCRequestCorrelator
        │                                  (.prompt / .resolved events)
        ▼
  ProcessInspector.snapshot(pid:)       ← sysctl KERN_PROCARGS2, lineage walk
        │
        ▼
  RiskTagger → HUDContent               ← status, master app, risk tags
        │
        ▼
  FortressHUDWindow.present(content)    ← NSPanel .floating, non-activating
  MenuBarController.recordPrompt        ← ghost alert, recent-spirits list
        │
        ▼
  User sees HUD alongside macOS dialog  → informed Allow / Deny
  ("Let Spirit Pass" / "Lower Portcullis")
        │
        ▼
  .resolved event (same msgID)          → PromptTracker: HUD hides, ghost idles
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

- [x] Can we reliably time the HUD to appear *before* the user clicks the TCC dialog? (Answer: yes — `tccd` blocks the child process thread until user responds)
- [ ] Exact `log stream` NDJSON field names for `clientPID` / `responsiblePID` across Ventura / Sonoma / Sequoia?
- [x] Best window position strategy: fixed upper-right vs. dynamically offset near native TCC dialog? (Answer: dynamic. The HUD sits 10 pt right of the alert found through the window list, with a top-right fallback.)
- [ ] Multi-monitor handling — which screen does the TCC dialog appear on?
- [x] PBT framework: `swift-testing` property tests or a third-party like `SwiftCheck`? (Answer: `swift-testing` with seeded generator loops of 100+ iterations; no extra dependency.)
