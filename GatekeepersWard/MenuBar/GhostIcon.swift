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
        /// Sleepy eyes and a crimson `!` badge: the Ward cannot read the system log.
        case unavailable

        /// The expression both figures wear in this pose.
        var expression: FaceExpression { self == .idle || self == .unavailable ? .sleepy : .surprised }

        /// The palette both figures are drawn with in this pose.
        var style: FigureRenderer.Style { self == .alertBlink ? .inverted : .normal }
    }

    /// Renders the two spirits.
    static func image(_ pose: Pose) -> NSImage {
        let image = NSImage(size: canvas, flipped: false) { _ in
            // The cloaked spirit is drawn first; the solo spirit sits in front of it.
            FigureRenderer.draw(.cloaked, pose.expression, in: cloakedFrame, detail: .compact, style: pose.style)
            FigureRenderer.draw(.solo, pose.expression, in: soloFrame, detail: .compact, style: pose.style)
            switch pose {
            case .idle: break
            case .alert, .alertBlink: drawLantern(raised: pose == .alert)
            case .unavailable: drawBadge()
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

    /// Centre of the not-watching badge, in canvas points. It sits in the empty
    /// top-left corner above the solo spirit, clear of both faces; the lantern
    /// (alert poses only) uses the same area but is never shown with the badge.
    static let badgeCenter = NSPoint(x: 4.2, y: 18.0)
    /// Radius of the not-watching badge in points, not counting its 0.8 pt light ring.
    static let badgeRadius: CGFloat = 3.1

    /// A crimson disc with a white `!` and a light ring, so it shows on light and dark bars.
    private static func drawBadge() {
        let c = badgeCenter, r = badgeRadius
        CastleNSColors.spectralEctoplasm.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - r - 0.8, y: c.y - r - 0.8, width: (r + 0.8) * 2, height: (r + 0.8) * 2)).fill()
        CastleNSColors.mischiefCrimson.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: c.x - 0.5, y: c.y - 0.4, width: 1.0, height: 2.3), xRadius: 0.5, yRadius: 0.5).fill()
        NSBezierPath(ovalIn: NSRect(x: c.x - 0.55, y: c.y - 1.9, width: 1.1, height: 1.1)).fill()
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
