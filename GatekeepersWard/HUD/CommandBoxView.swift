import SwiftUI

/// The executed command in a monospaced box with an amber border (crimson when
/// the status is suspicious), the requested vault, the working directory and
/// the flagged arguments.
struct CommandBoxView: View {
    /// The inspected process.
    let spirit: ProcessSnapshot
    /// The protected resource being requested.
    let service: TCCService
    /// The status; decides the border colour.
    let status: HUDStatus
    /// The flagged arguments.
    let riskTags: [RiskTag]

    private var borderTone: CastleTone { status == .suspicious ? .mischiefCrimson : .torchlightAmber }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(text: "Executed command")
            Text(spirit.commandLine.isEmpty ? spirit.executablePath : "$ " + spirit.commandLine)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(CastleTone.spectralEctoplasm.color)
                .lineLimit(12)
                // Grow taller to show the whole command rather than cutting it off.
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .help(spirit.commandLine)
            Divider().overlay(borderTone.color.opacity(0.4))
            detail(label: "vault:", value: service.vaultName)
            if let cwd = spirit.workingDirectory {
                detail(label: "in", value: cwd)
            }
            if !riskTags.isEmpty {
                RiskTagView(tags: riskTags)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(CastlePalette.obsidianSlate.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderTone.color.opacity(0.85), lineWidth: 1.2))
    }

    private func detail(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label).foregroundStyle(borderTone.color)
            Text(value).foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.8))
                .lineLimit(1).truncationMode(.middle)
        }
        .font(.system(size: 11, design: .monospaced))
    }
}

/// Crimson capsules for each suspicious argument (steering §5).
struct RiskTagView: View {
    /// The flagged arguments.
    let tags: [RiskTag]

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                Text("⚠ \(tag.argument)")
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(CastleTone.mischiefCrimson.color)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(CastleTone.mischiefCrimson.color.opacity(0.15)))
                    .accessibilityValue("Suspicious argument: \(tag.argument)")
            }
        }
    }
}
