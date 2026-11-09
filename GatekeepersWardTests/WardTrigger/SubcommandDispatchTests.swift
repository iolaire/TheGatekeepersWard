import Foundation
import Testing
@testable import WardTrigger

/// Records which stub behaviors fired during a dispatch test run.
private final class TriggerRecorder {
    var fired: [String] = []
    /// Lines the stub print behaviors "wrote"; per-test, never touches stdout.
    let output = OutputCollector()

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
            recorder.output.sink(([">", subcommand] + extra).joined(separator: " "))
        },
        usage: { printUsage(write: recorder.output.sink) },
        unrecognized: { recorder.record("unrecognized:\($0)") },
        triggers: Dictionary(uniqueKeysWithValues: wardTriggerCatalog.map { spec in
            (spec.name, { recorder.record(spec.name) })
        })
    )
}

@Test("Every catalog subcommand calls only its own trigger", arguments: wardTriggerCatalog.map(\.name))
func everyCatalogSubcommandCallsOnlyItsTrigger(name: String) {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", name],
        behaviors: makeStubBehaviors(recorder)
    )
    #expect(status == 0)
    #expect(recorder.fired == [name])
}

@Test("Catalog names are unique, lowercase, and map to kTCCService keys")
func catalogIsWellFormed() {
    let names = wardTriggerCatalog.map(\.name)
    #expect(Set(names).count == names.count)
    for spec in wardTriggerCatalog {
        #expect(spec.name == spec.name.lowercased())
        #expect(spec.serviceKey.hasPrefix("kTCCService"))
    }
}

@Test("The suggested expansion set is present in the catalog")
func catalogContainsExpansionSet() {
    let names = Set(wardTriggerCatalog.map(\.name))
    let expected: Set<String> = [
        "docs", "contacts", "mic", "desktop", "downloads",
        "calendar", "reminders", "camera", "photos", "events", "screen",
    ]
    #expect(expected.isSubset(of: names))
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
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger"],
        behaviors: makeStubBehaviors(recorder)
    )
    let output = recorder.output.text
    #expect(status == 1)
    #expect(recorder.fired.isEmpty)
    for spec in wardTriggerCatalog {
        #expect(output.contains(spec.name))
    }
}

@Test("Unknown subcommand exits with code 1 and names the bad argument")
func unknownSubcommandExitsWithCode1() {
    let recorder = TriggerRecorder()
    let status = runWardTriggerDispatch(
        arguments: ["WardTrigger", "bogus"],
        behaviors: makeStubBehaviors(recorder)
    )
    let output = recorder.output.text
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
