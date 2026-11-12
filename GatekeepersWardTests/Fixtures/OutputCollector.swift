import Foundation
import os

/// Collects lines written through an `OutputSink` so tests can assert on
/// output without redirecting the process-global stdout. Each test owns its
/// own collector, so parallel tests cannot interfere with each other.
///
/// Safe to share across isolation domains: the lines sit behind a lock.
final class OutputCollector: Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [String]())

    /// Every line written so far.
    var lines: [String] {
        storage.withLock { $0 }
    }

    /// A sink that appends each line to this collector.
    var sink: @Sendable (String) -> Void {
        { [self] line in storage.withLock { $0.append(line) } }
    }

    /// Everything written so far, one `\n` after each line (what `print` would emit).
    var text: String {
        lines.map { $0 + "\n" }.joined()
    }
}
