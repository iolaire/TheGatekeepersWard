import Foundation

/// Prints a simulated command-line invocation before the TCC trigger executes.
/// This makes the argv visible in the Fortress HUD's ProcessInspector output
/// and gives demo recordings a realistic-looking command.
///
/// Example output: `> docs rg "AWS_SECRET" ~/Documents/prod.env`
///
/// - Parameters:
///   - subcommand: The selected TCC trigger subcommand (`docs`, `contacts`, `mic`).
///   - extra: Additional positional arguments echoed verbatim for demo realism.
func printDemoCommandLine(subcommand: String, extra: [String]) {
    print(([">", subcommand] + extra).joined(separator: " "))
}

/// Prints the usage summary to standard output, listing all three valid
/// subcommands with a one-line description of each on the same line.
func printUsage() {
    print("Usage: WardTrigger <subcommand> [extra arguments...]")
    print("  docs      Attempt to read ~/Documents/.ward_canary — triggers the Documents folder TCC prompt.")
    print("  contacts  Request Contacts access via CNContactStore — triggers the Contacts TCC prompt.")
    print("  mic       Request Microphone access via AVFoundation — triggers the Microphone TCC prompt.")
}

/// Prints an "unrecognized subcommand" error that identifies the argument by
/// value, followed by the usage summary. All output goes to standard stdout.
///
/// - Parameter arg: The unrecognized first argument.
func printUnrecognized(_ arg: String) {
    print("Unknown subcommand: \(arg)")
    printUsage()
}
