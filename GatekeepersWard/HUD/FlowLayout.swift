import SwiftUI

/// Packs item widths into rows no wider than `maxWidth`, left to right.
///
/// - Returns: For each row, the indices of the items in it. An item wider
///   than `maxWidth` gets a row of its own rather than being dropped.
func flowRows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [[Int]] {
    var rows: [[Int]] = []
    var current: [Int] = []
    var used: CGFloat = 0
    for (index, width) in widths.enumerated() {
        let needed = current.isEmpty ? width : used + spacing + width
        if !current.isEmpty, needed > maxWidth {
            rows.append(current)
            current = [index]
            used = width
        } else {
            current.append(index)
            used = needed
        }
    }
    if !current.isEmpty { rows.append(current) }
    return rows
}

/// Lays children out left to right, wrapping to a new line when the next one
/// does not fit. Used for the lineage so every process stays visible in the
/// fixed-width card. (`Layout` is available from macOS 13.)
struct FlowLayout: Layout {
    /// Gap between items on a line and between lines.
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let maxWidth = proposal.width ?? .infinity
        let rows = flowRows(widths: sizes.map(\.width), maxWidth: maxWidth, spacing: spacing)
        var height: CGFloat = 0
        var width: CGFloat = 0
        for (rowIndex, row) in rows.enumerated() {
            var rowWidth: CGFloat = 0
            var rowHeight: CGFloat = 0
            for (position, index) in row.enumerated() {
                rowWidth += sizes[index].width + (position > 0 ? spacing : 0)
                rowHeight = max(rowHeight, sizes[index].height)
            }
            width = max(width, rowWidth)
            height += rowHeight + (rowIndex > 0 ? spacing : 0)
        }
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = flowRows(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: spacing)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            var x = bounds.minX
            for index in row {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height)
                )
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
}
