import SwiftUI

/// One legend entry: an icon and a short label for a kind of risk.
struct RiskLegendRow: Equatable {
    /// The risk this row explains.
    let category: RiskCategory
    /// SF Symbol name.
    let symbol: String
    /// Short label in capitals.
    let label: String
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

    /// The icon and label for a category.
    static func row(for category: RiskCategory) -> RiskLegendRow {
        switch category {
        case .credentialFile: return RiskLegendRow(category: category, symbol: "key.fill", label: "CREDENTIAL FILE")
        case .secretPath: return RiskLegendRow(category: category, symbol: "folder.fill", label: "SECRET PATH")
        case .networkTool:
            return RiskLegendRow(category: category, symbol: "antenna.radiowaves.left.and.right", label: "NETWORK TOOL")
        case .encoding: return RiskLegendRow(category: category, symbol: "textformat.123", label: "ENCODING TOOL")
        }
    }
}

/// Explains the flagged arguments as a wrapped row of crimson chips. Shows
/// nothing when no argument was flagged.
struct RiskLegendView: View {
    /// The flagged arguments of the current event.
    let tags: [RiskTag]

    var body: some View {
        let rows = RiskLegend.rows(for: tags)
        if !rows.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(rows, id: \.category) { row in
                    Label(row.label, systemImage: row.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CastleTone.mischiefCrimson.color)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(CastleTone.mischiefCrimson.color.opacity(0.14)))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Risks: \(rows.map(\.label).joined(separator: ", "))")
        }
    }
}
