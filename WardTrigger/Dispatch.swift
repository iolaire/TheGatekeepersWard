import Foundation

/// The behaviors invoked by the WardTrigger command-line dispatcher, collected
/// in one substitutable struct so tests can replace the trigger functions with
/// stubs (function-pointer injection) instead of firing real TCC dialogs.
struct WardTriggerBehaviors {
    /// Prints the simulated command line for the invocation.
    var demoCommandLine: (String, [String]) -> Void
    /// Prints the usage summary.
    var usage: () -> Void
    /// Prints the unrecognized-subcommand error (without the usage summary).
    var unrecognized: (String) -> Void
    /// The Documents TCC trigger.
    var documents: () -> Void
    /// The Contacts TCC trigger.
    var contacts: () -> Void
    /// The Microphone TCC trigger.
    var microphone: () -> Void
}

/// Dispatches WardTrigger command-line arguments to the matching trigger.
///
/// Contract (Requirements 1.1–1.7):
/// - No arguments → usage summary, exit code 1.
/// - `docs` / `contacts` / `mic` → demo command line, then the one matching
///   trigger only, exit code 0.
/// - Any other first argument → demo command line, unrecognized error, usage
///   summary, exit code 1.
///
/// The demo command line is always echoed before the trigger fires so that
/// `ProcessInspector` sees a fully-formed argv during a live TCC prompt.
///
/// - Parameters:
///   - arguments: The full argument vector, including the executable name at
///     index 0 (i.e. `CommandLine.arguments`).
///   - behaviors: The behaviors to invoke; `.live` wiring is done in main.swift.
/// - Returns: The process exit code: 1 for a bad invocation, 0 after a trigger
///   completes (regardless of the user's Allow/Deny choice).
func runWardTriggerDispatch(
    arguments: [String],
    behaviors: WardTriggerBehaviors
) -> Int32 {
    guard arguments.count >= 2 else {
        behaviors.usage()
        return 1
    }

    let subcommand = arguments[1]
    let extraArguments = Array(arguments.dropFirst(2))

    behaviors.demoCommandLine(subcommand, extraArguments)

    switch subcommand {
    case "docs":
        behaviors.documents()
    case "contacts":
        behaviors.contacts()
    case "mic":
        behaviors.microphone()
    default:
        behaviors.unrecognized(subcommand)
        behaviors.usage()
        return 1
    }

    return 0
}
