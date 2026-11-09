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
    /// `kTCCServiceSystemPolicyDownloadsFolder` — user Downloads folder access.
    case downloadsFolder
    /// `kTCCServiceCalendar` — Calendar access.
    case calendar
    /// `kTCCServiceReminders` — Reminders access.
    case reminders
    /// `kTCCServicePhotos` — Photos library access.
    case photos
    /// `kTCCServiceCamera` — Camera access.
    case camera
    /// `kTCCServiceScreenCapture` — Screen and system audio recording.
    case screenCapture
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
        case "kTCCServiceSystemPolicyDownloadsFolder": self = .downloadsFolder
        case "kTCCServiceCalendar": self = .calendar
        case "kTCCServiceReminders": self = .reminders
        case "kTCCServicePhotos": self = .photos
        case "kTCCServiceCamera": self = .camera
        case "kTCCServiceScreenCapture": self = .screenCapture
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
        case .downloadsFolder: return "kTCCServiceSystemPolicyDownloadsFolder"
        case .calendar: return "kTCCServiceCalendar"
        case .reminders: return "kTCCServiceReminders"
        case .photos: return "kTCCServicePhotos"
        case .camera: return "kTCCServiceCamera"
        case .screenCapture: return "kTCCServiceScreenCapture"
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
    /// PID of the client process requesting access, when the message wording
    /// carries one. `nil` for partial (fallback) events.
    let clientPID: Int?
    /// The raw NDJSON event the extraction ran on.
    let logEvent: TCCLogEvent
}

/// Extracts a `TCCEvent` from one NDJSON log line.
///
/// The `clientPID` and `service` are matched from `eventMessage` wording,
/// which is version-sensitive, using layered patterns:
///
/// - **Pattern A** (modern wording): `… service kTCCServiceX for client <path> with PID n …`
/// - **Pattern B** (older wording): `… kTCCServiceX, client pid: n …`
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
