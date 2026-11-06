# Test Harness Design: WardTrigger

## 1. Objective

Provide a lightweight, unprivileged test harness that can deterministically trigger macOS TCC permission challenge dialogs on demand without disrupting the developer's everyday tools (such as IDEs, Terminals, or coding agents).

---

## 2. macOS TCC Attribution & Test Isolation

On macOS, TCC permission tracking associates requests with two identities:
- **`responsiblePID` / Responsible Bundle:** The top-level application owning the user session (e.g. `Cursor.app`, `com.apple.Terminal`).
- **`clientPID` / Client Binary:** The exact process or CLI binary invoking the syscall or API (e.g. `rg`, `find`, `cat`, or a python script).

### The Isolation Problem
If tests are executed directly inside the user's primary terminal:
1. If the terminal already has permission granted (e.g., Full Disk Access or Documents access), no prompt will appear.
2. If `tccutil reset` is run on the terminal, daily terminal workflows will be repeatedly interrupted by system permission prompts.

### The Solution: Dual-Mode Execution

#### Mode A: Standalone Bundle (`WardTrigger.app`)
- A minimal Cocoa/Swift app bundle with a dedicated bundle identifier (`com.gatekeepersward.ward-trigger`).
- Running `tccutil reset All com.gatekeepersward.ward-trigger` resets **only** this test bundle.
- Every invocation guaranteed to trigger the native macOS modal until explicitly answered.

#### Mode B: Agent Subprocess Simulation (CLI)
- A command-line mode that spawns simulated child subshells with custom arguments (e.g. `zsh -c "grep -r SECRET ~/Documents"`).
- Used to verify that `ProcessInspector` correctly extracts:
  - Parent agent PID and process name
  - Child binary path
  - Command-line arguments vector (`argv`)
  - Working directory (`cwd`)

---

## 3. Targeted TCC Capabilities

| Service Key | Target Resource | Trigger Mechanism |
|---|---|---|
| `kTCCServiceSystemPolicyDocumentsFolder` | `~/Documents` | Attempt directory listing or read on `~/Documents/.ward_canary` |
| `kTCCServiceSystemPolicyDesktopFolder` | `~/Desktop` | Attempt directory listing or read on `~/Desktop/.ward_canary` |
| `kTCCServiceAddressBook` | Contacts DB | Request access via `CNContactStore().requestAccess(for: .contacts)` |
| `kTCCServiceAppleEvents` | Automation | Execute OSA/AppleScript command targeting `Finder` or `System Events` |

---

## 4. Reset & Verification Automation

A companion shell helper (`scripts/reset_trigger.sh`) will automate resetting the test harness permissions:

```bash
#!/usr/bin/env bash
# Reset permissions for the test harness only
BUNDLE_ID="com.gatekeepersward.ward-trigger"

echo "Resetting TCC permissions for ${BUNDLE_ID}..."
tccutil reset All "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset SystemPolicyDocumentsFolder "${BUNDLE_ID}" 2>/dev/null || true
tccutil reset AddressBook "${BUNDLE_ID}" 2>/dev/null || true
echo "Ready for next test run."
```

---

## 5. Timing & Log Stream Interception Verification

When `WardTrigger` triggers a permission challenge:
1. The kernel / `tccd` halts the triggering thread.
2. `tccd` logs an event to the unified log stream (`com.apple.TCC`).
3. While the modal is displayed on screen, the target PID remains alive in the process table in a suspended state.
4. `Gatekeeper's Ward` reads the log line, queries `sysctl(KERN_PROCARGS2, clientPID)`, and displays the HUD before the user clicks Allow or Don't Allow.
