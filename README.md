# 🏰 Gatekeeper's Ward

> *"Know who knocks before you drop the gates."*

**Kiroween 2026 Hackathon Entry** — iolaire & Dharshaneshwaran

---

## What Is It?

Gatekeeper's Ward protects your Mac from the blind spots of modern AI coding agents.

When an agent like Cursor or Claude Code runs a workspace task, macOS often halts with a sudden, opaque modal: *"App wants access to your Documents folder."* You're forced to make a blind choice — **Allow** or **Don't Allow** — without knowing if it's a harmless `grep` or a rogue subshell scraping your tax returns and private keys.

We solve this with a lightweight, open-source macOS menu bar utility and gothic forensic HUD.

## How It Works

Built natively in Swift using standard Darwin kernel hooks (`sysctl KERN_PROCARGS2`) and unified log streaming, Gatekeeper's Ward requires **zero kernel extensions or restricted Apple entitlements**.

The moment a permission challenge fires, our **Fortress HUD** pops up alongside Apple's prompt, unmasking the intruder in real time:

- 🔍 The master agent PID
- 💀 The exact child binary path
- 📂 Its working directory
- 📜 The full command-line arguments

## The Kiroween Spirit

For Kiroween 2026 — the ultimate Frankenstein entry. We stitch low-level POSIX process internals directly into high-level agentic workflows. We give developers the lantern to inspect who is knocking before they drop the castle gates.

## Tech Stack

- **Swift** — native macOS app, menu bar utility
- **SwiftUI** — gothic Fortress HUD overlay
- **Darwin / POSIX** — `sysctl KERN_PROCARGS2` for process inspection
- **Unified Log** — `log stream` for TCC/permission event detection
- **No SIP bypass, no kernel extensions, no restricted entitlements**

## Project Structure

```
GatekeepersWard/
├── App/            Entry point & app lifecycle
├── Core/           Process inspection engine (sysctl, log streaming)
├── HUD/            Fortress HUD overlay (SwiftUI)
├── MenuBar/        Menu bar controller & status icon
├── Permissions/    TCC permission event watcher
└── Resources/      Assets & gothic iconography
```

## Team

- **iolaire** 
- **Dharshaneshwaran**

## License

MIT — see [LICENSE](LICENSE)
