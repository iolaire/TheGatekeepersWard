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
        let collector = OutputCollector()
        printDemoCommandLine(subcommand: "docs", extra: words, write: collector.sink)
        let output = collector.text
        #expect(output.hasPrefix("> docs"))
        for word in words {
            #expect(output.contains(word))
        }
    }
}

@Test("Empty extra argument list produces the minimal `> subcommand` line")
func noExtraArgsProducesMinimalOutput() {
    let collector = OutputCollector()
    printDemoCommandLine(subcommand: "contacts", extra: [], write: collector.sink)
    let output = collector.text
    #expect(output == "> contacts\n")
}

@Test("Usage summary lists every catalog subcommand on its own line")
func usageMentionsEverySubcommand() {
    let collector = OutputCollector()
    printUsage(write: collector.sink)
    let lines = collector.text.split(separator: "\n").map(String.init)
    for spec in wardTriggerCatalog {
        #expect(lines.contains { $0.hasPrefix("  \(spec.name) ") && $0.contains(spec.summary) })
    }
}

@Test("Unrecognized-subcommand message identifies the argument by value")
func unrecognizedPrefixesArgName() {
    let collector = OutputCollector()
    printUnrecognized("bogus", write: collector.sink)
    let output = collector.text
    #expect(output.contains("bogus"))
    #expect(output.contains("Unknown subcommand: bogus"))
    // printUnrecognized must be followed by the usage summary.
    for spec in wardTriggerCatalog {
        #expect(output.contains(spec.name))
    }
}
