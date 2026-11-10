import SwiftUI

/// The amber panel that names the event, shows the raw TCC service key and
/// the status line ("Spirit Paused at the Gate"). The border turns crimson
/// when the status is suspicious.
struct AuditBannerView: View {
    /// The protected resource being requested.
    let service: TCCService
    /// The status to show.
    let status: HUDStatus
    /// What is being asked, in plain words.
    let request: RequestText

    private var borderTone: CastleTone { status == .suspicious ? .mischiefCrimson : .torchlightAmber }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(borderTone.color)
                Text("SECURITY AUDIT: TCC EVENT DETECTED")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(CastleTone.torchlightAmber.color)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            // The sentence people will recognise from Apple's dialog.
            Text(request.headline)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(CastleTone.spectralEctoplasm.color)
                .fixedSize(horizontal: false, vertical: true)
            if let purpose = request.purpose {
                Text(purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(status.text, systemImage: "flame.fill")
                .font(.system(.callout).weight(.semibold))
                .foregroundStyle(status.tone.color)
            // The raw key stays for the technical reader, but small and quieter than the
            // sentence. 65% keeps it above the 4.5:1 contrast the spec asks for.
            Text("[\(service.rawKey)]")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CastleTone.spectralEctoplasm.color.opacity(0.65))
                .lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(borderTone.color.opacity(0.13)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderTone.color.opacity(0.85), lineWidth: 1.2))
        .accessibilityElement(children: .combine)
    }
}
