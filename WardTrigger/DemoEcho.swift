import Foundation

/// Receives one line of output (without a trailing newline).
///
/// The default sink writes to standard output via `print`. Tests inject their
/// own sink so they never have to redirect the process-global stdout.
typealias OutputSink = (String) -> Void

/// The live sink: one line to standard output.
let standardOutputSink: OutputSink = { print($0) }

/// Prints a simulated command-line invocation before the TCC trigger executes.
/// This makes the argv visible in the Fortress HUD's ProcessInspector output
/// and gives demo recordings a realistic-looking command.
///
/// Example output: `> docs rg "AWS_SECRET" ~/Documents/prod.env`
///
/// - Parameters:
///   - subcommand: The selected TCC trigger subcommand (any name in `wardTriggerCatalog`).
///   - extra: Additional positional arguments echoed verbatim for demo realism.
///   - write: Where the line goes; defaults to standard output.
func printDemoCommandLine(
    subcommand: String,
    extra: [String],
    write: OutputSink = standardOutputSink
) {
    write(([">", subcommand] + extra).joined(separator: " "))
}

/// Prints the usage summary, listing every subcommand in `wardTriggerCatalog`
/// with a one-line description of each on the same line.
///
/// - Parameter write: Where each line goes; defaults to standard output.
func printUsage(write: OutputSink = standardOutputSink) {
    write("Usage: WardTrigger <subcommand> [extra arguments...]")
    for spec in wardTriggerCatalog {
        let padding = String(repeating: " ", count: max(1, 11 - spec.name.count))
        write("  \(spec.name)\(padding)\(spec.summary)")
    }
}

/// Prints an "unrecognized subcommand" error that identifies the argument by
/// value, followed by the usage summary.
///
/// - Parameters:
///   - arg: The unrecognized first argument.
///   - write: Where each line goes; defaults to standard output.
func printUnrecognized(_ arg: String, write: OutputSink = standardOutputSink) {
    write("Unknown subcommand: \(arg)")
    printUsage(write: write)
}
