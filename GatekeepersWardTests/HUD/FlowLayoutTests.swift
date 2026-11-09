import Foundation
import Testing
@testable import GatekeepersWard

/// Tests for the lineage wrapping logic.
struct FlowLayoutTests {
    @Test("Items wrap when the next one would not fit")
    func wrapsWhenFull() {
        // 100 + 6 + 100 + 6 + 100 = 312 > 300, so the third item wraps.
        #expect(flowRows(widths: [100, 100, 100], maxWidth: 300, spacing: 6) == [[0, 1], [2]])
    }

    @Test("Items that fit exactly stay on one line")
    func exactFit() {
        #expect(flowRows(widths: [100, 100], maxWidth: 206, spacing: 6) == [[0, 1]])
    }

    @Test("An item wider than the line gets its own row and is never dropped")
    func oversizedItem() {
        #expect(flowRows(widths: [50, 500, 50], maxWidth: 300, spacing: 6) == [[0], [1], [2]])
    }

    @Test("The real six-process Zed chain keeps every process, last one included")
    func zedChainKeepsRequester() {
        // Approximate chip widths for zed, node, kiro-cli, kiro-cli-chat, bash, WardTrigger.
        let widths: [CGFloat] = [84, 92, 104, 128, 88, 128]
        let rows = flowRows(widths: widths, maxWidth: 332, spacing: 6)
        #expect(rows.flatMap { $0 } == Array(0..<6))
        #expect(rows.count > 1)
    }

    @Test("No items, no rows")
    func empty() {
        #expect(flowRows(widths: [], maxWidth: 300, spacing: 6).isEmpty)
    }
}
