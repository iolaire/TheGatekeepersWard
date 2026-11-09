# 🏰 Gatekeeper's Ward

> *"Know who knocks before you drop the gates."*

**Kiroween 2026 Hackathon Entry** — iolaire & Dharshaneshwaran

---

## What Is It?

Gatekeeper's Ward protects your Mac from the blind spots of modern AI coding agents.

When an agent like Cursor or Claude Code runs a workspace task, macOS often halts with a sudden, opaque modal: *"App wants access to your Documents folder."* You're forced to make a blind choice — **Allow** or **Don't Allow** — without knowing if it's a harmless `grep` or a rogue subshell scraping your tax returns and private keys.

We solve this with a lightweight, open-source macOS menu bar utility and a gothic Fortress HUD — **The Castle Keep**.

## How It Works

Built natively in Swift using standard Darwin kernel hooks (`sysctl KERN_PROCARGS2`) and unified log streaming, Gatekeeper's Ward requires **zero kernel extensions, zero SIP bypass, and zero restricted Apple entitlements**.

The moment a permission challenge fires, our **Fortress HUD** slides in alongside Apple's prompt, unmasking the spirit at the gate in real time:

- 👻 The master agent PID and name
- 🔍 The exact child binary path
- 🌲 The full process lineage tree (`cursor → node → zsh → ripgrep`)
- 📂 The working directory
- 📜 The full command-line arguments
- ⚠️ Automatic risk tagging for suspicious arguments (`.pem`, `.env`, `curl`, `base64`, `id_rsa`)

## The Castle Keep & The Wandering Spirits

Your macOS system is a fortified castle courtyard. Unprivileged child processes are mischievous, curious **spirits** trying to slip past the portcullis gates into protected vaults (`~/Documents`, Contacts, Camera). Gatekeeper's Ward is the **night watch lantern** — spotting these phantoms suspended mid-escape while macOS holds the gate shut.

Each step in a process chain has its own spirit icon carrying a tiny tool. The menu bar shows a cheerful floating ghost; when a TCC event fires, it perks up with wide eyes and raises a lantern.

```
┌──────────────────────────────────────────────────────────────┐
│ 👻 GATEKEEPER'S WARD              [kTCCServiceDocumentsFolder] │
├──────────────────────────────────────────────────────────────┤
│ Master App:  Cursor (PID 14201)                              │
│ Lineage:     cursor ➔ node ➔ zsh ➔ ripgrep (PID 14582)       │
├──────────────────────────────────────────────────────────────┤
│ EXECUTED COMMAND                                             │
│ $ rg "AWS_SECRET" /Users/dev/Documents                       │
├──────────────────────────────────────────────────────────────┤
│ ⚠️ Target: ~/Documents/Work/production.env   Spirit Paused   │
└──────────────────────────────────────────────────────────────┘
```

## The Kiroween Spirit

For Kiroween 2026 — a **Frankenstein** entry. We resurrect 20-year-old POSIX APIs (`sysctl KERN_PROCARGS2`), stitch them to macOS Unified Log NDJSON streaming, dress them in modern declarative SwiftUI, and deploy them against the bleeding edge of autonomous AI coding agent workflows. The lantern to inspect who is knocking before you drop the castle gates.

## Tech Stack

- **Swift 5.9+** — native macOS app, menu bar utility (macOS 13+ minimum)
- **SwiftUI + AppKit** — gothic Fortress HUD (`NSPanel`) and menu bar (`NSStatusItem`)
- **Darwin / POSIX** — `sysctl KERN_PROCARGS2` for process inspection; `proc_pidinfo` for working directory
- **Unified Log** — `log stream` NDJSON listener watching `com.apple.TCC`
- **No SIP bypass · No kernel extensions · No restricted entitlements**

## Project Structure

```
GatekeepersWard/
├── App/            Entry point & app lifecycle
├── Core/           Process inspection engine (sysctl, log streaming)
├── HUD/            Fortress HUD overlay (SwiftUI + NSPanel)
├── MenuBar/        Menu bar controller & ghost status icon
├── Permissions/    TCC permission event watcher
└── Resources/      Assets & gothic iconography
GatekeepersWardTests/
WardTrigger/        Test harness — triggers TCC prompts on demand
scripts/            run_ward_trigger.sh (prompt launcher), reset_ward_trigger.sh, dev utilities
docs/               Planning, architecture, devlog
```

## Quick Start

> Requires the Swift toolchain (Xcode 15+ or Command Line Tools) and macOS 13+.

```bash
git clone https://github.com/iolaire/TheGatekeepersWard.git
cd TheGatekeepersWard
swift build          # builds the GatekeepersWard library and WardTrigger CLI
swift test           # 81 tests incl. 5 property-based suites
scripts/run_ward.sh  # builds and launches the menu bar app (stop: scripts/run_ward.sh --stop)
```

**Trigger a real TCC prompt** (attributed to WardTrigger's own bundle ID —
never launched as a terminal child, or macOS attributes the decision to the
terminal instead):

```bash
touch ~/Documents/.ward_canary                # canary file, created once
scripts/run_ward_trigger.sh docs rg "AWS_SECRET" ~/Documents/prod.env
cat "${TMPDIR}ward-trigger.out"                      # captured prompt outcome
scripts/reset_ward_trigger.sh                      # re-arm first-prompt state
```

Subcommands: `docs`, `desktop`, `downloads`, `contacts`, `calendar`,
`reminders`, `photos`, `mic`, `camera`, `events` (AppleEvents), `screen`. Run
the binary with no arguments for the list. The extra arguments are echoed and included in argv for demo
realism. See `docs/architecture.md` for details.

## Hackathon Category

**Frankenstein ($5,000)** — stitching low-level POSIX kernel APIs, macOS Unified Log streaming, SwiftUI, and autonomous AI agent workflows into one coherent tool.

**Submission deadline:** December 4, 2026 at 2:00 PM PT

## Team

- **Iolaire McFadden** (iolaire), Team Representative
- **Dharshaneshwaran**

## License

Apache 2.0 — see [LICENSE](LICENSE)
