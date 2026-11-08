import Testing
@testable import GatekeepersWard

/// Tests for joining macOS 27 `AUTHREQ_ATTRIBUTION` and `AUTHREQ_PROMPTING`
/// lines by `msgID`. All fixture messages are real captures from macOS 27.0.1.
struct TCCRequestCorrelatorTests {
    @Test("Child process: prompt gets the child's PID and the parent's responsible PID")
    func childProcessGetsChildPID() throws {
        var correlator = TCCRequestCorrelator()
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildAttributionEventMessageFixture
        ))
        let result = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildPromptingEventMessageFixture
        ))
        let event = try #require(result)
        #expect(event.service == .documentsFolder)
        #expect(event.clientPID == 8445)
        #expect(event.responsiblePID == 8443)
    }

    @Test("Real five-line request sequence: only the prompt gets the child's PID")
    func realRequestSequence() throws {
        var correlator = TCCRequestCorrelator()
        var prompts: [TCCEvent] = []
        for message in TCCLogFixtures.macOS27ChildRequestSequence {
            let result = correlator.ingest(TCCLogFixtures.tccLine(message))
            let event = try #require(result)
            if message.hasPrefix("AUTHREQ_PROMPTING:") {
                prompts.append(event)
            } else {
                #expect(event.clientPID == nil, "non-prompt line got a PID: \(message)")
            }
        }
        let prompt = try #require(prompts.first)
        #expect(prompts.count == 1)
        #expect(prompt.clientPID == 8445)
        #expect(prompt.responsiblePID == 8443)
    }

    @Test("Self-responsible process: client and responsible PID are the same process")
    func selfResponsibleProcess() throws {
        var correlator = TCCRequestCorrelator()
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27AttributionEventMessageFixture
        ))
        let result = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27PromptingEventMessageFixture
        ))
        let event = try #require(result)
        #expect(event.clientPID == 2215)
        #expect(event.responsiblePID == 2215)
    }

    @Test("An attribution with a different msgID is never applied")
    func mismatchedMessageIDIsIgnored() throws {
        var correlator = TCCRequestCorrelator()
        // Attribution for request 95165.1572, prompt for request 95165.55.
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildAttributionEventMessageFixture
        ))
        let result = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27PromptingEventMessageFixture
        ))
        let event = try #require(result)
        #expect(event.clientPID == nil)
        #expect(event.responsiblePID == 2215)
    }

    @Test("A prompt with no earlier attribution keeps clientPID nil")
    func promptWithoutAttribution() throws {
        var correlator = TCCRequestCorrelator()
        let result = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildPromptingEventMessageFixture
        ))
        let event = try #require(result)
        #expect(event.clientPID == nil)
        #expect(event.responsiblePID == 8443)
    }

    @Test("An attribution is used once, then forgotten")
    func attributionIsConsumed() throws {
        var correlator = TCCRequestCorrelator()
        let prompt = TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildPromptingEventMessageFixture
        )
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildAttributionEventMessageFixture
        ))
        let firstUsePID = correlator.ingest(prompt)?.clientPID
        #expect(firstUsePID == 8445)
        let secondUsePID = correlator.ingest(prompt)?.clientPID
        #expect(secondUsePID == nil)
    }

    @Test("Oldest attribution is evicted when capacity is exceeded")
    func capacityEvictsOldest() throws {
        var correlator = TCCRequestCorrelator(capacity: 1)
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildAttributionEventMessageFixture
        ))
        _ = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27AttributionEventMessageFixture
        ))
        // 95165.1572 was evicted by 95165.55; 95165.55 is still remembered.
        let evictedPID = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27ChildPromptingEventMessageFixture
        ))?.clientPID
        #expect(evictedPID == nil)
        let keptPID = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.macOS27PromptingEventMessageFixture
        ))?.clientPID
        #expect(keptPID == 2215)
    }

    @Test("Attribution parsing ignores the requesting daemon's PID")
    func attributionIgnoresRequestingDaemon() throws {
        let attribution = try #require(extractTCCAttribution(
            from: TCCLogFixtures.macOS27ChildAttributionEventMessageFixture
        ))
        #expect(attribution == TCCAttribution(
            messageID: "95165.1572",
            accessingPID: 8445,
            responsiblePID: 8443
        ))
        // The self-responsible line has no responsible block.
        let selfAttribution = try #require(extractTCCAttribution(
            from: TCCLogFixtures.macOS27AttributionEventMessageFixture
        ))
        #expect(selfAttribution.accessingPID == 2215)
        #expect(selfAttribution.responsiblePID == nil)
        // Non-attribution lines are rejected.
        #expect(extractTCCAttribution(
            from: TCCLogFixtures.macOS27PromptingEventMessageFixture
        ) == nil)
    }

    @Test("Older single-line wordings pass through unchanged")
    func olderWordingsPassThrough() throws {
        var correlator = TCCRequestCorrelator()
        let result = correlator.ingest(TCCLogFixtures.tccLine(
            TCCLogFixtures.sonomaEventMessageFixture
        ))
        let event = try #require(result)
        #expect(event.clientPID == 4711)
        #expect(event.responsiblePID == nil)
    }
}
