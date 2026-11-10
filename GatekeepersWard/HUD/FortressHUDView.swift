import AppKit
import SwiftUI

/// Fixed sizes for the Fortress HUD card.
enum HUDMetrics {
    /// Card width in points. Compact, so it fits beside Apple's alert.
    static let width: CGFloat = 400
    /// Tallest the card may grow, in points. The card grows with its content (the
    /// command can run to 12 lines); this is only a hard stop.
    static let maxHeight: CGFloat = 900
}

/// The Fortress HUD card: gate banner, header, audit banner, lineage, risk
/// legend, command and the instruction pills
/// (see `.kiro/specs/castle-keep-visual-theme`).
///
/// It only informs: nothing in it is a control. Every section lives in its own file.
struct FortressHUDView: View {
    /// What to show.
    let content: HUDContent
    /// Tallest the card may grow. Tests pass `.infinity` to measure the natural height.
    var maxHeight: CGFloat = HUDMetrics.maxHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GateBanner()
            HUDHeader(service: content.prompt.service)
            VStack(alignment: .leading, spacing: 8) {
                AuditBannerView(service: content.prompt.service, status: content.status,
                                request: content.displayedRequest)
                if let spirit = content.spirit {
                    ProcessLineageView(lineage: spirit.lineage, master: content.visibleMasterApp)
                    RiskLegendView(tags: content.riskTags)
                    CommandBoxView(spirit: spirit, service: content.prompt.service,
                                   status: content.status, riskTags: content.riskTags)
                }
                InstructionPillsView()
            }
            .padding(12)
        }
        .frame(width: HUDMetrics.width)
        .frame(maxHeight: maxHeight)
        .background(.ultraThinMaterial)
        .background(CastlePalette.obsidianSlate.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CastleTone.wroughtIron.color, lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }
}

/// A small violet caption above a section.
struct SectionLabel: View {
    /// The caption (shown in capitals).
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(CastleTone.kiroViolet.color)
    }
}
