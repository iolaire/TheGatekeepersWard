Approach 2: The Parallel "Forensic HUD" (Zero-Entitlement Companion)
If you don't want to mess with kernel authorization, SIP toggling, or requesting restricted entitlements from Apple, you can build an assistive auditing tool that runs completely in user space.
Instead of intercepting the decision, this tool acts as an instant companion:
[ Apple displays native TCC modal: "Cursor wants access to Documents" ]
       │ (Simultaneously)
       ▼
[ Your Menu Bar App (listening to `os_log` or `fs_usage`) ]
       │
       ▼
[ Instant Flyout Card next to the native dialog ]
  ├── Responsible App: Cursor (PID 14201)
  ├── Actual Trigger Binary: /usr/local/bin/rg (ripgrep)
  ├── Full Executed Command: rg "API_KEY" /Users/.../Documents
  └── Target Path: ~/Documents/Work/secrets.env
How it works:
Log Stream Consumer: Your menu bar app spins up an OSLogStore stream in Swift, monitoring the subsystem com.apple.TCC for message patterns indicating Prompting user for [kTCCServiceSystemPolicyDocumentsFolder].
Process Correlator: The moment that event fires, your app grabs the requesting PID and responsible PID from the log payload.
Execution Extraction: It queries recent system process records (via sysctl process inspection or by reading the local audit pipeline) to grab the exact arguments and current working directory of that PID.
HUD Display: A small floating window appears right beside or above the native dialog showing the exact terminal command, the parent tree, and the target file path. You then make an informed choice on Apple's native Allow or Don't Allow button.
Feasibility & Constraints:
100% Feasible Today: Requires no special entitlements from Apple and runs without modifying SIP.
Non-Blocking: You cannot programmatically press the buttons on Apple's dialog (TCC dialogs run in a secure session that ignores synthetic Accessibility clicks to prevent clickjacking), but it gives you full visibility into what command caused the prompt before you manually click.