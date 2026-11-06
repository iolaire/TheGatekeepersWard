---
inclusion: auto
name: log-stream-parsing
description: Rules for launching the /usr/bin/log stream subprocess, parsing TCC NDJSON events, handling multi-version macOS log wording differences, and the structured-then-regex fallback pipeline. Read before touching TCCWatcher or TCCEvent.
---

# Log Stream Parsing Guidelines

`TCCWatcher` is the most version-sensitive component in the project. Apple has
changed `tccd` log wording across Ventura (13), Sonoma (14), and Sequoia (15)
without notice. These rules keep the parser resilient across all three.

---

## 1. Subprocess launch contract

Always launch `/usr/bin/log` as a child `Process`. Never use `OSLogStore` for
live streaming — its real-time buffer policies are unreliable for cross-process
subscriptions in a non-entitled menu bar app.

```swift
func makeLogProcess() -> Process {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
    proc.arguments = [
        "stream",
        "--predicate", #"subsystem == "com.apple.TCC""#,
        "--style", "ndjson",
        "--level", "info",      // "debug" is too noisy; "info" catches prompts
    ]
    proc.qualityOfService = .userInitiated
    return proc
}
```

Rules:
- Use `--style ndjson` — never `--style syslog` or `--style compact`. The NDJSON
  format provides stable field names independent of human-readable wording.
- Set `standardError` to `Pipe()` and drain it on a background thread; on some
  macOS versions `log` emits startup diagnostics to stderr that can stall the
  pipe buffer if not consumed.
- Set `terminationHandler` to restart the process after a 2-second delay if it
  exits unexpectedly (e.g., on a system sleep/wake cycle).
- Never call `proc.waitUntilExit()` on the main thread.

---

## 2. Async line reading

Read lines from `standardOutput` asynchronously using `FileHandle`'s
notification API. Do not use `readToEndOfFile()` — it blocks.

```swift
func startReading(pipe: Pipe, handler: @escaping (String) -> Void) {
    let handle = pipe.fileHandleForReading
    handle.readabilityHandler = { fh in
        let data = fh.availableData
        guard !data.isEmpty else { return }
        // Split on newlines — each NDJSON line is one log entry
        let text = String(data: data, encoding: .utf8) ?? ""
        text.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .forEach { handler($0) }
    }
}
```

Each callback invocation may contain multiple lines if the system batches output.
Always split on `\n` and process each line independently.

---

## 3. NDJSON primary parse path

Each line is a JSON object. The fields we need:

| JSON key | Type | Contents |
|---|---|---|
| `timestamp` | `String` | ISO 8601 date-time, e.g. `"2026-11-06T14:23:01.123456-0800"` |
| `eventMessage` | `String` | Human-readable log message (version-sensitive wording) |
| `processID` | `Int` | PID of `tccd` itself — **not** the requesting process |
| `subsystem` | `String` | Should be `"com.apple.TCC"` |
| `category` | `String` | Usually `"access"` for prompt events |

Parse with `JSONSerialization` — do not introduce a `Codable` struct for this
because the field set changes across macOS versions and missing fields must be
tolerated, not cause a decode failure:

```swift
func parseNDJSON(_ line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return json
}
```

If `JSONSerialization` fails (malformed line during startup or teardown), discard
silently. Never propagate a throw to the caller from an individual line parse.

---

## 4. eventMessage — multi-version regex patterns

The `eventMessage` field contains the process-identifying information. Its exact
wording has changed across macOS versions. Use the following patterns in priority
order; stop at the first match.

### Pattern A — macOS 14 Sonoma / 15 Sequoia (structured requestor format)

```
requestor: TCCDProcess: identifier=<bundleOrPath>, pid=<pid>, auid=<uid>,
binary_path=<path> is checking access for accessor TCCDProcess: identifier=..., ...
service=<service>
```

Regex (capture groups named):
```swift
let patternA = try! NSRegularExpression(pattern:
    #"requestor: TCCDProcess: identifier=(?P<client>[^,]+), pid=(?P<clientPID>\d+).*?service=(?P<service>[A-Za-z0-9]+)"#,
    options: [.dotMatchesLineSeparators]
)
```

Named capture groups are not supported in `NSRegularExpression` — use positional
groups and document the index:
```swift
// group 1: client identifier, group 2: clientPID, group 3: service
let patternA = try! NSRegularExpression(pattern:
    #"requestor: TCCDProcess: identifier=([^,]+), pid=(\d+).*?service=([A-Za-z0-9]+)"#,
    options: [.dotMatchesLineSeparators]
)
```

### Pattern B — macOS 13 Ventura (Prompting user format)

```
Prompting user for [<service>] from client [<path>] with PID [<pid>]
responsible PID [<responsiblePID>]
```

```swift
let patternB = try! NSRegularExpression(pattern:
    #"Prompting user for \[([A-Za-z0-9]+)\].*?with PID \[(\d+)\].*?responsible PID \[(\d+)\]"#,
    options: [.dotMatchesLineSeparators]
)
```

### Pattern C — category filter fallback

If neither A nor B matches but the event has `"category": "access"` and
`"subsystem": "com.apple.TCC"`, emit a `TCCEvent` with:
- `service: .unknown`
- `clientPID: nil`
- `responsiblePID: nil`
- `rawMessage: eventMessage`

Log the raw message at `.debug` level so it can be triaged during development.

### Applying patterns

```swift
func extractTCCEvent(from json: [String: Any]) -> TCCEvent? {
    guard let message = json["eventMessage"] as? String else { return nil }
    let range = NSRange(message.startIndex..., in: message)

    if let match = patternA.firstMatch(in: message, range: range) {
        // extract group 1, 2, 3
    } else if let match = patternB.firstMatch(in: message, range: range) {
        // extract group 1, 2, 3
    } else {
        // Pattern C fallback
    }
}
```

---

## 5. TCCEvent model

```swift
/// An immutable snapshot of a single TCC permission challenge detected from
/// the Unified Log stream.
struct TCCEvent: Sendable {
    let timestamp: Date
    let service: TCCService        // enum with .documents, .contacts, .camera… .unknown
    let clientPID: pid_t?          // nil when not parseable from log
    let responsiblePID: pid_t?     // nil when not parseable
    let clientPath: String?        // binary path extracted from log, if present
    let rawMessage: String         // always preserved for diagnostics
}
```

`TCCService` is an enum that maps `kTCCService*` strings to typed cases.
Unmapped strings become `.unknown(String)` — never silently drop novel services.

```swift
enum TCCService: Equatable, Sendable {
    case documents, desktop, downloads, fullDisk
    case contacts, calendar, reminders
    case camera, microphone
    case screenCapture, accessibility, appleEvents
    case unknown(String)

    init(rawKey: String) {
        switch rawKey {
        case "kTCCServiceSystemPolicyDocumentsFolder": self = .documents
        case "kTCCServiceSystemPolicyDesktopFolder":   self = .desktop
        case "kTCCServiceSystemPolicyDownloadsFolder": self = .downloads
        case "kTCCServiceSystemPolicyAllFiles":        self = .fullDisk
        case "kTCCServiceAddressBook",
             "kTCCServiceContactsFull":                self = .contacts
        case "kTCCServiceCalendar":                    self = .calendar
        case "kTCCServiceReminders":                   self = .reminders
        case "kTCCServiceCamera":                      self = .camera
        case "kTCCServiceMicrophone":                  self = .microphone
        case "kTCCServiceScreenCapture":               self = .screenCapture
        case "kTCCServiceAccessibility":               self = .accessibility
        case "kTCCServiceAppleEvents":                 self = .appleEvents
        default:                                       self = .unknown(rawKey)
        }
    }
}
```

---

## 6. Subprocess lifecycle management

`TCCWatcher` must be an `actor` (or guarded by a dedicated serial `DispatchQueue`)
because `startReading` callbacks arrive on a background thread.

```swift
actor TCCWatcher {
    private var process: Process?
    private var restartTask: Task<Void, Never>?

    func start() { ... }
    func stop() { process?.terminate(); restartTask?.cancel() }

    private func scheduleRestart() {
        restartTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            start()
        }
    }
}
```

On `stop()`:
1. Terminate the `Process`.
2. Set `fileHandleForReading.readabilityHandler = nil` to prevent callbacks
   after teardown.
3. Cancel any pending restart task.

On app quit, call `stop()` from `applicationWillTerminate`.

---

## 7. Privacy — never log PII from eventMessage

`eventMessage` can contain file paths, bundle identifiers, and user names.

- Log raw messages only at `.debug` level, which is off in production builds
  (`#if DEBUG` guard).
- Never write `eventMessage` to disk or include it in crash reports.
- In release builds, log only `TCCEvent.service` and `TCCEvent.timestamp` at
  `.info` level.

---

## 8. Testing the parser without a live macOS TCC event

Unit tests must not require a real `log stream` to run. Provide a static fixture
set of raw NDJSON strings covering:

- Pattern A (Sonoma/Sequoia) — well-formed
- Pattern B (Ventura) — well-formed
- Pattern A with multi-line `eventMessage`
- Missing `clientPID` in the message (Pattern C fallback)
- Malformed JSON (should return `nil` silently)
- Empty string (should return `nil` silently)
- `kTCCService` key not in the `TCCService` enum (should produce `.unknown`)

Store fixtures in `GatekeepersWardTests/Fixtures/TCCLogFixtures.swift` as
`static let` string constants so they can be referenced across multiple test files.
