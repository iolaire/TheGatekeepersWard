// WardTrigger entry point — argument dispatch only.
//
// The dispatch contract lives in `runWardTriggerDispatch(arguments:behaviors:)`
// (Dispatch.swift) with function-pointer injection so tests can stub the
// trigger functions; the live trigger table is `wardTriggerCatalog`
// (TriggerCatalog.swift).
import Foundation

let wardTriggerBehaviors = WardTriggerBehaviors(
    demoCommandLine: { printDemoCommandLine(subcommand: $0, extra: $1) },
    usage: { printUsage() },
    unrecognized: { printUnrecognized($0) },
    triggers: WardTriggerBehaviors.liveTriggers
)

exit(runWardTriggerDispatch(
    arguments: CommandLine.arguments,
    behaviors: wardTriggerBehaviors
))
