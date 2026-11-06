import Foundation

/// Static NDJSON fixtures matching the two known `tccd` log wording patterns,
/// plus a generator for well-formed lines used by the property-based tests.
enum TCCLogFixtures {
    /// Modern wording (macOS 14 Sonoma and later): Pattern A of the TCC event
    /// extractor — `service <key> for client <path> with PID <n>`.
    static let sonomaEventMessageFixture =
        "TCC accessed service kTCCServiceSystemPolicyDocumentsFolder for client /usr/local/bin/WardTrigger with PID 4711, auth: 0"

    /// Older wording (macOS 13 Ventura era): Pattern B of the TCC event
    /// extractor — `<key>, client pid: <n>`.
    static let venturaEventMessageFixture =
        "access request: kTCCServiceAddressBook, client pid: 8765, responsible: /Applications/Terminal.app"

    /// Builds a well-formed NDJSON line carrying at least the three required
    /// string fields (`subsystem`, `timestamp`, `eventMessage`) plus a few
    /// realistic extra fields the decoder must ignore.
    ///
    /// The line is produced by `JSONSerialization`, so it is valid JSON for
    /// any String/Int values — including strings with quotes, backslashes,
    /// newlines, and arbitrary Unicode.
    ///
    /// - Parameters:
    ///   - subsystem: Value for the `subsystem` field.
    ///   - timestamp: Value for the ISO 8601 `timestamp` field.
    ///   - eventMessage: Value for the `eventMessage` field.
    /// - Returns: A single-line JSON object string (no trailing newline).
    static func generateWellFormedNDJSON(
        subsystem: String,
        timestamp: String,
        eventMessage: String
    ) -> String {
        let object: [String: Any] = [
            "eventMessage": eventMessage,
            "messageType": 0,
            "processID": 4321,
            "subsystem": subsystem,
            "timestamp": timestamp,
            "category": "access",
            "traceID": 987_654_321,
        ]
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.sortedKeys]
            )
        else {
            // Unreachable for String/Int-only objects; keeps the helper
            // non-throwing for test ergonomics.
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }
}
