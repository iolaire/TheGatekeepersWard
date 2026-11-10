import SwiftUI

/// One instruction: the name of Apple's button and what it means in Ward wording.
struct InstructionPill: Equatable {
    /// The label on Apple's dialog button.
    let appleButton: String
    /// The Ward wording for that choice.
    let meaning: String
    /// The pill's colour.
    let tone: CastleTone
}

/// The canonical copy of the instruction pills (`.kiro/steering/swiftui-hud-design.md` §7).
///
/// The Ward cannot press Apple's buttons, so these only remind the user which
/// button does what. They are labels, never controls.
enum InstructionCopy {
    /// The line above the pills.
    static let caption = "Answer in Apple's dialog"

    /// Deny first, then allow, matching the order of Apple's buttons.
    static let pills: [InstructionPill] = [
        InstructionPill(appleButton: "Don't Allow", meaning: "Lower Portcullis", tone: .mischiefCrimson),
        InstructionPill(appleButton: "Allow", meaning: "Let Spirit Pass", tone: .torchlightAmber),  // palette-ok: Apple's own button name
    ]

    /// One sentence for VoiceOver covering the caption and both pills.
    static var accessibilityLabel: String {
        let choices = pills.map { "\($0.appleButton) means \($0.meaning)" }.joined(separator: ". ")
        return "\(caption). \(choices)."
    }
}

/// The caption and the two glowing instruction pills. Not interactive: hit
/// testing is off and VoiceOver reads it as one static sentence.
struct InstructionPillsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(InstructionCopy.caption)
                .font(.system(size: 11))
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(InstructionCopy.pills, id: \.meaning) { pill in
                    PillView(pill: pill)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(InstructionCopy.accessibilityLabel)
    }
}

/// One glowing pill.
private struct PillView: View {
    let pill: InstructionPill

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(pill.appleButton)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.75))
            Text(pill.meaning)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(CastleTone.spectralEctoplasm.color)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(pill.tone.color.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(pill.tone.color, lineWidth: 1.5))
        .shadow(color: pill.tone.color.opacity(0.5), radius: 6)
    }
}
