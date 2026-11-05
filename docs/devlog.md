# Dev Log

Running notes from the build. Newest entries at the top.

---

## 2026-11-05 — Day 1: Project Setup

**iolaire & Dharshaneshwaran**

- Defined project structure and scaffolded repo
- Wrote pitch, architecture overview, and contributing guide
- Set up git with `.gitignore` tuned for Swift/Xcode
- Kiro steering file in place for project context

**Next up:**
- Create Xcode project (macOS app, menu bar, no storyboard)
- Stub out `ProcessInspector` with a basic `sysctl KERN_PROCARGS2` wrapper
- Stub out `TCCWatcher` with `log stream` subprocess harness
- Get something building and printing to console before touching UI

**Questions to resolve:**
- Which macOS version minimum to target? (Ventura 13 vs Sonoma 14)
- SwiftUI or AppKit for the HUD? (Leaning SwiftUI inside an NSPanel)
- How to handle the case where the child PID we get from the log event has already exited by the time we inspect it?

---

<!-- Add new entries above this line -->
