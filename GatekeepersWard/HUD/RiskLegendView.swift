import SwiftUI

/// One legend entry: an icon, a short label and a plain-language reason for a kind of risk.
struct RiskLegendRow: Equatable {
    /// The risk this row explains.
    let category: RiskCategory
    /// SF Symbol name.
    let symbol: String
    /// Short label in capitals.
    let label: String
    /// Why this kind of argument is risky, short enough to share one line with
    /// the label (spec `hud-plain-language-copy`, Requirement 2).
    let reason: String
}

/// Builds the legend from the risk tags of the current event.
enum RiskLegend {
    /// The order rows appear in.
    static let order: [RiskCategory] = [.credentialFile, .secretPath, .networkTool, .encoding]

    /// One row per distinct category present in `tags`, in `order`. Empty when there are no tags.
    static func rows(for tags: [RiskTag]) -> [RiskLegendRow] {
        let present = Set(tags.map(\.category))
        return order.filter(present.contains).map(row(for:))
    }

    /// The icon, label and reason for a category.
    static func row(for category: RiskCategory) -> RiskLegendRow {
        switch category {
        case .credentialFile:
            return RiskLegendRow(category: category, symbol: "key.fill", label: "CREDENTIAL FILE",
                                 reason: "Usually holds passwords or API keys.")
        case .secretPath:
            return RiskLegendRow(category: category, symbol: "folder.fill", label: "SECRET PATH",
                                 reason: "Often points to stored secrets.")
        case .networkTool:
            return RiskLegendRow(category: category, symbol: "antenna.radiowaves.left.and.right",
                                 label: "NETWORK TOOL", reason: "Can send data off your Mac.")
        case .encoding:
            return RiskLegendRow(category: category, symbol: "textformat.123", label: "ENCODING TOOL",
                                 reason: "Can hide data before it is sent.")
        }
    }

    /// What VoiceOver reads: each label with its reason.
    static func accessibilityLabel(for rows: [RiskLegendRow]) -> String {
        "Risks: " + rows.map { "\($0.label), \($0.reason)" }.joined(separator: "; ")
    }
}

/// Explains the flagged arguments: one line per risk category, the crimson
/// icon and label followed by the reason. Shows nothing when no argument was flagged.
struct RiskLegendView: View {
    /// The flagged arguments of the current event.
    let tags: [RiskTag]

    var body: some View {
        let rows = RiskLegend.rows(for: tags)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(rows, id: \.category) { row in
                    RiskLegendLine(row: row)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(CastleTone.mischiefCrimson.color.opacity(0.10)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(RiskLegend.accessibilityLabel(for: rows))
        }
    }
}

/// One legend line: the category icon and label in crimson, then the reason in dim ectoplasm.
struct RiskLegendLine: View {
    /// The row to draw.
    let row: RiskLegendRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: row.symbol)
                .foregroundStyle(CastleTone.mischiefCrimson.color)
                .frame(width: 14)
            Text(row.label)
                .fontWeight(.semibold)
                .foregroundStyle(CastleTone.mischiefCrimson.color)
            Text(row.reason)
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11))
    }
}
