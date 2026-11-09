import Foundation

/// Splits a byte stream into complete lines.
///
/// `log stream` output arrives in arbitrary chunks: one chunk can hold several
/// lines or end halfway through one (or halfway through a UTF-8 character).
/// Bytes after the last newline are kept until the next chunk completes them.
struct LineBuffer {
    /// Partial-line bytes larger than this are discarded, so a stream with no
    /// newlines cannot grow memory without limit. TCC lines are a few KB.
    static let maximumPendingBytes = 1 << 20

    private var pending = Data()

    /// Appends a chunk and returns every line it completed, without the
    /// trailing newline. Empty lines are skipped.
    mutating func append(_ chunk: Data) -> [String] {
        pending.append(chunk)
        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = pending[pending.startIndex..<newline]
            pending.removeSubrange(pending.startIndex...newline)
            if !lineData.isEmpty {
                lines.append(String(decoding: lineData, as: UTF8.self))
            }
        }
        if pending.count > Self.maximumPendingBytes {
            pending.removeAll()
        }
        return lines
    }
}
