import Foundation

/// Static `tccd` log message fixtures for each wording pattern the extractor
/// handles, plus a generator for well-formed lines used by the property-based
/// tests.
enum TCCLogFixtures {
    /// Modern wording (macOS 14 Sonoma and later): Pattern A of the TCC event
    /// extractor — `service <key> for client <path> with PID <n>`.
    static let sonomaEventMessageFixture =
        "TCC accessed service kTCCServiceSystemPolicyDocumentsFolder for client /usr/local/bin/WardTrigger with PID 4711, auth: 0"

    /// Older wording (macOS 13 Ventura era): Pattern B of the TCC event
    /// extractor — `<key>, client pid: <n>`.
    static let venturaEventMessageFixture =
        "access request: kTCCServiceAddressBook, client pid: 8765, responsible: /Applications/Terminal.app"

    /// Real `AUTHREQ_PROMPTING` message captured from `log stream` on macOS
    /// 27.0.1 while WardTrigger's Documents prompt was on screen (only the
    /// home-directory username is anonymized). Pattern D of the extractor.
    static let macOS27PromptingEventMessageFixture =
        "AUTHREQ_PROMPTING: msgID=95165.55, service=kTCCServiceSystemPolicyDocumentsFolder, subject=Sub:{com.gatekeepersward.ward-trigger}Resp:{TCCDProcess: identifier=com.gatekeepersward.ward-trigger, pid=2215, auid=501, euid=501, binary_path=/Users/dev/TheGatekeepersWard/.build/WardTrigger.app/Contents/MacOS/WardTrigger},"

    /// Real `AUTHREQ_ATTRIBUTION` message from the same macOS 27.0.1 request.
    /// It carries two PIDs (the app and `sandboxd`) and no service key, so it
    /// must not yield a client PID.
    static let macOS27AttributionEventMessageFixture =
        "AUTHREQ_ATTRIBUTION: msgID=95165.55, attribution={accessing={TCCDProcess: identifier=com.gatekeepersward.ward-trigger, pid=2215, auid=501, euid=501, binary_path=/Users/dev/TheGatekeepersWard/.build/WardTrigger.app/Contents/MacOS/WardTrigger}, requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=95165, auid=0, euid=0, binary_path=/usr/libexec/sandboxd}, },"

    /// Real macOS 27.0.1 `AUTHREQ_ATTRIBUTION` message for a child process
    /// (WardTrigger, PID 8445) launched by a parent app (PID 8443). The
    /// child's PID appears only here, not on the prompting line.
    static let macOS27ChildAttributionEventMessageFixture =
        "AUTHREQ_ATTRIBUTION: msgID=95165.1572, attribution={responsible={TCCDProcess: identifier=com.gatekeepersward.test-parent, pid=8443, auid=501, euid=501, responsible_path=/private/tmp/wardparent/WardParent.app/Contents/MacOS/WardParent, binary_path=/private/tmp/wardparent/WardParent.app/Contents/MacOS/WardParent}, accessing={TCCDProcess: identifier=com.gatekeepersward.ward-trigger, pid=8445, auid=501, euid=501, binary_path=/Users/dev/TheGatekeepersWard/.build/out/Products/Debug/WardTrigger}, requesting={TCCDProcess: identifier=com.apple.sandboxd, pid=95165, auid=0, euid=0, binary_path=/usr/libexec/sandboxd}, },"

    /// Real macOS 27.0.1 `AUTHREQ_PROMPTING` message for the same child
    /// request. `Resp` names the parent app (8443), not the child.
    static let macOS27ChildPromptingEventMessageFixture =
        "AUTHREQ_PROMPTING: msgID=95165.1572, service=kTCCServiceSystemPolicyDocumentsFolder, subject=Sub:{com.gatekeepersward.test-parent}Resp:{TCCDProcess: identifier=com.gatekeepersward.test-parent, pid=8443, auid=501, euid=501, responsible_path=/private/tmp/wardparent/WardParent.app/Contents/MacOS/WardParent, binary_path=/private/tmp/wardparent/WardParent.app/Contents/MacOS/WardParent},"

    /// The full real sequence of `tccd` messages for request 95165.1572, in
    /// arrival order. The SUBJECT and RESULT lines share the `msgID`, so the
    /// correlator must not apply the attribution to them.
    static let macOS27ChildRequestSequence = [
        "AUTHREQ_CTX: msgID=95165.1572, function=TCCAccessRequest, service=kTCCServiceSystemPolicyDocumentsFolder, preflight=no, query=1, client_dict=(null), daemon_dict=<private>",
        macOS27ChildAttributionEventMessageFixture,
        "AUTHREQ_SUBJECT: msgID=95165.1572, subject=com.gatekeepersward.test-parent,",
        macOS27ChildPromptingEventMessageFixture,
        "AUTHREQ_RESULT: msgID=95165.1572, authValue=2, authReason=2, authVersion=1, desired_auth=0, error=(null),",
    ]

    /// Wraps a `tccd` message in a well-formed `com.apple.TCC` NDJSON line.
    ///
    /// - Parameter eventMessage: The message text.
    /// - Returns: A single-line JSON object string.
    static func tccLine(_ eventMessage: String) -> String {
        generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-08T09:44:08.000+0530",
            eventMessage: eventMessage
        )
    }

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
