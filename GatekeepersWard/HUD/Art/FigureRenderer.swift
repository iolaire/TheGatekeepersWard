import AppKit

/// Draws the two spirit characters from `GhostGeometry`.
///
/// One renderer serves the menu bar (`.compact`) and the HUD and review
/// images (`.full`), so the characters look the same everywhere. It draws in
/// the current `NSGraphicsContext`, in the given frame: a two-tone dark outline
/// (with a violet aura when `.full`), the body fill with layered shading and an
/// inner rim light, the gloss highlights, and the face. At full detail the
/// whole figure is drawn in a transparency layer and its tail is faded out.
///
/// Compact detail is simplified for readability at about 20 pt tall: a strong
/// outline, large eyes and a bold smile, and none of the small shading details.
enum FigureRenderer {
    /// How much detail to draw.
    enum Detail {
        /// Menu bar size: opaque, strong outline, large face, no aura, gloss, rim light, glints or blush.
        case compact
        /// HUD and review size: everything, with a translucent fading tail.
        case full
    }

    /// Which palette to draw with.
    enum Style {
        /// A light body with a dark outline.
        case normal
        /// A dark body with a light outline and features, used for the alert pulse.
        case inverted
    }

    private typealias Colors = CastleNSColors

    /// How much larger the eyes are drawn at compact detail.
    private static let compactEyeScale: CGFloat = 1.5
    /// Extra vertical scale for sleepy eyes at compact detail, so they stay visible.
    private static let compactSleepyEyeScale: CGFloat = 2.4
    /// How much longer the smile is drawn at compact detail.
    private static let compactSmileScale: CGFloat = 1.4
    /// Visible outline width at compact detail, in points.
    private static let compactOutline: CGFloat = 1.4

    /// Maps a point in a figure's unit square to the frame.
    static func point(_ unit: CGPoint, in frame: NSRect) -> NSPoint {
        NSPoint(x: frame.minX + unit.x * frame.width, y: frame.minY + unit.y * frame.height)
    }

    /// Draws one figure.
    ///
    /// - Parameters:
    ///   - kind: Which spirit.
    ///   - expression: The face to wear.
    ///   - frame: Where to draw it; the figure fills the frame's unit square.
    ///   - detail: Compact for the menu bar, full for everything else.
    ///   - style: The palette; `.inverted` is only meaningful at compact detail.
    static func draw(_ kind: FigureKind, _ expression: FaceExpression, in frame: NSRect,
                     detail: Detail, style: Style = .normal) {
        guard detail == .full, let context = NSGraphicsContext.current?.cgContext else {
            drawLayers(kind, expression, in: frame, detail: detail, style: style)
            return
        }
        // A transparency layer isolates the fade, so erasing the tail never
        // touches whatever is already drawn behind the figure.
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        drawLayers(kind, expression, in: frame, detail: .full, style: style)
        fadeTail(in: frame)
        context.endTransparencyLayer()
    }

    private static func drawLayers(_ kind: FigureKind, _ expression: FaceExpression, in frame: NSRect,
                                   detail: Detail, style: Style) {
        let body = path(GhostGeometry.bodyOutline(kind), in: frame)
        drawOutline(body, frame: frame, detail: detail, style: style)
        drawFill(body, frame: frame, detail: detail, style: style)
        if detail == .full { drawGloss(kind, in: frame) }
        drawEyes(kind, expression, in: frame, detail: detail, style: style)
        drawFeatures(kind, expression, in: frame, detail: detail, style: style)
    }

    // MARK: - Passes

    private static func drawOutline(_ body: NSBezierPath, frame: NSRect, detail: Detail, style: Style) {
        // Strokes are centred on the edge and the fill covers the inner half, so
        // the visible outline is half the stroke width. The reference SVG has a
        // 5-unit outer ring in Midnight Violet around a 2-unit ring of Spirit Ink.
        let visible = detail == .full ? frame.width * 0.032 : compactOutline
        body.lineJoinStyle = .round
        body.lineCapStyle = .round
        NSGraphicsContext.saveGraphicsState()
        if detail == .full {
            let aura = NSShadow()
            aura.shadowColor = Colors.kiroViolet.withAlphaComponent(0.9)
            aura.shadowBlurRadius = frame.width * 0.1
            aura.shadowOffset = .zero
            aura.set()
        }
        (style == .inverted ? Colors.spectralEctoplasm : Colors.midnightViolet).setStroke()
        body.lineWidth = visible * 2
        body.stroke()
        NSGraphicsContext.restoreGraphicsState()
        (style == .inverted ? Colors.kiroViolet : Colors.spiritInk).setStroke()
        body.lineWidth = visible * 0.9
        body.stroke()
    }

    /// Fills the body, then (full detail) adds shading and the rim light, all clipped to the body.
    private static func drawFill(_ body: NSBezierPath, frame: NSRect, detail: Detail, style: Style) {
        NSGraphicsContext.saveGraphicsState()
        body.addClip()
        baseGradient(detail, style)?.draw(in: frame, angle: 270)
        if detail == .full {
            // A soft white light near the top of the head, and a violet bounce at the hem.
            radialGlow(at: CGPoint(x: 0.4, y: 0.76), radius: 0.42, color: .white, alpha: 0.6, in: frame)
            radialGlow(at: CGPoint(x: 0.55, y: 0.08), radius: 0.4, color: Colors.kiroViolet, alpha: 0.3, in: frame)
            drawRim(body, frame: frame)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func baseGradient(_ detail: Detail, _ style: Style) -> NSGradient? {
        let light = Colors.spectralEctoplasm, shade = Colors.ectoplasmShade, violet = Colors.kiroViolet
        if style == .inverted {
            return NSGradient(starting: Colors.midnightViolet, ending: Colors.spiritInk)
        }
        if detail == .compact {
            let deep = shade.blended(withFraction: 0.35, of: violet) ?? shade
            return NSGradient(colors: [light, light, shade, deep], atLocations: [0, 0.5, 0.82, 1], colorSpace: .sRGB)
        }
        // Darker than compact so the rim light and highlights stand out.
        let top = light.blended(withFraction: 0.5, of: shade) ?? shade
        // Keep the hem fairly bright: it is partly erased, and a dark hem would read as dimming.
        let lower = shade.blended(withFraction: 0.15, of: violet) ?? shade
        let hem = shade.blended(withFraction: 0.3, of: violet) ?? shade
        return NSGradient(colors: [top, shade, lower, hem], atLocations: [0, 0.45, 0.8, 1], colorSpace: .sRGB)
    }

    /// A circular glow that fades to nothing at `radius` (a fraction of the frame width).
    private static func radialGlow(at unit: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat, in frame: NSRect) {
        let center = point(unit, in: frame)
        NSGradient(starting: color.withAlphaComponent(alpha), ending: color.withAlphaComponent(0))?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius * frame.width, options: [])
    }

    /// A bright light along the inside of the contour: a white stroke with a
    /// white shadow, clipped to the body so only the inner glow shows.
    private static func drawRim(_ body: NSBezierPath, frame: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor.white.withAlphaComponent(0.95)
        glow.shadowBlurRadius = frame.width * 0.05
        glow.shadowOffset = .zero
        glow.set()
        NSColor.white.withAlphaComponent(0.95).setStroke()
        body.lineWidth = frame.width * 0.014
        body.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// The main flat highlight, then the small round sparkle. Full detail only.
    private static func drawGloss(_ kind: FigureKind, in frame: NSRect) {
        for (index, highlight) in GhostGeometry.highlights(kind).enumerated() {
            NSColor.white.withAlphaComponent(index == 0 ? 0.88 : 1).setFill()
            NSBezierPath(ovalIn: rect(of: highlight, in: frame)).fill()
        }
    }

    private static func drawEyes(_ kind: FigureKind, _ expression: FaceExpression, in frame: NSRect,
                                 detail: Detail, style: Style) {
        for eye in GhostGeometry.eyes(kind, expression) {
            var socket = rect(of: eye, in: frame)
            if detail == .compact {
                // Bigger eyes, so they are visible at menu bar size.
                let scaleY = expression == .sleepy ? compactSleepyEyeScale : compactEyeScale
                socket = socket.insetBy(dx: -socket.width * (compactEyeScale - 1) / 2,
                                        dy: -socket.height * (scaleY - 1) / 2)
            }
            (style == .inverted ? Colors.spectralEctoplasm : Colors.spiritInk).setFill()
            NSBezierPath(ovalIn: socket).fill()
            if detail == .full {
                // A white glint, up and to the left like in the reference.
                let size = min(socket.width, socket.height) * 0.66
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: socket.midX - socket.width * 0.38, y: socket.midY + socket.height * 0.1,
                                            width: size, height: size)).fill()
            }
        }
    }

    private static func drawFeatures(_ kind: FigureKind, _ expression: FaceExpression, in frame: NSRect,
                                     detail: Detail, style: Style) {
        let ink = style == .inverted ? Colors.spectralEctoplasm : Colors.spiritInk
        let lineWidth = detail == .full ? frame.width * 0.022 : 1.4
        for feature in GhostGeometry.features(kind, expression) {
            switch feature {
            case .blush(let center, let radius) where detail == .full:
                Colors.blushPink.withAlphaComponent(0.45).setFill()
                let c = point(center, in: frame), r = radius * frame.width
                NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 1.2)).fill()
            case .smile(let start, let end, let control):
                var s = point(start, in: frame), e = point(end, in: frame)
                let q = point(control, in: frame)
                if detail == .compact {
                    // A longer smile about its middle, so it reads at menu bar size.
                    let mid = NSPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
                    s = NSPoint(x: mid.x + (s.x - mid.x) * compactSmileScale, y: s.y)
                    e = NSPoint(x: mid.x + (e.x - mid.x) * compactSmileScale, y: e.y)
                }
                let path = NSBezierPath()
                path.move(to: s)
                // Quadratic to cubic: control points two thirds of the way to the control.
                path.curve(to: e,
                           controlPoint1: NSPoint(x: s.x + 2 / 3 * (q.x - s.x), y: s.y + 2 / 3 * (q.y - s.y)),
                           controlPoint2: NSPoint(x: e.x + 2 / 3 * (q.x - e.x), y: e.y + 2 / 3 * (q.y - e.y)))
                ink.setStroke()
                path.lineWidth = lineWidth
                path.lineCapStyle = .round
                path.stroke()
            case .ring(let center, let rx, let ry):
                let c = point(center, in: frame)
                let scale = detail == .compact ? compactEyeScale : 1
                ink.setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - rx * scale * frame.width, y: c.y - ry * scale * frame.height,
                                            width: rx * 2 * scale * frame.width, height: ry * 2 * scale * frame.height)).fill()
            default:
                break
            }
        }
    }

    /// Erases the lower body progressively towards the hem, inside a transparency
    /// layer, so the tail (fill, rim, outline and aura) dissolves.
    private static func fadeTail(in frame: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let top = frame.minY + frame.height * 0.5
        let bottom = frame.minY - frame.height * 0.25
        let region = NSRect(x: frame.minX - frame.width * 0.3, y: bottom, width: frame.width * 1.6, height: top - bottom)
        // Alpha here is how much to erase: nothing at the top, most at the hem.
        // The gradient is vertical on purpose: an angled one leaves a visible
        // seam along the top edge of the region.
        let erase = NSGradient(
            colors: [NSColor.black.withAlphaComponent(0), NSColor.black.withAlphaComponent(0.04),
                     NSColor.black.withAlphaComponent(0.5), NSColor.black.withAlphaComponent(0.85)],
            atLocations: [0, 0.3, 0.68, 1], colorSpace: .sRGB)
        erase?.draw(in: region, angle: 270)
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Helpers

    private static func rect(of ellipse: EyeSpec, in frame: NSRect) -> NSRect {
        let r = ellipse.rect
        let origin = point(r.origin, in: frame)
        return NSRect(x: origin.x, y: origin.y, width: r.width * frame.width, height: r.height * frame.height)
    }

    private static func path(_ segments: [PathSegment], in frame: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        for segment in segments {
            switch segment {
            case .move(let p): path.move(to: point(p, in: frame))
            case .line(let p): path.line(to: point(p, in: frame))
            case .curve(let end, let c1, let c2):
                path.curve(to: point(end, in: frame), controlPoint1: point(c1, in: frame), controlPoint2: point(c2, in: frame))
            case .close: path.close()
            }
        }
        return path
    }
}
