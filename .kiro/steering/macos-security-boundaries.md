---
inclusion: auto
name: macos-security-boundaries
description: macOS security model constraints for Gatekeeper's Ward — TCC, SIP, entitlements, sandbox, and what the app may and may not do at runtime. Read before adding any new capability, permission, or system API call.
---

# macOS Security Boundaries

Gatekeeper's Ward is an **informational, zero-entitlement companion** tool.
It observes and displays; it never intercepts, modifies, or replaces macOS
security decisions. Every architectural choice must preserve this constraint.

---

## 1. The non-negotiable constraints

These are absolute limits — not tradeoffs to revisit under schedule pressure:

| Constraint | Rationale |
|---|---|
| No SIP bypass | App store distribution and open-source credibility require SIP-on operation |
| No kernel extensions (kext / DriverKit) | Requires Apple notarization + restricted entitlements; incompatible with the hackathon timeline |
| No restricted entitlements | `com.apple.private.*` entitlements require an Apple developer relationship and a provisioning profile that GitHub contributors would not have |
| No synthetic input to Apple's TCC dialog | TCC dialogs run in a secure input session; `AXUIElement` clicks are silently ignored by design — attempting this is both futile and a code smell |
| No TCC database writes | `~/Library/Application Support/com.apple.TCC/TCC.db` is protected by SIP; writing to it without entitlements is not possible and attempting it is a red flag for reviewers |

---

## 2. TCC — what we observe, not what we own

### What we read

The app reads TCC events **only** from the Unified Log stream:

```
/usr/bin/log stream --predicate 'subsystem == "com.apple.TCC"' --style ndjson
```

This requires no entitlements and no special permissions.

### What we never do

- Never query `TCC.db` directly (`sqlite3` on the protected database requires
  Full Disk Access and is not needed — the log stream gives us what we need).
- Never call `TCCAccessRequest` or any `TCC.framework` private API.
- Never read `/private/var/db/` paths (these are root-owned and SIP-protected).

### TCC service keys — display only

We display the `kTCCService*` key extracted from the log message verbatim
(e.g. `kTCCServiceSystemPolicyDocumentsFolder`). We map it to a human-readable
label for the HUD. We never make a judgment on behalf of the user about whether
the request should be allowed.

---

## 3. Process inspection boundaries

### Permitted

| API | Permitted scope |
|---|---|
| `sysctl(KERN_PROCARGS2, pid)` | Any process owned by the current user |
| `sysctl(KERN_PROC_PID, pid)` | Any process (returns basic info for other users, full info for same user) |
| `proc_pidinfo(PROC_PIDVNODEPATHINFO, pid)` | Same-user processes only; returns `EPERM` for other users — handle silently |
| `/proc/` (Linux path) | **Not applicable** — do not reference Linux `/proc` APIs |

### Not permitted

- `task_for_pid()` — requires `com.apple.security.cs.debugger` entitlement.
- Reading process memory via `vm_read()` — requires `task_for_pid`.
- Attaching a debugger (`ptrace PT_ATTACH`) — restricted by SIP for protected binaries.
- Killing, pausing, or sending signals to inspected processes — we are read-only observers.

### Cross-user processes

When a TCC event involves a process running as a different user (e.g. root),
`proc_pidinfo` returns `EPERM`. Degrade gracefully:

```swift
// ProcessSnapshot for cross-user or inaccessible processes
ProcessSnapshot(
    pid: pid,
    executablePath: details?.executablePath ?? "<restricted>",
    arguments: details?.arguments ?? [],
    workingDirectory: nil,
    inspectionDenied: true   // set "Spirit's origins are veiled" note in HUD
)
```

---

## 4. Entitlements we do use (and why they are safe)

The app's `.entitlements` file must contain only these:

```xml
<!-- Hardened Runtime — required for notarization -->
<key>com.apple.security.cs.allow-jit</key>       <!-- NOT included -->
<key>com.apple.security.cs.disable-library-validation</key>  <!-- NOT included -->

<!-- What we actually need -->
<key>com.apple.security.app-sandbox</key>
<false/>   <!-- sandboxing disabled — NSStatusItem + NSPanel require it -->
```

The app runs **without the App Sandbox** because `NSStatusItem` and a floating
`NSPanel` that appears over all windows require it. Document this in `Info.plist`
comments and in the README so reviewers understand it is intentional, not an
oversight.

Do not add any `com.apple.security.*` key without a written justification in
a `///` doc comment on the entitlement request site in code.

---

## 5. Unified Log access

The `log stream` subprocess approach requires no entitlements.
The predicate `subsystem == "com.apple.TCC"` is readable by any process in the
user session.

If Apple changes TCC log wording between macOS versions, the parser must not
crash. Maintain a regex fallback:

```swift
// Primary parse path: structured NDJSON fields
// Fallback: eventMessage regex
let patterns: [NSRegularExpression] = [
    // macOS 14+
    try! NSRegularExpression(pattern: #"requestor: TCCDProcess: identifier=(?<client>[^,]+), pid=(?<pid>\d+)"#),
    // macOS 13 / legacy
    try! NSRegularExpression(pattern: #"Prompting user for \[(?<service>[^\]]+)\].*?PID \[(?<pid>\d+)\]"#),
]
```

If no pattern matches, emit a `TCCEvent` with `service: .unknown` and log the
raw `eventMessage` at `.debug` level — never discard silently, never crash.

---

## 6. App Sandbox implications for WardTrigger

`WardTrigger` (the test harness, bundle ID `com.gatekeepersward.ward-trigger`)
**must not** share a bundle ID with the main app. If they share a bundle ID,
granting TCC to one grants it to the other, invalidating test resets.

`WardTrigger` must not be sandboxed (it needs to attempt access to protected
paths to trigger prompts). The main app is also not sandboxed (see §4 above).

---

## 7. Privacy — what we log and store

The HUD displays process arguments that may contain file paths, credentials,
or secrets (e.g. `rg "API_KEY" ~/Documents`). These are shown only in the
live HUD and the in-memory history list. The app must:

- Never write process arguments to disk.
- Never transmit process arguments over the network.
- Cap the in-memory history list to the last 50 events to bound memory use.
- Provide a "Clear History" menu bar action that wipes the in-memory list.

---

## 8. Notarization readiness (post-hackathon)

The app is built with Hardened Runtime enabled during the hackathon even though
formal notarization is not required for the submission. This ensures the binary
will notarize cleanly after the competition without architectural changes.

Hardened Runtime requirements:
- No JIT (`com.apple.security.cs.allow-jit` must be absent).
- No unsigned dylibs loaded at runtime.
- No `DYLD_INSERT_LIBRARIES` injection.
- `@executable_path` relative rpaths only.

---

## 9. SIP-protected paths — read access rules

SIP protects certain directories from modification by any process, including root.
Reading these paths is generally allowed but returning their content in the HUD
could expose sensitive system internals. Follow this table:

| Path pattern | Display in HUD? |
|---|---|
| `~/Documents`, `~/Desktop`, `~/Downloads` | ✅ Full path — this is the core value prop |
| `/System/Library/`, `/usr/` | ✅ Display binary path; do not enumerate directory contents |
| `/private/var/db/` | ❌ Show `<system-protected path>` — do not display |
| `~/Library/Application Support/` | ✅ Display path; mark "App Data" in HUD tag |
| SSH keys: `~/.ssh/`, `.pem`, `id_rsa`, `id_ed25519` | ✅ Display with 🔴 Mischief Crimson risk tag |
| `.env`, `.aws/credentials` | ✅ Display with 🔴 Mischief Crimson risk tag |
