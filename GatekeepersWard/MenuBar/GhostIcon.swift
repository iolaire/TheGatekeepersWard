import AppKit

/// Draws the menu bar icon, the small solo spirit in front of the larger
/// cloaked spirit, as a 24×22 pt full-colour image in the Castle Keep palette.
/// It is not a template image, so it uses only fixed sRGB colours
/// (`CastleNSColors`) and looks the same on light and dark menu bars. SF
/// Symbols has no ghost, and SwiftPM cannot bundle an asset catalog, so it is
/// drawn in code by `FigureRenderer` at compact detail.
enum GhostIcon {
    /// Size of the rendered image in points (the menu bar is ~22–24 pt tall).
    static let canvas = NSSize(width: 24, height: 22)
    /// Where the smaller solo spirit is drawn, in canvas points. Each figure
    /// fills the middle 88% of its frame, and the frames overlap. The frames leave
    /// about 1.5 pt around the figures for the 1.4 pt outline.
    static let soloFrame = NSRect(x: -0.8, y: 0.4, width: 16, height: 16)
    /// Where the larger cloaked spirit is drawn, in canvas points.
    static let cloakedFrame = NSRect(x: 6.5, y: 0.4, width: 21, height: 21)

    /// The icon's pose.
    enum Pose {
        /// Sleepy eyes on both figures, no lantern.
        case idle
        /// Wide eyes, lantern raised above the solo spirit. Normal palette.
        case alert
        /// Wide eyes, lantern lowered, and the palette inverted (dark bodies, light
        /// outline and features). Alternating with `alert` makes the icon pulse.
        case alertBlink

        /// The expression both figures wear in this pose.
        var expression: FaceExpression { self == .idle ? .sleepy : .surprised }

        /// The palette both figures are drawn with in this pose.
        var style: FigureRenderer.Style { self == .alertBlink ? .inverted : .normal }
    }

    /// Renders the two spirits.
    static func image(_ pose: Pose) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { _ in
            // The cloaked spirit is drawn first; the solo spirit sits in front of it.
            FigureRenderer.draw(.cloaked, pose.expression, in: cloakedFrame, detail: .compact, style: pose.style)
            FigureRenderer.draw(.solo, pose.expression, in: soloFrame, detail: .compact, style: pose.style)
            if pose != .idle {
                drawLantern(raised: pose == .alert)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Maps a point in a figure's unit square to canvas points.
    static func canvasPoint(_ unit: CGPoint, in frame: NSRect) -> NSPoint {
        FigureRenderer.point(unit, in: frame)
    }

    /// A small lantern hovering above (raised) or resting on (lowered) the solo
    /// spirit's head: handle ring, cap, glowing glass and base.
    private static func drawLantern(raised: Bool) {
        let amber = CastleNSColors.torchlightAmber
        let x: CGFloat = 5.1, bottom: CGFloat = raised ? 16.4 : 14.4
        // Handle ring above the cap.
        let handle = NSBezierPath(ovalIn: NSRect(x: x + 0.7, y: bottom + 3.5, width: 1.6, height: 1.4))
        handle.lineWidth = 0.6
        amber.setStroke()
        handle.stroke()
        amber.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: 3, height: 0.7), xRadius: 0.3, yRadius: 0.3).fill()
        NSBezierPath(roundedRect: NSRect(x: x, y: bottom + 3, width: 3, height: 0.7), xRadius: 0.3, yRadius: 0.3).fill()
        // Frame and glass: amber bars around a light flame.
        NSBezierPath(rect: NSRect(x: x + 0.2, y: bottom + 0.7, width: 2.6, height: 2.3)).fill()
        CastleNSColors.spectralEctoplasm.setFill()
        NSBezierPath(ovalIn: NSRect(x: x + 0.95, y: bottom + 1.1, width: 1.1, height: 1.6)).fill()
    }
}
