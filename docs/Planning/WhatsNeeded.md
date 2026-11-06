Needs
1. simple app that AI can interact with to tigger access requests (Protected TCC Services) (maybe AppleScript/OSA events call app)
2. The background framework to identify Protected TCC Services calls
3. The unprivileged menu bar a lightweight, unprivileged menu bar app (`MenuBarExtra` in SwiftUI)
4. Graphics - app icon, menu bar icon, styleing on flyout
5. Documentation
6. Video
x. Future i18n trasnlations only after fully functional MVP




### 1. Test Harness & TCC Trigger Strategy (`WhatsNeeded.md` Item #1)

During development and when recording the 3-minute video demo, we need a reliable way to summon Apple’s native permission dialog on demand.

* **The Challenge:** Once you click "Allow" or "Don't Allow" on macOS, the system saves the decision in `TCC.db`, and future calls will silently pass or fail without showing the modal again.
* **The Solution:** 
  1. **Resetting Permissions via `tccutil`:**
     ```bash
     tccutil reset SystemPolicyDocumentsFolder
     tccutil reset AddressBook
     ```
  2. **Candidate Trigger Methods:**
     * **File Access (Documents/Desktop):** A tiny CLI binary or Python/zsh script attempting to read `~/Documents` directly. When run as a standalone unnotarized binary or child process, macOS prompts immediately if unpermitted.
     * **OSA / AppleScript Automation (`kTCCServiceAppleEvents`):**
       ```bash
       osascript -e 'tell application "Finder" to get name of every window'
       ```
       This triggers the *"Terminal would like to control Finder"* prompt, which is a classic vector when agents try to automate GUI apps.
     * **Contacts API (`kTCCServiceAddressBook`):** Calling `CNContactStore().requestAccess(...)` will immediately spawn the native permission request modal.

---

### 2. Gothic Fortress HUD Design & Aesthetic (`WhatsNeeded.md` Item #4)

For the **Frankenstein** and **Costume Contest** judging categories, the visual presentation must feel deliberate, polished, and thematic rather than like a standard macOS alert:

* **Atmosphere & Palette:**
  * **Background:** Deep obsidian slate (`#0E1013` to `#181A20`) with subtle frosted glass material (`.ultraThinMaterial`).
  * **Border / Accents:** Wrought-iron border (`#2D3139`) with an antique brass/torchlight amber accent (`#D4A373`).
  * **Alert / Danger Accent:** Gargoyle blood crimson (`#E63946`) activated when suspicious flags or keywords (`--secret`, `.pem`, `id_rsa`, `curl`, `nc`) are spotted in the argument vector.
* **HUD Structure:**
  ```
  ┌──────────────────────────────────────────────────────────────┐
  │ 💀 GATEKEEPER'S WARD                    [kTCCService...Docs] │
  ├──────────────────────────────────────────────────────────────┤
  │ Master App: Cursor (PID 14201)                               │
  │ Lineage:    cursor ➔ node ➔ zsh ➔ ripgrep (PID 14582)        │
  ├──────────────────────────────────────────────────────────────┤
  │ EXECUTED COMMAND                                             │
  │ $ rg "AWS_SECRET" /Users/dev/Documents                       │
  ├──────────────────────────────────────────────────────────────┤
  │ ⚠️ Target: ~/Documents/Work/production.env                    │
  │ Status: Process suspended pending your decision on modal    │
  └──────────────────────────────────────────────────────────────┘
  ```

---

### 3. Demo Video Storyboard ($\le 3$ Minutes)

Judges evaluate **Presentation (20%)** based on clarity, impact, and whether the project works end-to-end on a real device.

| Timecode | Visual | Voiceover / Narrative |
|---|---|---|
| **0:00 – 0:35** | Split screen: Terminal with an AI agent (Cursor/Kiro) running + Apple's opaque modal: *"App wants access to Documents"*. | *"Modern AI coding agents work fast, but macOS blinds us. When an agent triggers a TCC modal, do you know what command it ran? You're forced to guess."* |
| **0:35 – 1:15** | Trigger occurs again, but now Gatekeeper’s Ward Fortress HUD slides in alongside Apple’s dialog in real-time. | *"Gatekeeper's Ward unmasks the intruder. The instant macOS prompts, our gothic HUD reveals the master agent, child PID, and the exact command line arguments."* |
| **1:15 – 2:00** | Architecture slide / Code walkthrough showing `sysctl KERN_PROCARGS2` and Unified Log streaming. | *"Zero dark magic. No kernel extensions, no SIP disabling, no security bypass. We resurrect 20-year-old POSIX APIs to inspect suspended processes while macOS waits for the user."* |
| **2:00 – 2:35** | Menu bar status dropdown + History viewer + Edge cases. | *"Shows history log of past challenges, process lineage tree, and suspicious parameter flags."* |
| **2:35 – 3:00** | Kiro usage wrap-up (spec-driven development, hooks, PBT) & GitHub repository link. | *"Built for Kiroween 2026. Know who knocks before you drop the castle gates."* |

---




**100% agreed.** Having the test/trigger app as your very first step is not just good practice—it is essential for several critical reasons:

### 1. Ground Truth for the Log Format
Apple does not officially document `tccd` log formatting, and the wording changes between macOS versions (Ventura, Sonoma, Sequoia, etc.). 
* Before writing log regexes or buffer parsers, you need to see the **exact real-world log output** that macOS produces on your machine when a prompt occurs.
* A trigger app gives you instant ground truth within seconds.

### 2. Protects Your Daily Dev Environment
If you test by triggering prompts through your actual IDE (Cursor, VS Code, Terminal), you will eventually have to reset permissions using:
```bash
tccutil reset SystemPolicyDocumentsFolder
```
Doing this wipes permissions for **all** your apps or your primary tools, disrupting your daily workflow. With a dedicated test app (or a dedicated bundle ID), you can reset permissions repeatedly without breaking your main editor.

### 3. Millisecond Feedback Loop
Building the log watcher (`TCCWatcher`) and process inspector (`ProcessInspector`) requires tight iteration:
* **Without a test app:** You have to prompt an AI agent, wait for it to generate code, wait for it to run a command, and hope it trips a permission boundary.
* **With a test app:** You run a one-line command (`./trigger docs` or `./trigger contacts`), and you immediately verify whether your HUD caught the event and resolved the PID.

### 4. Repeatable Staging for the Demo Video
When you record your $\le 3$-minute hackathon video, you need crisp, repeatable timing. A test app lets you pass realistic, provocative command-line arguments (like `rg "AWS_SECRET_KEY" ~/Documents/prod.env`) so the demo looks authentic and compelling on the first take.

---

### What the Test App Should Cover (Minimal Scope)

To keep it lightweight and aligned with YAGNI:
1. **Target 1: Filesystem Access** (e.g., trying to read `~/Documents` or `~/Desktop`).
2. **Target 2: Automation / AppleEvents** (e.g., an AppleScript calling `System Events` or `Finder`).
3. **Target 3: Personal Data** (e.g., querying `CNContactStore` for Contacts).
4. **Reset Helper:** A companion one-liner script that runs `tccutil reset` so you can trigger prompts repeatedly on demand.

It is definitely the right foundation to start with before building the companion HUD.

