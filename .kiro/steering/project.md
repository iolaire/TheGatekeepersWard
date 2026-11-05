# Gatekeeper's Ward — Project Steering

## What This Project Is

A native macOS menu bar utility and gothic forensic HUD for Kiroween 2026 hackathon.
**Team:** iolaire & Dharshaneshwaran.

**Core purpose:** When an AI coding agent triggers a macOS TCC permission dialog, intercept the event and display a SwiftUI HUD alongside Apple's prompt, showing the full process forensics (PID, binary, working directory, command-line args, parent chain).

## Tech Stack

- **Language:** Swift (Swift 5.9+, macOS 13+ minimum target)
- **UI:** SwiftUI for the Fortress HUD; AppKit (`NSStatusItem`, `NSPanel`) for the menu bar and overlay window
- **Process inspection:** `sysctl(KERN_PROCARGS2)` — no kernel extensions, no restricted entitlements
- **Event detection:** `log stream` subprocess watching `com.apple.TCC` subsystem via unified log
- **No SIP bypass, no kernel extensions, no restricted entitlements**

## Project Layout

```
GatekeepersWard/
├── App/            @main entry, AppDelegate, dependency wiring
├── Core/           ProcessInspector, ProcessTree, ProcessSnapshot
├── HUD/            FortressHUDWindow, FortressHUDView, ProcessCard (SwiftUI)
├── MenuBar/        MenuBarController (NSStatusItem)
├── Permissions/    TCCWatcher, TCCEvent
└── Resources/      Icons, color assets
docs/               pitch.md, architecture.md, devlog.md
```

## Coding Standards

- Follow Swift API Design Guidelines
- No force-unwrap (`!`) in production paths — use `guard` or `if let`
- Max ~300 lines per file; extract to new types when growing
- Every public type and function has a doc comment (`///`)
- Prefer value types (`struct`) over classes unless reference semantics are needed

## Key Design Decisions

- We **inform**, we don't intercept — Apple's TCC dialog stays in control
- The HUD must appear with minimal latency after the TCC log event fires
- Graceful degradation: if the child process has already exited before we can inspect, show partial info with a note
- Gothic aesthetic: dark stone colour palette, subtle red accent for suspicious-looking commands

## Planning Docs

- See `docs/pitch.md` for the hackathon pitch and demo flow
- See `docs/architecture.md` for the full data flow and module breakdown
- See `docs/devlog.md` for running notes and day-to-day decisions
