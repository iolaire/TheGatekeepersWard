// WardTrigger entry point — argument dispatch only.
//
// The dispatch contract lives in `runWardTriggerDispatch(arguments:behaviors:)`
// (Dispatch.swift) with function-pointer injection so tests can stub the
// trigger functions; this file wires the live implementations.
import Foundation

let wardTriggerBehaviors = WardTriggerBehaviors(
    demoCommandLine: { printDemoCommandLine(subcommand: $0, extra: $1) },
    usage: { printUsage() },
    unrecognized: { printUnrecognized($0) },
    documents: triggerDocuments,
    contacts: triggerContacts,
    microphone: triggerMicrophone
)

exit(runWardTriggerDispatch(
    arguments: CommandLine.arguments,
    behaviors: wardTriggerBehaviors
))
