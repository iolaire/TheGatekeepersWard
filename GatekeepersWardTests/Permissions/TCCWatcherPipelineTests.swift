import Foundation
import Testing
@testable import GatekeepersWard

/// Tests for the stream plumbing behind `TCCWatcher`: line splitting and
/// turning real macOS 27 log lines into prompt / result events.
struct TCCWatcherPipelineTests {
    @Test("Lines split across chunks, and several lines in one chunk, are rebuilt")
    func lineBufferReassembles() {
        var buffer = LineBuffer()
        #expect(buffer.append(Data("{\"a\":".utf8)).isEmpty)
        #expect(buffer.append(Data("1}\n{\"b\":2}\n\n{\"c\"".utf8)) == [#"{"a":1}"#, #"{"b":2}"#])
        #expect(buffer.append(Data(":3}\n".utf8)) == [#"{"c":3}"#])
    }

    @Test("A UTF-8 character split across chunks is not corrupted")
    func lineBufferKeepsUTF8Intact() {
        var buffer = LineBuffer()
        let bytes = Array("café\n".utf8)          // é is two bytes
        #expect(buffer.append(Data(bytes[..<4])).isEmpty)
        #expect(buffer.append(Data(bytes[4...])) == ["café"])
    }

    @Test("Random chunking of a stream yields the same lines as one chunk")
    func lineBufferChunkingProperty() {
        var rng = SeededRNG(seed: 0xC0FFEE)
        let lines = (0..<40).map { "line-\($0)-" + String(repeating: "x", count: $0 % 7) }
        let stream = Array((lines.joined(separator: "\n") + "\n").utf8)
        for _ in 0..<200 {
            var buffer = LineBuffer()
            var output: [String] = []
            var offset = 0
            while offset < stream.count {
                let length = Int.random(in: 1...16, using: &rng)
                let end = min(stream.count, offset + length)
                output += buffer.append(Data(stream[offset..<end]))
                offset = end
            }
            #expect(output == lines)
        }
    }

    @Test("The log stream's non-JSON header line is ignored")
    func headerLineIgnored() {
        var pipeline = TCCEventPipeline()
        #expect(pipeline.process(#"Filtering the log data using "subsystem == "com.apple.TCC"""#) == nil)
    }

    @Test("Real child-process request: one prompt with the child's PID, then the result")
    func realRequestProducesPromptThenResult() throws {
        var pipeline = TCCEventPipeline()
        let now = Date(timeIntervalSince1970: 0)
        let events = TCCLogFixtures.macOS27ChildRequestSequence.compactMap {
            pipeline.process(TCCLogFixtures.tccLine($0), now: now)
        }
        #expect(events == [
            .prompt(TCCPrompt(
                service: .documentsFolder, clientPID: 8445, responsiblePID: 8443,
                messageID: "95165.1572", detectedAt: now
            )),
            .resolved(TCCPromptResult(messageID: "95165.1572", isAllowed: true)),
        ])
    }

    @Test("A denied result (authValue=0) is reported as not allowed")
    func deniedResult() {
        var pipeline = TCCEventPipeline()
        let line = TCCLogFixtures.tccLine(
            "AUTHREQ_RESULT: msgID=95165.52, authValue=0, authReason=5, authVersion=1, desired_auth=0, error=(null),"
        )
        #expect(pipeline.process(line) == .resolved(TCCPromptResult(messageID: "95165.52", isAllowed: false)))
    }

    @Test("Older one-line wording with a PID is treated as a prompt")
    func legacyWordingIsPrompt() {
        var pipeline = TCCEventPipeline()
        let event = pipeline.process(TCCLogFixtures.tccLine(TCCLogFixtures.sonomaEventMessageFixture))
        guard case .prompt(let prompt) = event else {
            Issue.record("expected a prompt, got \(String(describing: event))")
            return
        }
        #expect(prompt.clientPID == 4711)
    }

    @Test("The log stream arguments use NDJSON and the TCC subsystem")
    func logArguments() {
        #expect(TCCWatcher.logArguments.contains("ndjson"))
        #expect(TCCWatcher.logArguments.contains(#"subsystem == "com.apple.TCC""#))
    }
}
