import Foundation

/// A TCC service identifier extracted from a `tccd` unified log event.
enum TCCService: Equatable {
    /// `kTCCServiceSystemPolicyDocumentsFolder` — user Documents folder access.
    case documentsFolder
    /// `kTCCServiceSystemPolicyDesktopFolder` — user Desktop folder access.
    case desktopFolder
    /// `kTCCServiceAddressBook` — Contacts access.
    case addressBook
    /// `kTCCServiceAppleEvents` — Apple Events (inter-app automation) access.
    case appleEvents
    /// `kTCCServiceMicrophone` — Microphone access.
    case microphone
    /// Any other service key; the raw key is preserved, never dropped.
    case unknown(String)

    /// Maps a raw `kTCCService*` key from a `tccd` log event to a case.
    ///
    /// Unrecognized keys map to `.unknown(rawKey)` so that new services
    /// introduced by future macOS versions are surfaced to `TCCWatcher`
    /// instead of being silently discarded.
    ///
    /// - Parameter rawKey: The raw `kTCCService*` identifier string.
    init(rawKey: String) {
        switch rawKey {
        case "kTCCServiceSystemPolicyDocumentsFolder": self = .documentsFolder
        case "kTCCServiceSystemPolicyDesktopFolder": self = .desktopFolder
        case "kTCCServiceAddressBook": self = .addressBook
        case "kTCCServiceAppleEvents": self = .appleEvents
        case "kTCCServiceMicrophone": self = .microphone
        default: self = .unknown(rawKey)
        }
    }

    /// The raw `kTCCService*` identifier string for this service.
    var rawKey: String {
        switch self {
        case .documentsFolder: return "kTCCServiceSystemPolicyDocumentsFolder"
        case .desktopFolder: return "kTCCServiceSystemPolicyDesktopFolder"
        case .addressBook: return "kTCCServiceAddressBook"
        case .appleEvents: return "kTCCServiceAppleEvents"
        case .microphone: return "kTCCServiceMicrophone"
        case .unknown(let key): return key
        }
    }
}

/// A single NDJSON log event as emitted by `/usr/bin/log stream --style ndjson`.
///
/// Only the fields `TCCWatcher` consumes are decoded; every other key in the
/// source JSON object is ignored by the decoder.
struct TCCLogEvent: Codable, Equatable {
    /// ISO 8601 timestamp of the log line.
    var timestamp: String
    /// Log subsystem — `com.apple.TCC` for TCC events.
    var subsystem: String
    /// Log category — usually `access` for prompts.
    var category: String?
    /// Free-form message text containing the client PID and service key.
    var eventMessage: String
    /// PID of `tccd` itself (not the requesting process).
    var processID: Int?
}

extension TCCLogEvent {
    /// Decodes one NDJSON line into a `TCCLogEvent`.
    ///
    /// - Parameter line: A single JSON object line from `log stream`.
    /// - Returns: The decoded event, or `nil` when the line is not valid JSON,
    ///   is not a JSON object, or is missing required fields.
    static func decode(from line: String) -> TCCLogEvent? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TCCLogEvent.self, from: data)
    }

    /// Serializes the event back to a single-line JSON string, suitable for
    /// re-parsing with `decode(from:)` (round-trip contract).
    ///
    /// - Returns: The JSON representation, or an empty string if encoding
    ///   fails (which cannot happen for String/Int-only fields in practice).
    func encodedJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// The TCC-relevant data extracted from one NDJSON log line.
struct TCCEvent: Equatable {
    /// The protected service the event refers to.
    let service: TCCService
    /// PID of the process that actually requested access (e.g. `rg` run by an
    /// agent), when known. `nil` for partial (fallback) events, and for macOS
    /// 27 prompt lines until `TCCRequestCorrelator` fills it in.
    let clientPID: Int?
    /// PID of the app macOS holds responsible for the request (e.g. Cursor),
    /// when the message wording carries one.
    let responsiblePID: Int?
    /// The raw NDJSON event the extraction ran on.
    let logEvent: TCCLogEvent

    /// Creates an event. `responsiblePID` defaults to `nil` because only some
    /// log wordings carry it.
    init(
        service: TCCService,
        clientPID: Int?,
        responsiblePID: Int? = nil,
        logEvent: TCCLogEvent
    ) {
        self.service = service
        self.clientPID = clientPID
        self.responsiblePID = responsiblePID
        self.logEvent = logEvent
    }
}

/// Extracts a `TCCEvent` from one NDJSON log line.
///
/// The `clientPID` and `service` are matched from `eventMessage` wording,
/// which is version-sensitive, using layered patterns:
///
/// - **Pattern A** (modern wording): `… service kTCCServiceX for client <path> with PID n …`
/// - **Pattern B** (older wording): `… kTCCServiceX, client pid: n …`
/// - **Pattern D** (macOS 27, captured from a real prompt):
///   `AUTHREQ_PROMPTING: … service=kTCCServiceX, … Resp:{TCCDProcess: … pid=n, …}`.
///   `n` is the *responsible* app's PID; `clientPID` is left `nil` here and
///   filled in by `TCCRequestCorrelator` from the matching attribution line.
/// - **Pattern C** (fallback): any `kTCCService*` token, no PID — the line is
///   surfaced as a partial event rather than dropped.
///
/// - Parameter line: A single NDJSON line from `log stream`.
/// - Returns: A `TCCEvent`, or `nil` when the line is not a decodable log
///   event (invalid JSON or missing required fields).
func extractTCCEvent(from line: String) -> TCCEvent? {
    guard let event = TCCLogEvent.decode(from: line) else { return nil }
    let message = event.eventMessage

    // Pattern A: "… service kTCCServiceX for client <path> with PID n …"
    if let match = message.firstMatch(
        of: #/service (kTCCService[A-Za-z]+) for client \S+ with PID (\d+)/#
    ) {
        return TCCEvent(
            service: TCCService(rawKey: String(match.1)),
            clientPID: Int(match.2),
            logEvent: event
        )
    }

    // Pattern B: "… kTCCServiceX, client pid: n …"
    if let match = message.firstMatch(
        of: #/(kTCCService[A-Za-z]+), client pid: (\d+)/#
    ) {
        return TCCEvent(
            service: TCCService(rawKey: String(match.1)),
            clientPID: Int(match.2),
            logEvent: event
        )
    }

    // Pattern D: macOS 27 "AUTHREQ_PROMPTING: … service=kTCCServiceX, …
    // Resp:{TCCDProcess: identifier=…, pid=n, …}". Resp is the responsible
    // app: a real capture of a child process prompting showed the parent's
    // PID here, not the child's. The child's PID appears only on the
    // AUTHREQ_ATTRIBUTION line with the same msgID, so clientPID stays nil and
    // `TCCRequestCorrelator` fills it in.
    if let match = message.firstMatch(
        of: #/service=(kTCCService[A-Za-z]+),.*?Resp:\{TCCDProcess: [^}]*?\bpid=(\d+)/#
    ) {
        return TCCEvent(
            service: TCCService(rawKey: String(match.1)),
            clientPID: nil,
            responsiblePID: Int(match.2),
            logEvent: event
        )
    }

    // Pattern C (fallback): keep the line as a partial event with whatever
    // service token is present, so version-specific wording changes degrade
    // instead of silently dropping events.
    if let token = message.firstMatch(of: #/kTCCService[A-Za-z]+/#) {
        return TCCEvent(
            service: TCCService(rawKey: String(token.0)),
            clientPID: nil,
            logEvent: event
        )
    }

    return TCCEvent(service: .unknown(message), clientPID: nil, logEvent: event)
}
