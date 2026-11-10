import SwiftUI

/// Title text with a violet neon outline and glow, like the logo in the
/// reference mock.
///
/// The mock's display face cannot be bundled, so this uses a heavy rounded
/// system font. SwiftUI `Text` has no stroke, so the outline is the text drawn
/// eight times around the centre in Kiro Violet, with two soft violet shadows
/// for the glow. To use a gothic face later, change `label` only.
struct NeonText: View {
    /// The words to show.
    let text: String
    /// Font size in points.
    var size: CGFloat = 19

    /// Offsets for the outline copies, on a circle of radius 1.1 pt.
    private static let outlineOffsets: [CGSize] = (0..<8).map { index in
        let angle = Double(index) * .pi / 4
        return CGSize(width: cos(angle) * 1.1, height: sin(angle) * 1.1)
    }

    private var label: some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(1.4)
            .lineLimit(1)
            .fixedSize()
    }

    var body: some View {
        ZStack {
            ForEach(Self.outlineOffsets.indices, id: \.self) { index in
                label.foregroundStyle(CastleTone.kiroViolet.color).offset(Self.outlineOffsets[index])
            }
            label.foregroundStyle(CastleTone.spectralEctoplasm.color)
        }
        .shadow(color: CastleTone.kiroViolet.color.opacity(0.9), radius: 3)
        .shadow(color: CastleTone.kiroViolet.color.opacity(0.6), radius: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isHeader)
    }
}
