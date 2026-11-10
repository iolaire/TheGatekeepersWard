import AppKit
import SwiftUI

/// Vector `NSImage`s of the spirits for use in SwiftUI.
///
/// Each image is an `NSImage` with a drawing handler that calls
/// `FigureRenderer`, so it is redrawn crisply at any size and on any display
/// scale. Images are cached, because the drawing handler is cheap to keep and
/// the Gate_Banner redraws its figures while they bob.
@MainActor
enum FigureImages {
    private static var cache: [String: NSImage] = [:]

    /// Space around a single figure, as a fraction of the image side, so its
    /// aura is not cropped by the image edge.
    static let inset: CGFloat = 0.14

    /// Width over height of the pair image.
    static let pairAspect: CGFloat = 7.0 / 6.0

    /// A square image of one spirit at full detail.
    static func figure(_ kind: FigureKind, _ expression: FaceExpression) -> NSImage {
        let key = "\(kind)-\(expression)"
        if let cached = cache[key] { return cached }
        let image = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
            let frame = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
            FigureRenderer.draw(kind, expression, in: frame, detail: .full)
            return true
        }
        cache[key] = image
        return image
    }

    /// The solo spirit in front of the cloaked spirit, as in the menu bar icon.
    static func pair(_ expression: FaceExpression) -> NSImage {
        let key = "pair-\(expression)"
        if let cached = cache[key] { return cached }
        let image = NSImage(size: NSSize(width: 140, height: 120), flipped: false) { _ in
            // The cloaked frame is 100 pt; the solo frame is 0.75 of it, tucked in
            // front of the cloak's left edge (same arrangement as `GhostIcon`).
            let cloaked = NSRect(x: 42, y: 12, width: 100, height: 100)
            let solo = NSRect(x: cloaked.minX - 35.8, y: cloaked.minY + 1.5, width: 75, height: 75)
            FigureRenderer.draw(.cloaked, expression, in: cloaked, detail: .full)
            FigureRenderer.draw(.solo, expression, in: solo, detail: .full)
            return true
        }
        cache[key] = image
        return image
    }
}

/// One spirit drawn as vector art. Decorative: hidden from VoiceOver.
struct FigureImage: View {
    /// Which spirit.
    let kind: FigureKind
    /// The face to wear.
    var expression: FaceExpression = .happy
    /// Side of the (square) image in points. The figure itself fills about 70% of it.
    let size: CGFloat

    var body: some View {
        Image(nsImage: FigureImages.figure(kind, expression))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The ghost pair (the HUD header logo). Decorative: hidden from VoiceOver.
struct GhostPairView: View {
    /// Height of the image in points.
    let height: CGFloat
    /// The face both spirits wear.
    var expression: FaceExpression = .happy

    var body: some View {
        Image(nsImage: FigureImages.pair(expression))
            .resizable()
            .interpolation(.high)
            .frame(width: height * FigureImages.pairAspect, height: height)
            .accessibilityHidden(true)
    }
}
