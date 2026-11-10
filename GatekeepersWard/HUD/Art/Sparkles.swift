import AppKit

/// Four-point sparkles and faint wisps that float around the spirits.
///
/// Positions are fixed fractions of the frame they are drawn in, so the result
/// is deterministic (stable for tests and snapshots) and scales with the frame.
/// The Gate_Banner and the review images use it; the menu bar icon does not.
enum Sparkles {
    /// The colour family of a sparkle, from the Castle Keep palette.
    enum Tone {
        /// Spectral white.
        case white
        /// Kiro Violet.
        case violet
        /// Torchlight Amber.
        case amber
    }

    /// One four-point star, in fractions of the frame.
    struct Spark: Equatable {
        /// Horizontal centre, 0 at the left of the frame.
        let x: CGFloat
        /// Vertical centre, 0 at the bottom of the frame.
        let y: CGFloat
        /// Outer radius as a fraction of the frame width.
        let size: CGFloat
        /// The sparkle's colour family.
        let tone: Tone
    }

    /// One tapered, curved strand, in fractions of the frame.
    struct Wisp: Equatable {
        /// Where the strand starts (the thick end).
        let start: CGPoint
        /// A point the strand bends towards.
        let control: CGPoint
        /// Where the strand fades out (the thin end).
        let end: CGPoint
        /// Thickness at the start, as a fraction of the frame width.
        let width: CGFloat
    }

    /// The sparkle layout.
    static let sparks: [Spark] = [
        Spark(x: 0.04, y: 0.86, size: 0.045, tone: .white),
        Spark(x: 0.96, y: 0.74, size: 0.06, tone: .violet),
        Spark(x: -0.02, y: 0.38, size: 0.035, tone: .violet),
        Spark(x: 1.04, y: 0.4, size: 0.04, tone: .white),
        Spark(x: 0.5, y: 1.0, size: 0.03, tone: .amber),
        Spark(x: 0.9, y: 0.12, size: 0.032, tone: .white),
    ]

    /// Sparkles for the Gate_Banner, in fractions of the banner (y up). The
    /// size is a fraction of the banner width.
    static let bannerSparks: [Spark] = [
        Spark(x: 0.11, y: 0.82, size: 0.018, tone: .white),
        Spark(x: 0.27, y: 0.32, size: 0.014, tone: .violet),
        Spark(x: 0.60, y: 0.8, size: 0.016, tone: .white),
        Spark(x: 0.76, y: 0.26, size: 0.015, tone: .violet),
        Spark(x: 0.9, y: 0.7, size: 0.02, tone: .white),
        Spark(x: 0.47, y: 0.93, size: 0.012, tone: .amber),
        Spark(x: 0.05, y: 0.3, size: 0.012, tone: .violet),
        Spark(x: 0.69, y: 0.58, size: 0.011, tone: .amber),
    ]

    /// The wisp layout: strands trailing off the hem.
    static let wisps: [Wisp] = [
        Wisp(start: CGPoint(x: 0.74, y: 0.14), control: CGPoint(x: 1.0, y: 0.05), end: CGPoint(x: 1.12, y: 0.2), width: 0.03),
        Wisp(start: CGPoint(x: 0.3, y: 0.12), control: CGPoint(x: 0.1, y: 0.0), end: CGPoint(x: -0.1, y: 0.1), width: 0.025),
    ]

    private static func color(_ tone: Tone) -> NSColor {
        switch tone {
        case .white: return CastleNSColors.spectralEctoplasm
        case .violet: return CastleNSColors.kiroViolet
        case .amber: return CastleNSColors.torchlightAmber
        }
    }

    /// The vertices of a four-point star: long points up, down, left and right.
    static func starPath(center: NSPoint, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let inner = radius * 0.3
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let length = index.isMultiple(of: 2) ? radius : inner
            let point = NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            if index == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        path.close()
        return path
    }

    /// Draws the sparkles around the frame.
    static func drawSparks(in frame: NSRect) {
        for spark in sparks {
            let center = NSPoint(x: frame.minX + spark.x * frame.width, y: frame.minY + spark.y * frame.height)
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = color(spark.tone).withAlphaComponent(0.9)
            glow.shadowBlurRadius = spark.size * frame.width * 0.8
            glow.shadowOffset = .zero
            glow.set()
            color(spark.tone).withAlphaComponent(spark.tone == .violet ? 0.9 : 1).setFill()
            starPath(center: center, radius: spark.size * frame.width).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// Draws the faint wisps trailing from the frame.
    static func drawWisps(in frame: NSRect) {
        for wisp in wisps {
            let start = NSPoint(x: frame.minX + wisp.start.x * frame.width, y: frame.minY + wisp.start.y * frame.height)
            let control = NSPoint(x: frame.minX + wisp.control.x * frame.width, y: frame.minY + wisp.control.y * frame.height)
            let end = NSPoint(x: frame.minX + wisp.end.x * frame.width, y: frame.minY + wisp.end.y * frame.height)
            let thickness = wisp.width * frame.width
            // A lens between two curves that meet at the thin end.
            let path = NSBezierPath()
            path.move(to: start)
            path.curve(to: end,
                       controlPoint1: NSPoint(x: control.x, y: control.y + thickness),
                       controlPoint2: NSPoint(x: control.x, y: control.y + thickness * 0.4))
            path.curve(to: start,
                       controlPoint1: NSPoint(x: control.x, y: control.y - thickness * 0.4),
                       controlPoint2: NSPoint(x: control.x, y: control.y - thickness))
            path.close()
            // Pale lavender, so the strand reads as a continuation of the ghost's tail.
            CastleNSColors.ectoplasmShade.withAlphaComponent(0.3).setFill()
            path.fill()
        }
    }
}
