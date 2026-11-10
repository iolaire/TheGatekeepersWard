import SwiftUI

/// One row of the lineage tree.
enum LineageRow: Equatable {
    /// A process; `depth` is its indent level, `isRequester` marks the process that asked.
    case process(node: ProcessNode, depth: Int, isRequester: Bool)
    /// A summary of processes left out of a long chain.
    case hidden(count: Int, depth: Int)
}

/// Decides which lineage rows to show and how far to indent them.
enum LineageLayout {
    /// Most rows shown, the summary row included.
    static let maxRows = 5
    /// Deepest indent level; deeper rows line up at this level.
    static let maxDepth = 4

    /// The rows for a lineage (oldest ancestor first). A chain longer than
    /// `maxRows` keeps the first process, a "… N more" row and the last
    /// `maxRows - 2` processes, so the asker is always visible.
    static func rows(for lineage: [ProcessNode], maxRows: Int = LineageLayout.maxRows) -> [LineageRow] {
        guard !lineage.isEmpty else { return [] }
        func process(_ index: Int, depth: Int) -> LineageRow {
            .process(node: lineage[index], depth: min(depth, maxDepth), isRequester: index == lineage.count - 1)
        }
        guard lineage.count > maxRows, maxRows >= 3 else {
            return lineage.indices.map { process($0, depth: $0) }
        }
        let tail = maxRows - 2
        var rows: [LineageRow] = [process(0, depth: 0), .hidden(count: lineage.count - 1 - tail, depth: 1)]
        for (offset, index) in ((lineage.count - tail)..<lineage.count).enumerated() {
            // Depth follows the position on screen, so the staircase continues after the summary.
            rows.append(process(index, depth: 2 + offset))
        }
        return rows
    }
}

/// The process chain as an indented tree, ancestors first, with the process
/// that asked highlighted.
struct ProcessLineageView: View {
    /// Oldest ancestor first.
    let lineage: [ProcessNode]
    /// The responsible app, shown beside the heading when it is not already in the chain.
    var master: ProcessNode?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                SectionLabel(text: "Lineage")
                if let master {
                    Spacer(minLength: 4)
                    SectionLabel(text: "Master app")
                    Text(verbatim: "\(master.name) (PID \(master.pid))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.8))
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(LineageLayout.rows(for: lineage).enumerated()), id: \.offset) { _, row in
                    LineageRowView(row: row)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Process chain: \(lineage.map(\.name).joined(separator: ", "))"
            + (master.map { ". Master app: \($0.name)" } ?? ""))
    }
}

/// One row: connector arrow, terminal-style tile with the spirit icon, name, PID.
private struct LineageRowView: View {
    let row: LineageRow
    private let indent: CGFloat = 16

    var body: some View {
        switch row {
        case .process(let node, let depth, let isRequester):
            HStack(spacing: 6) {
                if depth > 0 {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.5))
                }
                TerminalTile(name: node.name, glows: isRequester)
                Text(node.name).lineLimit(1)
                Text(verbatim: "(PID \(node.pid))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.6))
            }
            .font(.system(.callout, design: .monospaced).weight(isRequester ? .semibold : .regular))
            .foregroundStyle(CastleTone.spectralEctoplasm.color)
            .padding(.leading, CGFloat(depth) * indent)
            .help(node.executablePath ?? node.name)
        case .hidden(let count, let depth):
            Text("… \(count) more")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.55))
                .padding(.leading, CGFloat(depth) * indent)
        }
    }
}

/// A rounded, terminal-style tile holding a process's spirit icon.
private struct TerminalTile: View {
    let name: String
    let glows: Bool

    var body: some View {
        let icon = SpiritIcon.forProcess(named: name)
        Image(systemName: icon.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(icon.tone.color)
            .frame(width: 24, height: 20)
            .background(RoundedRectangle(cornerRadius: 5).fill(CastlePalette.obsidianSlate.opacity(0.9)))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(glows ? CastleTone.torchlightAmber.color : CastleTone.spectralEctoplasm.color.opacity(0.35),
                        lineWidth: glows ? 1.5 : 1))
            .shadow(color: glows ? CastleTone.torchlightAmber.color.opacity(0.6) : .clear, radius: 6)
    }
}
