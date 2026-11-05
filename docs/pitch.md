# Gatekeeper's Ward — Hackathon Pitch

**Kiroween 2026 | Team: iolaire & Dharshaneshwaran**

---

## The Problem

Modern AI coding agents (Cursor, Claude Code, Kiro, etc.) operate autonomously inside your filesystem. When they trigger a macOS TCC (Transparency, Consent, and Control) permission dialog, you see only:

> *"XYZ app would like to access your Documents folder."*

You have no context. Is this:
- A benign `cat README.md`?
- A subshell doing `find ~/Documents -name "*.pem"`?
- Something worse?

You're forced to **Allow** or **Don't Allow** blind.

---

## The Solution

**Gatekeeper's Ward** — a lightweight macOS menu bar utility that intercepts permission challenges and immediately shows you a gothic forensic HUD alongside Apple's own dialog:

| Field | Example |
|---|---|
| Requesting agent PID | `12847 (cursor)` |
| Child process binary | `/bin/zsh` |
| Working directory | `/Users/iolaire/Projects/myapp` |
| Full command line | `zsh -c "find ~/Documents -name '*.pem'"` |
| Parent chain | `cursor → node → zsh` |

You can now make an **informed** decision.

---

## Why It's Compelling for Kiroween

This is the ultimate Frankenstein project:
- 🧟 **POSIX undead**: `sysctl KERN_PROCARGS2` — a 20-year-old Unix API, resurrected
- 🏰 **Gothic UI**: full fortress HUD overlay in SwiftUI
- 🤖 **AI-agent native**: purpose-built for the agentic coding era
- 🕯️ **Zero dark magic**: no kernel extensions, no SIP bypass, no scary entitlements

---

## Differentiators

- **No kernel extension required** — pure userspace, ships as a notarised .app
- **Open source** — developers can audit and trust it
- **Zero config** — install, run, done
- **Real-time** — HUD appears the instant the permission dialog fires, not after

---

## Demo Flow (for judges)

1. Launch Gatekeeper's Ward → gothic skull appears in menu bar
2. Open Cursor / Claude Code, trigger a permission-requiring action
3. macOS shows its dialog — simultaneously, our Fortress HUD pops up
4. HUD reveals: agent PID, child binary, working directory, full args
5. Developer makes informed choice; HUD logs decision to history

---

## Future (post-hackathon)

- Allow/block rules engine (auto-deny suspicious patterns)
- Brew install distribution
- Integration with popular agent frameworks' audit logs
- iOS companion (for remote monitoring)
