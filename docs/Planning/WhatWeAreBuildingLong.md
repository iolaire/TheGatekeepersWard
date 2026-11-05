The companion approach (Approach 2) is well-suited for an open-source GitHub project: it requires **no restricted Apple entitlements**, works with **System Integrity Protection (SIP) enabled**, compiles cleanly with the standard Swift package manager or Xcode, and solves an immediate pain point without risky kernel extensions.

The architecture, event pipeline, and Swift implementation for this companion app operate as follows.

---

### High-Level Architecture

The tool runs as a lightweight, unprivileged menu bar app (`MenuBarExtra` in SwiftUI).

```
   [ macOS / tccd ]
          │  Generates TCC prompt (modal on screen)
          ▼
   [ Unified Log Stream: com.apple.TCC ]
          │
          │  Read by background Task (OSLogStore / /usr/bin/log stream)
          ▼
   [ Event Extractor ]
          ├── Target Service (e.g., kTCCServiceSystemPolicyDocumentsFolder)
          ├── Requesting Client / PID (e.g., node, ripgrep, python)
          └── Responsible PID / Bundle ID (e.g., com.cursor.Cursor)
          │
          ▼
   [ Process & Argument Resolver ]
          │  sysctl(KERN_PROCARGS2, pid)
          ▼
   [ UI Presenter ]
          └── Drops a HUD notification card near the top-right / menu bar
              showing: Responsible App + Exact Executable + Command Line Arguments

```

---

### Step 1: The Real-Time TCC Stream Listener

While Apple provides `OSLogStore` in the `OSLog` framework, querying live real-time streams programmatically across subsystems in Swift can be tricky due to private buffer policies. The most reliable, non-blocking way to ingest real-time TCC events without root privileges is spawning a lightweight `/usr/bin/log stream` subprocess with an NDJSON or structured text output.

```swift
import Foundation

struct TCCPromptEvent {
    let timestamp: Date
    let service: String
    let clientPID: pid_t
    let responsiblePID: pid_t
    let clientPath: String
}

final class TCCLogMonitor {
    private var process: Process?
    private var pipe: Pipe?
    var onPromptDetected: ((TCCPromptEvent) -> Void)?

    func start() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        // Target tccd logs specifically for user prompts
        proc.arguments = [
            "stream",
            "--predicate", "sender == \"tccd\" and eventMessage CONTAINS \"Prompting user\"",
            "--style", "ndjson"
        ]

        let pipe = Pipe()
        proc.standardOutput = pipe
        self.process = proc
        self.pipe = pipe

        NotificationCenter.default.addObserver(
            forName: Pipe.fileHandleDataAvailableNotification,
            object: pipe.fileHandleForReading,
            queue: .global(qos: .userInitiated)
        ) { [weak self] _ in
            let data = pipe.fileHandleForReading.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            self?.parseLogLine(line)
            pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }

        pipe.fileHandleForReading.waitForDataInBackgroundAndNotify()

        do {
            try proc.run()
        } catch {
            print("Failed to start log monitor: \(error)")
        }
    }

    private func parseLogLine(_ ndjson: String) {
        // Sample tccd message:
        // "Prompting user for [kTCCServiceSystemPolicyDocumentsFolder] from client [/usr/local/bin/rg] with PID [14582] responsible PID [14201]"
        guard let message = extractMessageField(from: ndjson) else { return }
        
        let serviceRegex = try? NSRegularExpression(pattern: #"Prompting user for \[([a-zA-Z0-9]+)\]"#)
        let clientRegex = try? NSRegularExpression(pattern: #"client \[([^\]]+)\]"#)
        let pidRegex = try? NSRegularExpression(pattern: #"with PID \[(\d+)\]"#)
        let responsiblePidRegex = try? NSRegularExpression(pattern: #"responsible PID \[(\d+)\]"#)

        // Extract regex tokens and construct TCCPromptEvent
        if let s = match(serviceRegex, in: message),
           let client = match(clientRegex, in: message),
           let pidStr = match(pidRegex, in: message), let pid = pid_t(pidStr),
           let respPidStr = match(responsiblePidRegex, in: message), let respPid = pid_t(respPidStr) {
            
            let event = TCCPromptEvent(
                timestamp: Date(),
                service: s,
                clientPID: pid,
                responsiblePID: respPid,
                clientPath: client
            )
            DispatchQueue.main.async {
                self.onPromptDetected?(event)
            }
        }
    }

    private func match(_ regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex = regex,
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private func extractMessageField(from jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventMessage = json["eventMessage"] as? String else { return nil }
        return eventMessage
    }

    func stop() {
        process?.terminate()
    }
}

```

---

### Step 2: Resolving the Command Line Arguments (`sysctl`)

Once you obtain the child's `clientPID`, you need the exact CLI invocation. On macOS, `sysctl` with `KERN_PROCARGS2` retrieves the complete argument vector directly from kernel memory for any process running under your user account:

```swift
import Darwin

struct ProcessDetails {
    let pid: pid_t
    let executablePath: String
    let arguments: [String]
}

enum ProcessInspector {
    static func getProcessArguments(pid: pid_t) -> ProcessDetails? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size: Int = 0

        // 1. Get required buffer size
        if sysctl(&mib, 3, nil, &size, nil, 0) == -1 {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        // 2. Fetch the argument payload
        if sysctl(&mib, 3, &buffer, &size, nil, 0) == -1 {
            return nil
        }

        // KERN_PROCARGS2 layout:
        // [argc (4 bytes CInt)] [executable path \0] [\0 padding] [argv[0] \0] [argv[1] \0] ...
        var argc: CInt = 0
        memcpy(&argc, buffer, MemoryLayout<CInt>.size)

        var offset = MemoryLayout<CInt>.size
        let execPath = String(cString: buffer.advanced(by: offset))
        offset += execPath.utf8.count

        // Skip null bytes between executable path and argv
        while offset < size && buffer[offset] == 0 {
            offset += 1
        }

        var args: [String] = []
        var parsedArgsCount = 0

        while offset < size && parsedArgsCount < argc {
            let arg = String(cString: buffer.advanced(by: offset))
            args.append(arg)
            offset += arg.utf8.count + 1
            parsedArgsCount += 1
        }

        return ProcessDetails(pid: pid, executablePath: execPath, arguments: args)
    }
}

```

---

### Step 3: Presenting the HUD in SwiftUI

When `onPromptDetected` fires, populate an observable state that renders an unobtrusive, always-on-top floating HUD window near the native dialog.

```swift
import SwiftUI

struct AuditPopupView: View {
    let event: TCCPromptEvent
    let details: ProcessDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .foregroundColor(.orange)
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Permission Audit Triggered")
                        .font(.headline)
                    Text("Service: \(event.service)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Group {
                Text("Responsible App:").font(.caption).bold()
                Text("PID \(event.responsiblePID)")
                    .font(.system(.body, design: .monospaced))

                Text("Spawned Command:").font(.caption).bold()
                Text(details?.arguments.joined(separator: " ") ?? event.clientPath)
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

```

---

### Practical Scope and Limitations

* **Race Conditions on Fast Commands:** Quick commands like `cat ~/Documents/secret.txt` will trigger TCC and cause the kernel to pause the process thread waiting for the modal dialog. Because the thread is suspended, the process remains in the process table, allowing `sysctl` to read `KERN_PROCARGS2` reliably.
* **Open Source Readiness:** The codebase requires only standard Xcode/Swift tools with no external CocoaPods or C dependencies. Users can clone and build via:
```bash
git clone https://github.com/your-username/tcc-companion
cd tcc-companion
swift build -c release

```

* **Packaging as MenuBarExtra:** On macOS 13+, SwiftUI provides `MenuBarExtra("TCC Companion", systemImage: "eye.trianglebadge.exclamationmark")` out of the box, making it simple to package as an agent/menu bar utility (`LSUIElement = YES` in `Info.plist`) with a history table of past access triggers.