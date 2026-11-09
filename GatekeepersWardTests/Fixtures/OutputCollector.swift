import Foundation

/// Collects lines written through an `OutputSink` so tests can assert on
/// output without redirecting the process-global stdout. Each test owns its
/// own collector, so parallel tests cannot interfere with each other.
final class OutputCollector {
    private(set) var lines: [String] = []

    /// A sink that appends each line to this collector.
    var sink: (String) -> Void {
        { [self] line in lines.append(line) }
    }

    /// Everything written so far, one `\n` after each line (what `print` would emit).
    var text: String {
        lines.map { $0 + "\n" }.joined()
    }
}
