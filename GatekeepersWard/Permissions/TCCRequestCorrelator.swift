import Foundation

/// The process attribution `tccd` logs for one access request on macOS 27,
/// parsed from an `AUTHREQ_ATTRIBUTION` line.
///
/// Example (real capture, child process launched by a parent app):
///
/// ```
/// AUTHREQ_ATTRIBUTION: msgID=95165.1572, attribution={
///     responsible={TCCDProcess: identifier=…test-parent, pid=8443, …},
///     accessing={TCCDProcess: identifier=…ward-trigger, pid=8445, …},
///     requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=95165, …}, },
/// ```
///
/// When an `accessing` block is present, `requesting` is the system daemon
/// that forwarded the request (`sandboxd`) and is ignored. When it is absent
/// (the app asked `tccd` directly, e.g. for Contacts), `requesting` is the
/// client.
struct TCCAttribution: Equatable {
    /// The request identifier shared by every log line of one request.
    let messageID: String
    /// PID of the process that actually touched the protected resource.
    let accessingPID: Int
    /// PID of the responsible app. Absent when the accessing process is its
    /// own responsible app.
    let responsiblePID: Int?
}

/// Extracts the `msgID=<sender>.<counter>` request identifier from a `tccd`
/// log message.
///
/// - Parameter message: The `eventMessage` text of one log line.
/// - Returns: The identifier (e.g. `"95165.1572"`), or `nil` if absent.
func extractTCCMessageID(from message: String) -> String? {
    guard let match = message.firstMatch(of: #/\bmsgID=(\d+\.\d+)/#) else {
        return nil
    }
    return String(match.1)
}

/// Parses an `AUTHREQ_ATTRIBUTION` log message.
///
/// PIDs are read only from inside `TCCDProcess` blocks. `requesting={…}` is
/// used only when there is no `accessing={…}` block.
///
/// - Parameter message: The `eventMessage` text of one log line.
/// - Returns: The attribution, or `nil` when the line is not an attribution
///   line or carries no `msgID` or client PID.
func extractTCCAttribution(from message: String) -> TCCAttribution? {
    guard message.hasPrefix("AUTHREQ_ATTRIBUTION:"),
          let messageID = extractTCCMessageID(from: message)
    else { return nil }

    // With an `accessing` block, `requesting` is a forwarding daemon
    // (sandboxd, mds) and must be ignored. Without one (e.g. a Contacts or
    // Microphone request the app makes itself), `requesting` is the client.
    let accessing = message.firstMatch(of: #/accessing=\{TCCDProcess: [^}]*?\bpid=(\d+)/#)
        ?? message.firstMatch(of: #/requesting=\{TCCDProcess: [^}]*?\bpid=(\d+)/#)
    guard let accessing, let accessingPID = Int(accessing.1) else { return nil }

    let responsible = message.firstMatch(
        of: #/responsible=\{TCCDProcess: [^}]*?\bpid=(\d+)/#
    )
    return TCCAttribution(
        messageID: messageID,
        accessingPID: accessingPID,
        responsiblePID: responsible.flatMap { Int($0.1) }
    )
}

/// Joins the separate log lines `tccd` writes for one access request, so a
/// prompt event carries the PID of the process that actually asked.
///
/// On macOS 27 the `AUTHREQ_PROMPTING` line names only the responsible app
/// (e.g. Cursor). The accessing child (e.g. `rg`) appears only on the earlier
/// `AUTHREQ_ATTRIBUTION` line with the same `msgID`. Feed every log line to
/// `ingest(_:)` in arrival order; the correlator remembers attributions and
/// fills `clientPID` on the matching prompt event.
///
/// Memory is bounded: at most `capacity` unmatched attributions are kept, and
/// the oldest is dropped first. An attribution is forgotten once used.
struct TCCRequestCorrelator {
    /// Maximum number of unmatched attributions remembered at once.
    let capacity: Int
    private var attributions: [String: TCCAttribution] = [:]
    private var arrivalOrder: [String] = []

    /// Creates a correlator.
    ///
    /// - Parameter capacity: Maximum unmatched attributions to remember.
    ///   Values below 1 are treated as 1.
    init(capacity: Int = 256) {
        self.capacity = max(1, capacity)
    }

    /// Processes one NDJSON log line.
    ///
    /// - Parameter line: A single NDJSON line from `log stream`.
    /// - Returns: The same result as `extractTCCEvent(from:)`, except that an
    ///   `AUTHREQ_PROMPTING` event with no `clientPID` gets the accessing PID
    ///   (and, if missing, the responsible PID) from an earlier attribution
    ///   line with the same `msgID`. If no attribution was seen, `clientPID`
    ///   stays `nil`.
    mutating func ingest(_ line: String) -> TCCEvent? {
        guard let event = extractTCCEvent(from: line) else { return nil }
        let message = event.logEvent.eventMessage

        if let attribution = extractTCCAttribution(from: message) {
            remember(attribution)
            return event
        }

        // Only the prompt line takes the attribution. Other lines of the same
        // request (AUTHREQ_SUBJECT, AUTHREQ_RESULT) share the msgID and would
        // otherwise use it up before the prompt arrives.
        guard event.clientPID == nil,
              message.hasPrefix("AUTHREQ_PROMPTING:"),
              let messageID = extractTCCMessageID(from: message),
              let attribution = attributions.removeValue(forKey: messageID)
        else { return event }

        arrivalOrder.removeAll { $0 == messageID }
        return TCCEvent(
            service: event.service,
            clientPID: attribution.accessingPID,
            responsiblePID: event.responsiblePID ?? attribution.responsiblePID,
            logEvent: event.logEvent
        )
    }

    /// Stores an attribution, evicting the oldest when over capacity.
    private mutating func remember(_ attribution: TCCAttribution) {
        if attributions.updateValue(attribution, forKey: attribution.messageID) == nil {
            arrivalOrder.append(attribution.messageID)
        }
        while arrivalOrder.count > capacity {
            attributions.removeValue(forKey: arrivalOrder.removeFirst())
        }
    }
}
