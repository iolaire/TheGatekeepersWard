import Foundation
import Testing
@testable import GatekeepersWard
@testable import WardTrigger

/// PBT + unit coverage for the NDJSON log-stream event parser used by
/// `TCCWatcher` (Requirements 11.1–11.5).
struct TCCEventParserTests {
    /// Iteration count for the property loops: 200 in CI, 1000 locally.
    private static var propertyIterations: Int {
        ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    }

    /// Generates a random printable-ASCII string with the seeded RNG.
    private func randomString<R: RandomNumberGenerator>(
        rng: inout R
    ) -> String {
        generatePrintableASCIIArgv(count: 1, rng: &rng)[0]
    }

    // Feature: ward-trigger, Property 3: NDJSON parser round-trip
    @Test("Property 3: decode → encode → decode preserves the three required fields")
    func ndjsonRoundTrip() {
        var rng = SeededRNG(seed: 0x3A7F_AC02)
        for _ in 0..<Self.propertyIterations {
            let line = TCCLogFixtures.generateWellFormedNDJSON(
                subsystem: randomString(rng: &rng),
                timestamp: randomString(rng: &rng),
                eventMessage: randomString(rng: &rng)
            )
            guard let event = TCCLogEvent.decode(from: line) else {
                Issue.record("Failed to decode a well-formed NDJSON line: \(line)")
                continue
            }
            let redecoded = TCCLogEvent.decode(from: event.encodedJSON())
            #expect(redecoded?.subsystem == event.subsystem)
            #expect(redecoded?.timestamp == event.timestamp)
            #expect(redecoded?.eventMessage == event.eventMessage)
        }
    }

    // Feature: ward-trigger, Property 4: NDJSON parser never crashes
    @Test("Property 4: extractor returns nil or a valid event for arbitrary input, never traps")
    func noCrashOnArbitraryStrings() {
        var rng = SeededRNG(seed: 0x0DD_BA11)
        for _ in 0..<Self.propertyIterations {
            // Arbitrary bytes decoded lossily: valid JSON, invalid JSON,
            // empty strings, and binary-safe arbitrary Unicode all occur.
            let length = Int.random(in: 0...128, using: &rng)
            let bytes = (0..<length).map { _ in UInt8.random(in: 0...255, using: &rng) }
            let input = String(decoding: bytes, as: UTF8.self)
            if let event = extractTCCEvent(from: input) {
                // Any extracted event must come from a decodable log line.
                #expect(TCCLogEvent.decode(from: input) != nil)
                _ = event
            }
        }
    }

    @Test("Pattern A extracts service and client PID from the Sonoma wording")
    func patternAExtractionFromSonoma() throws {
        let line = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-06T12:00:00.000Z",
            eventMessage: TCCLogFixtures.sonomaEventMessageFixture
        )
        let event = try #require(extractTCCEvent(from: line))
        #expect(event.service == .documentsFolder)
        #expect(event.clientPID == 4711)
    }

    @Test("Pattern B extracts service and client PID from the Ventura wording")
    func patternBExtractionFromVentura() throws {
        let line = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-06T12:00:00.000Z",
            eventMessage: TCCLogFixtures.venturaEventMessageFixture
        )
        let event = try #require(extractTCCEvent(from: line))
        #expect(event.service == .addressBook)
        #expect(event.clientPID == 8765)
    }

    @Test("Pattern D extracts service and responsible PID from the real macOS 27 AUTHREQ_PROMPTING line")
    func patternDExtractionFromMacOS27Prompting() throws {
        let line = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-07T22:27:58.000+0530",
            eventMessage: TCCLogFixtures.macOS27PromptingEventMessageFixture
        )
        let event = try #require(extractTCCEvent(from: line))
        #expect(event.service == .documentsFolder)
        #expect(event.responsiblePID == 2215)
        // The prompting line alone cannot name the accessing process; that
        // comes from TCCRequestCorrelator.
        #expect(event.clientPID == nil)
    }

    @Test("macOS 27 AUTHREQ_ATTRIBUTION line yields no client PID")
    func macOS27AttributionLineHasNoClientPID() throws {
        // This line names two processes (the app and sandboxd) and no service,
        // so picking either PID would be a guess.
        let line = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-07T22:27:58.000+0530",
            eventMessage: TCCLogFixtures.macOS27AttributionEventMessageFixture
        )
        let event = try #require(extractTCCEvent(from: line))
        #expect(event.clientPID == nil)
    }

    @Test("Pattern C fallback keeps unknown wordings as a partial event")
    func patternCFallbackOnUnknownMessage() throws {
        let line = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-06T12:00:00.000Z",
            eventMessage: "Sandbox extension issued for kTCCServiceCamera evaluation"
        )
        let event = try #require(extractTCCEvent(from: line))
        #expect(event.service.rawKey == "kTCCServiceCamera")
        #expect(event.clientPID == nil)

        // Even a message with no service token at all must not be dropped.
        let opaqueLine = TCCLogFixtures.generateWellFormedNDJSON(
            subsystem: "com.apple.TCC",
            timestamp: "2026-11-06T12:00:00.000Z",
            eventMessage: "totally unfamiliar future macOS wording"
        )
        #expect(extractTCCEvent(from: opaqueLine) != nil)
    }

    @Test("Malformed JSON lines return nil instead of crashing")
    func malformedJSONReturnsNil() {
        #expect(extractTCCEvent(from: "") == nil)
        #expect(extractTCCEvent(from: "not json {") == nil)
        #expect(extractTCCEvent(from: "42") == nil)
        #expect(extractTCCEvent(from: "[1, 2, 3]") == nil)
        #expect(extractTCCEvent(from: "{}") == nil)
        #expect(extractTCCEvent(from: #"{"eventMessage": 42}"#) == nil)
    }

    @Test("All known TCC service keys map to a case; unknown keys are preserved")
    func allTCCServiceCasesMapped() {
        #expect(TCCService(rawKey: "kTCCServiceSystemPolicyDocumentsFolder") == .documentsFolder)
        #expect(TCCService(rawKey: "kTCCServiceSystemPolicyDesktopFolder") == .desktopFolder)
        #expect(TCCService(rawKey: "kTCCServiceAddressBook") == .addressBook)
        #expect(TCCService(rawKey: "kTCCServiceAppleEvents") == .appleEvents)
        #expect(TCCService(rawKey: "kTCCServiceMicrophone") == .microphone)
        #expect(TCCService(rawKey: "kTCCServiceSystemPolicyDownloadsFolder") == .downloadsFolder)
        #expect(TCCService(rawKey: "kTCCServiceCalendar") == .calendar)
        #expect(TCCService(rawKey: "kTCCServiceReminders") == .reminders)
        #expect(TCCService(rawKey: "kTCCServicePhotos") == .photos)
        #expect(TCCService(rawKey: "kTCCServiceCamera") == .camera)
        #expect(TCCService(rawKey: "kTCCServiceScreenCapture") == .screenCapture)
        // Unknown keys are never silently dropped — they round-trip as .unknown.
        #expect(TCCService(rawKey: "kTCCServiceSensorKitMotion") == .unknown("kTCCServiceSensorKitMotion"))
        #expect(TCCService(rawKey: "kTCCServiceSomethingNew") == .unknown("kTCCServiceSomethingNew"))
        #expect(TCCService(rawKey: "kTCCServiceSensorKitMotion").rawKey == "kTCCServiceSensorKitMotion")
        // Every WardTrigger catalog key must map to a named case, not .unknown.
        for spec in wardTriggerCatalog {
            if case .unknown = TCCService(rawKey: spec.serviceKey) {
                Issue.record("\(spec.serviceKey) has no TCCService case")
            }
        }
    }
}
