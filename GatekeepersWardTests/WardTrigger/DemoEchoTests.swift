import Foundation
import Testing
@testable import WardTrigger

// Feature: ward-trigger, Property 5: extra argv passthrough
@Test("Property 5: every extra argument appears in the echoed demo command line")
func extraArgsAppearsInOutput() {
    var rng = SeededRNG(seed: 0x57A2D_11CE)
    let iterations = ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    for _ in 0..<iterations {
        let wordCount = Int.random(in: 1...6, using: &rng)
        let words = generatePrintableASCIIArgv(count: wordCount, rng: &rng)
        let output = captureStdout {
            printDemoCommandLine(subcommand: "docs", extra: words)
        }
        #expect(output.hasPrefix("> docs"))
        for word in words {
            #expect(output.contains(word))
        }
    }
}

@Test("Empty extra argument list produces the minimal `> subcommand` line")
func noExtraArgsProducesMinimalOutput() {
    let output = captureStdout {
        printDemoCommandLine(subcommand: "contacts", extra: [])
    }
    #expect(output == "> contacts\n")
}

@Test("Usage summary mentions all three subcommands")
func usageMentionsAllThreeSubcommands() {
    let output = captureStdout {
        printUsage()
    }
    #expect(output.contains("docs"))
    #expect(output.contains("contacts"))
    #expect(output.contains("mic"))
}

@Test("Unrecognized-subcommand message identifies the argument by value")
func unrecognizedPrefixesArgName() {
    let output = captureStdout {
        printUnrecognized("bogus")
    }
    #expect(output.contains("bogus"))
    #expect(output.contains("Unknown subcommand: bogus"))
    // printUnrecognized must be followed by the usage summary.
    #expect(output.contains("docs"))
    #expect(output.contains("contacts"))
    #expect(output.contains("mic"))
}
