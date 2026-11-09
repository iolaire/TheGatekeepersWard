# Gatekeeper's Ward — Hackathon Pitch

**Kiroween 2026 | Team: iolaire & Dharshaneshwaran**

---

## The Problem

Modern AI coding agents (Cursor, Claude Code, Kiro, GitHub Copilot Workspace) operate autonomously inside your filesystem. When they trigger a macOS TCC (Transparency, Consent, and Control) permission dialog, you see only:

> *"XYZ app would like to access your Documents folder."*

You have no context. Is this:
- A benign `cat README.md`?
- A subshell doing `find ~/Documents -name "*.pem"`?
- A `rg "AWS_SECRET_KEY" ~/Documents/prod.env`?

You're forced to **Allow** or **Don't Allow** blind.

---

## The Solution

**Gatekeeper's Ward** — a lightweight macOS menu bar utility that intercepts permission challenges and immediately shows a gothic Fortress HUD alongside Apple's own dialog.

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
│                                                              │
│  [ Let Spirit Pass ]              [ Lower Portcullis ]       │
└──────────────────────────────────────────────────────────────┘
```

You can now make an **informed** decision.

---

## The Castle Keep & The Wandering Spirits

Your macOS system is a **fortified castle courtyard**. Unprivileged child processes are mischievous, curious spirits trying to slip past the portcullis gates into protected vaults. Gatekeeper's Ward is the **night watch lantern** that spots these phantoms suspended mid-escape while macOS holds the gate shut.

The process lineage tree shows each spirit carrying a contextual tool (🔍 for `ripgrep`, 🗝️ for shell scripts). The menu bar ghost perks up with wide eyes and raises a lantern the instant a TCC event fires.

---

## Why It's Compelling for Kiroween

**Frankenstein angle** — stitching together technologies that have no right to work so well together:

| Layer | Technology |
|---|---|
| Zombie API | `sysctl KERN_PROCARGS2` — 20-year-old POSIX, resurrected |
| Modern declarative | SwiftUI Fortress HUD |
| System forensics | macOS Unified Log NDJSON streaming |
| Target domain | Cutting-edge autonomous AI coding agents |

This fits the *"stitch together a chimera of technologies"* prompt to the letter.

**The gothic Castle Keep aesthetic** supports the Frankenstein story rather than competing with it: obsidian background, Kiro Violet portcullis bars, Torchlight Amber lantern glow, Mischief Crimson for suspicious arguments. The theme explains the function.

---

## Differentiators

- **No kernel extension required** — pure userspace, ships as a notarised `.app`
- **No SIP bypass** — zero security compromise required to install or run
- **Open source** — developers can audit and trust it
- **Zero config** — install, launch, done
- **Real-time** — HUD appears the instant the permission dialog fires, not after
- **Process suspension insight** — `tccd` blocks the child process thread while waiting; the process is frozen in the table, so `sysctl` inspection is always reliable

---

## Hackathon Category & Prize Strategy

| Category | Rationale |
|---|---|
| **Frankenstein ($5,000)** | Our one category: POSIX + Unified Log + SwiftUI + AI agents |
| **Best Demo ($1,000)** | ≤3 min video: agent runs command → HUD reveals hidden script instantly |
| **Bonus Blog/Social** | Short Dev.to post + `#KiroweenHackathon26` tweet for bonus credits |

---

## Hackathon Compliance Checklist

- [x] Public GitHub repository with detectable Apache 2.0 `LICENSE` file
- [x] `.kiro/` directory with `specs/`, `hooks/`, and `steering/` populated
- [x] Spec-driven development documented (scores in *Technological Implementation 20%*)
- [x] Property-Based Testing (PBT) implemented on `KERN_PROCARGS2` parser and log parser
- [ ] Demo video ≤3 minutes on a real Mac device
- [ ] Devpost submission submitted before December 4, 2026 at 2:00 PM PT

---

## Demo Flow (≤3 Minutes)

| Timecode | Scene | Narrative |
|---|---|---|
| 0:00–0:35 | AI agent running + opaque TCC modal | *"Modern agents work fast but macOS blinds us. You're forced to guess."* |
| 0:35–1:15 | Same trigger — Fortress HUD slides in alongside Apple's dialog | *"Gatekeeper's Ward unmasks the intruder instantly."* |
| 1:15–2:00 | Code walkthrough: `sysctl KERN_PROCARGS2` + Unified Log | *"Zero dark magic. No kernel extensions. We resurrect 20-year-old POSIX APIs."* |
| 2:00–2:35 | Menu bar ghost, history dropdown, risk tags on suspicious args | *"Full lineage tree, process history, automatic risk tagging."* |
| 2:35–3:00 | Kiro spec-driven development + GitHub repo link | *"Built for Kiroween 2026. Know who knocks before you drop the castle gates."* |

---

## Future (post-hackathon)

- Allow/block rules engine (auto-deny patterns matching `.pem`, `curl | sh`, etc.)
- `brew install` distribution
- Integration with popular agent frameworks' audit logs
- Optional: companion app for remote monitoring
