import SwiftUI

/// The header under the gate banner: the neon title, the vault that was
/// requested, and the ghost pair logo.
struct HUDHeader: View {
    /// The protected resource being requested.
    let service: TCCService

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                NeonText(text: "GATEKEEPER'S WARD")
                Text(service.vaultName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(CastleTone.spectralEctoplasm.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(CastleTone.kiroViolet.color.opacity(0.35)))
                    .help(service.rawKey)
            }
            Spacer(minLength: 4)
            GhostPairView(height: 50)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(LinearGradient(
            colors: [CastleTone.kiroViolet.color.opacity(0.28), CastleTone.kiroViolet.color.opacity(0.08)],
            startPoint: .top, endPoint: .bottom))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gatekeeper's Ward: \(service.vaultName) requested")
    }
}
