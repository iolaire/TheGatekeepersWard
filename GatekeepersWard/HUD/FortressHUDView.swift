import AppKit
import SwiftUI

/// The Fortress HUD card: header, lineage, command, status
/// (layout from `.kiro/steering/swiftui-hud-design.md` §3).
struct FortressHUDView: View {
    /// What to show.
    let content: HUDContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HUDHeader(service: content.prompt.service)
            VStack(alignment: .leading, spacing: 12) {
                if let master = content.masterApp {
                    LabeledLine(label: "Master App", value: "\(master.name) (PID \(master.pid))")
                }
                if let spirit = content.spirit {
                    ProcessLineageView(lineage: spirit.lineage)
                    CommandSection(spirit: spirit, riskTags: content.riskTags)
                }
                StatusBadge(status: content.status)
            }
            .padding(14)
        }
        .frame(width: 360)
        .frame(maxHeight: 480)
        .background(.ultraThinMaterial)
        .background(CastlePalette.obsidianSlate.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CastleTone.wroughtIron.color, lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }
}

/// Violet header bar with the ghost, title and vault name.
private struct HUDHeader: View {
    let service: TCCService

    var body: some View {
        HStack(spacing: 8) {
            Text("👻").font(.system(size: 16))
            Text("GATEKEEPER'S WARD")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .tracking(1.2)
            Spacer()
            Text(service.vaultName)
                .font(.system(.caption).weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(CastlePalette.obsidianSlate.opacity(0.4)))
                .help(service.rawKey)
        }
        .foregroundStyle(CastleTone.spectralEctoplasm.color)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(CastleTone.kiroViolet.color.opacity(0.85))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gatekeeper's Ward: \(service.vaultName) requested")
    }
}

/// A small caption label above a value.
private struct LabeledLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CastleTone.kiroViolet.color)
            Text(value)
                .font(.system(.callout))
                .foregroundStyle(CastleTone.spectralEctoplasm.color)
                .textSelection(.enabled)
        }
    }
}

/// The process chain, ancestors first, the asking process highlighted.
struct ProcessLineageView: View {
    /// Oldest ancestor first.
    let lineage: [ProcessNode]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LINEAGE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CastleTone.kiroViolet.color)
            // Long chains wrap onto new lines so every process, especially
            // the last one (the asker), stays visible in the 360 pt card.
            // Each arrow is part of the chip after it, so they wrap together.
            FlowLayout(spacing: 6) {
                ForEach(Array(lineage.enumerated()), id: \.offset) { index, node in
                    HStack(spacing: 6) {
                        if index > 0 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.5))
                        }
                        SpiritNode(node: node, isRequester: index == lineage.count - 1)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Process chain: \(lineage.map(\.name).joined(separator: ", "))")
    }
}

/// One process in the lineage: spirit icon, name, PID.
private struct SpiritNode: View {
    let node: ProcessNode
    let isRequester: Bool

    var body: some View {
        let icon = SpiritIcon.forProcess(named: node.name)
        HStack(spacing: 4) {
            Image(systemName: icon.symbol).foregroundStyle(icon.tone.color)
            Text(node.name).lineLimit(1)
            Text(verbatim: String(node.pid)).font(.system(size: 11)).opacity(0.6)
        }
        .font(.system(.callout))
        .foregroundStyle(CastleTone.spectralEctoplasm.color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6).fill(CastleTone.wroughtIron.color.opacity(0.6)))
        .shadow(color: isRequester ? CastleTone.torchlightAmber.color.opacity(0.6) : .clear, radius: 6)
        .help(node.executablePath ?? node.name)
    }
}

/// The executed command, working directory and risk tags.
private struct CommandSection: View {
    let spirit: ProcessSnapshot
    let riskTags: [RiskTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EXECUTED COMMAND")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CastleTone.kiroViolet.color)
            Text(spirit.commandLine.isEmpty ? spirit.executablePath : "$ " + spirit.commandLine)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(CastleTone.spectralEctoplasm.color)
                .lineLimit(6)
                .textSelection(.enabled)
            if let cwd = spirit.workingDirectory {
                Text("in \(cwd)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.7))
                    .lineLimit(1).truncationMode(.middle)
            }
            if !riskTags.isEmpty {
                RiskTagView(tags: riskTags)
            }
        }
    }
}

/// Crimson capsules for each suspicious argument (steering §5).
struct RiskTagView: View {
    /// The flagged arguments.
    let tags: [RiskTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

/// The status line plus the reminder of Apple's two buttons.
private struct StatusBadge: View {
    let status: HUDStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(status.text, systemImage: "flame.fill")
                .font(.system(.callout).weight(.semibold))
                .foregroundStyle(status.tone.color)
            // Informational only: we cannot press Apple's dialog buttons.
            Text("Answer in Apple's dialog — Allow: “Let Spirit Pass” · Don't Allow: “Lower Portcullis”")
                .font(.system(size: 11))
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
