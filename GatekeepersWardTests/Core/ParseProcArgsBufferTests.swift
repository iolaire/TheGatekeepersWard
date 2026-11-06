import Foundation
import Testing
@testable import GatekeepersWard

/// PBT + unit coverage for the `KERN_PROCARGS2` buffer parser used by
/// `ProcessInspector` (Requirements 10.1–10.5).
struct ParseProcArgsBufferTests {
    /// Iteration count for the property loops: 200 in CI, 1000 locally.
    private static var propertyIterations: Int {
        ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    }

    // Feature: ward-trigger, Property 1: KERN_PROCARGS2 round-trip
    @Test("Property 1: encoding then parsing reproduces the original argv")
    func kernProcArgs2RoundTrip() {
        var rng = SeededRNG(seed: 0xC0FF_EE01)
        for _ in 0..<Self.propertyIterations {
            let count = Int.random(in: 1...8, using: &rng)
            let argv = generatePrintableASCIIArgv(count: count, rng: &rng)
            let buffer = encodeProcArgsBuffer(argv: argv)
            let parsed = parseProcArgsBuffer(buffer)
            #expect(parsed?.arguments == argv)
            #expect(parsed?.executablePath == "/usr/local/bin/ward-trigger")
        }
    }

    // Feature: ward-trigger, Property 2: KERN_PROCARGS2 parser never crashes
    @Test("Property 2: parser returns nil or a valid result for arbitrary bytes, never traps")
    func noCrashOnArbitraryBytes() {
        var rng = SeededRNG(seed: 0xBAD_C0DE)
        for _ in 0..<Self.propertyIterations {
            let length = Int.random(in: 0...256, using: &rng)
            let buffer = (0..<length).map { _ in UInt8.random(in: 0...255, using: &rng) }
            let parsed = parseProcArgsBuffer(buffer)
            if let parsed {
                // Any non-nil result must be structurally valid.
                #expect(!parsed.executablePath.isEmpty)
                #expect(parsed.arguments.count >= 0)
            }
        }
    }

    @Test("Buffers shorter than the 4-byte argc header return nil")
    func tooShortBufferReturnsNil() {
        for length in 0..<4 {
            let buffer = (0..<length).map { _ in UInt8.random(in: 0...255) }
            #expect(parseProcArgsBuffer(buffer) == nil, "length \(length) must be rejected")
        }
    }

    @Test("An all-zero buffer returns nil")
    func allZeroBufferReturnsNil() {
        let buffer = [UInt8](repeating: 0, count: 64)
        #expect(parseProcArgsBuffer(buffer) == nil)
    }

    @Test("argc = 0 with a valid executable path yields an empty argv")
    func argcZeroReturnsEmptyArgv() throws {
        let buffer = encodeProcArgsBuffer(argv: [])
        let parsed = try #require(parseProcArgsBuffer(buffer))
        #expect(parsed.arguments == [])
        #expect(parsed.executablePath == "/usr/local/bin/ward-trigger")
    }

    @Test("A string region with no null terminator returns nil")
    func noNullTerminatorReturnsError() {
        // No terminator after the executable path.
        let noPathTerminator = [UInt8](Array("abc".utf8))
        #expect(parseProcArgsBuffer(noPathTerminator) == nil)

        // Valid header and path, but argv[0] runs off the end of the buffer.
        var noArgTerminator: [UInt8] = [1, 0, 0, 0]
        noArgTerminator += Array("/usr/bin/true".utf8)
        noArgTerminator.append(0)
        noArgTerminator += Array("unterminated-argument".utf8)
        #expect(parseProcArgsBuffer(noArgTerminator) == nil)
    }
}
