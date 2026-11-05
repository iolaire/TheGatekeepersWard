# Architecture

## Overview

Gatekeeper's Ward is a native macOS menu bar app written in Swift. It operates entirely in userspace with no kernel extensions.

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS User Session                        │
│                                                             │
│  ┌─────────────┐    TCC event     ┌──────────────────────┐  │
│  │  AI Agent   │ ───────────────► │  macOS Permission    │  │
│  │  (Cursor /  │                  │  Dialog (TCC)        │  │
│  │  Claude /   │                  └──────────────────────┘  │
│  │  Kiro etc.) │                           │                 │
│  └──────┬──────┘                           │ simultaneously  │
│         │ spawns                           ▼                 │
│  ┌──────▼──────┐   ┌──────────────────────────────────────┐ │
│  │ Child proc  │   │        Gatekeeper's Ward              │ │
│  │ (bash/node  │   │                                       │ │
│  │  /python)   │   │  ┌─────────────┐  ┌───────────────┐  │ │
│  └─────────────┘   │  │  Permission │  │  Process      │  │ │
│                    │  │  Watcher    │  │  Inspector    │  │ │
│  sysctl            │  │  (log stream│  │  (sysctl      │  │ │
│  KERN_PROCARGS2    │  │   unified)  │  │  KERN_PROCARGS│  │ │
│  ◄─────────────────│  └──────┬──────┘  └───────┬───────┘  │ │
│                    │         │                  │          │ │
│                    │         └────────┬─────────┘          │ │
│                    │                  ▼                     │ │
│                    │         ┌────────────────┐             │ │
│                    │         │  Fortress HUD  │             │ │
│                    │         │  (SwiftUI)     │             │ │
│                    │         └────────────────┘             │ │
│                    │                                        │ │
│                    │  ┌─────────────┐  ┌────────────────┐  │ │
│                    │  │  Menu Bar   │  │  Decision Log  │  │ │
│                    │  │  Controller │  │  (persistent)  │  │ │
│                    │  └─────────────┘  └────────────────┘  │ │
│                    └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Modules

### `App/`
Entry point (`@main`), app lifecycle, dependency wiring.

### `Core/` — Process Inspection Engine
The heart of the app. Given a PID, resolves the full process story:

- **`ProcessInspector`** — wraps `sysctl(KERN_PROCARGS2)` to extract binary path, argv, working directory, and environment
- **`ProcessTree`** — walks the parent chain (`KERN_PROC_PPID`) to build a readable call stack from AI agent → shell → command
- **`ProcessSnapshot`** — value type holding everything we know about a process at a point in time

Key API:
```swift
let snapshot = try ProcessInspector.snapshot(pid: 12847)
// snapshot.binaryPath → "/bin/zsh"
// snapshot.arguments  → ["-c", "find ~/Documents -name '*.pem'"]
// snapshot.parentChain → ["cursor", "node", "zsh"]
```

### `Permissions/` — TCC Event Watcher
Listens for macOS TCC permission challenge events using the unified log:

```bash
log stream --predicate 'subsystem == "com.apple.TCC"'
```

- **`TCCWatcher`** — runs `log stream` in a subprocess, parses relevant events
- **`TCCEvent`** — model: app bundle ID, resource type (Documents/Desktop/etc.), timestamp
- On event: hands PID to `ProcessInspector`, fires HUD

### `HUD/` — Fortress HUD Overlay
SwiftUI overlay window that appears alongside the TCC dialog.

- **`FortressHUDWindow`** — frameless, dark, borderless `NSPanel` positioned near the TCC dialog
- **`FortressHUDView`** — gothic-styled SwiftUI view showing process forensics
- **`ProcessCard`** — individual row component: PID, binary, path, args
- Gothic aesthetic: dark stone palette, serif headers, subtle red accent for suspicious signals

### `MenuBar/`
- **`MenuBarController`** — manages `NSStatusItem`, the skull icon, and the dropdown menu
- Menu items: Show History, Preferences, Quit

### `Resources/`
- App icon (gothic castle / skull variants)
- SF Symbol overrides
- Color assets (gothic palette)

---

## Data Flow

```
unified log event (TCC challenge)
        │
        ▼
  TCCWatcher.parse(logLine)
        │
        ▼
  ProcessInspector.snapshot(pid:)  ← sysctl KERN_PROCARGS2
        │
        ▼
  ProcessTree.walk(from: pid)      ← sysctl KERN_PROC_PPID (chain)
        │
        ▼
  FortressHUDWindow.present(snapshot:)
        │
        ▼
  User sees HUD alongside macOS dialog → makes informed Allow/Deny
        │
        ▼
  DecisionLog.record(event:decision:)
```

---

## Constraints & Non-Goals

- **No SIP bypass** — we only read process args for processes we own or that are unprotected
- **No kernel extensions** — pure userspace
- **No restricted entitlements** — ships as a normal notarised app
- **No blocking** — we inform, we don't intercept; Apple's TCC dialog remains in control
- **macOS 13+ (Ventura)** — minimum target for unified log API stability

---

## Open Questions

- [ ] Can we reliably time the HUD to appear *before* the user clicks on the TCC dialog?
- [ ] What's the latency budget between `log stream` event and HUD display?
- [ ] For child processes we don't own, are there sysctl limits we need to handle gracefully?
- [ ] Best approach for positioning the HUD window relative to the TCC dialog?
