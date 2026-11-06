import Foundation
import Testing
@testable import WardTrigger

/// Records which stub behaviors fired during a dispatch test run.
private final class TriggerRecorder {
    var fired: [String] = []

    /// Appends an event marker.
    func record(_ name: String) {
        fired.append(name)
    }
}

/// Builds stub behaviors that echo the demo command line and usage text but
/// never fire a real TCC trigger — every trigger invocation is recorded.
private func makeStubBehaviors(_ recorder: TriggerRecorder) -> WardTriggerBehaviors {
    WardTriggerBehaviors(
        demoCommandLine: { subcommand, extra in
            print(([">", subcommand] + extra).joined(separator: " "))
        },
        usage: { print("Usage: docs | contacts | mic") },
        unrecognized: { recorder.record("unrecognized:\($0)") },
        documents: { recorder.record("docs") },
        contacts: { recorder.record("contacts") },
        microphone: { recorder.record("mic") }
    )
}

@Test("`docs` subcommand calls only triggerDocuments")
func docsSubcommandCallsTriggerDocuments() {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", "docs"],
        behaviors: makeStubBehaviors(recorder)
    )
    #expect(status == 0)
    #expect(recorder.fired == ["docs"])
}

@Test("`contacts` subcommand calls only triggerContacts")
func contactsSubcommandCallsTriggerContacts() {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", "contacts"],
        behaviors: makeStubBehaviors(recorder)
    )
    #expect(status == 0)
    #expect(recorder.fired == ["contacts"])
}

@Test("`mic` subcommand calls only triggerMicrophone")
func micSubcommandCallsTriggerMicrophone() {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", "mic"],
        behaviors: makeStubBehaviors(recorder)
    )
    #expect(status == 0)
    #expect(recorder.fired == ["mic"])
}

@Test("No arguments exits with code 1 and prints the usage summary")
func noArgsExitsWithCode1AndPrintsUsage() {
    let recorder = TriggerRecorder()
    var status: Int32 = 0
    let output = captureStdout {
        status = runWardTriggerDispatch(
            arguments: ["WardTrigger"],
            behaviors: makeStubBehaviors(recorder)
        )
    }
    #expect(status == 1)
    #expect(recorder.fired.isEmpty)
    #expect(output.contains("docs"))
    #expect(output.contains("contacts"))
    #expect(output.contains("mic"))
}

@Test("Unknown subcommand exits with code 1 and names the bad argument")
func unknownSubcommandExitsWithCode1() {
    let recorder = TriggerRecorder()
    var status: Int32 = 0
    let output = captureStdout {
        status = runWardTriggerDispatch(
            arguments: ["WardTrigger", "bogus"],
            behaviors: makeStubBehaviors(recorder)
        )
    }
    #expect(status == 1)
    #expect(recorder.fired == ["unrecognized:bogus"])
    #expect(output.contains("bogus"))
}

@Test("Valid subcommand with extra arguments exits with code 0")
func validSubcommandExitsWithCode0() {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", "docs", "rg", "AWS_SECRET", "prod.env"],
        behaviors: makeStubBehaviors(recorder)
    )
    #expect(status == 0)
    #expect(recorder.fired == ["docs"])
}
