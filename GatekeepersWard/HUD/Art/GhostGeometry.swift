import CoreGraphics
import Foundation

/// Which character to draw.
enum FigureKind: Equatable, Sendable {
    /// The smaller spirit with a swooping tail (`docs/Planning/Styles/solo_spirit.svg`).
    case solo
    /// The larger cloaked spirit (`docs/Planning/Styles/cloaked_spirit.svg`).
    case cloaked
}

/// How a figure's face looks.
enum FaceExpression: Equatable, Sendable {
    /// Round eyes and a smile.
    case happy
    /// Half-closed eyes.
    case sleepy
    /// Wide eyes and a round mouth.
    case surprised
}

/// One drawing step of a figure outline. Renderers replay these into their
/// own path type.
enum PathSegment: Equatable, Sendable {
    /// Starts a new sub-path.
    case move(CGPoint)
    /// Straight line to a point.
    case line(CGPoint)
    /// Cubic Bézier curve.
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    /// Closes the sub-path.
    case close
}

/// An ellipse in unit space, used for eyes and gloss highlights.
struct EyeSpec: Equatable, Sendable {
    /// Centre of the ellipse.
    let center: CGPoint
    /// Horizontal radius.
    let radiusX: CGFloat
    /// Vertical radius.
    let radiusY: CGFloat

    /// The bounding rectangle of the ellipse.
    var rect: CGRect {
        CGRect(x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2)
    }
}

/// A face detail other than the eyes, in unit space.
enum FeatureSpec: Equatable, Sendable {
    /// A round cheek blush.
    case blush(center: CGPoint, radius: CGFloat)
    /// A smile drawn as a quadratic curve.
    case smile(start: CGPoint, end: CGPoint, control: CGPoint)
    /// An "o" mouth.
    case ring(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat)
}

/// Pure figure geometry in a unit square (origin bottom-left, y up).
///
/// The shapes are ported from the reference SVGs, whose coordinates are used
/// as written (y down) and then mapped into the unit square, so the paths
/// below can be compared with the SVG files line by line. Each figure is fitted
/// into the unit square with a small margin for the outline. No UI framework is
/// imported so the geometry can be tested directly.
enum GhostGeometry {
    /// How much wider the cloaked spirit's lower body is than in
    /// `cloaked_spirit.svg` (hem and flare, ramping in from the waist).
    static let cloakWidening: CGFloat = 0.22
    /// How far, in SVG units, the cloaked spirit's hem sweeps to the right of
    /// the head's centre line. The shift eases in from the neck, so the head is untouched.
    static let cloakSweep: CGFloat = 14
    /// How far, in SVG units, the right end of the cloaked spirit's hem lifts.
    static let cloakCurl: CGFloat = 8

    // MARK: - SVG space

    /// Maps SVG coordinates (y down) into the unit square (y up).
    private struct SVGSpace {
        let center: CGPoint
        /// Side of the square window in SVG units.
        let side: CGFloat

        func unit(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: 0.5 + (x - center.x) / side, y: 0.5 - (y - center.y) / side)
        }

        func length(_ value: CGFloat) -> CGFloat { value / side }
    }

    /// Fraction of the window left empty around the figure, for the outline.
    private static let margin: CGFloat = 0.06

    /// The window that centres each figure's body with a margin for the outline.
    private static func space(_ kind: FigureKind) -> SVGSpace {
        var xs: [CGFloat] = [], ys: [CGFloat] = []
        for command in outlineCommands(kind) {
            switch command {
            case .move(let x, let y): xs.append(x); ys.append(y)
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                xs.append(contentsOf: [x1, x2, x]); ys.append(contentsOf: [y1, y2, y])
            case .close: break
            }
        }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1, minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        return SVGSpace(center: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
                        side: max(maxX - minX, maxY - minY) / (1 - 2 * margin))
    }

    /// One SVG path command, in SVG coordinates.
    private enum SVGCommand {
        case move(CGFloat, CGFloat)
        case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
        case close
    }

    private static func clamp01(_ value: CGFloat) -> CGFloat { min(max(value, 0), 1) }

    /// Applies `transform` to every point of a path.
    private static func mapped(_ commands: [SVGCommand], _ transform: (CGFloat, CGFloat) -> CGPoint) -> [SVGCommand] {
        commands.map { command in
            switch command {
            case .move(let x, let y):
                let p = transform(x, y)
                return .move(p.x, p.y)
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                let c1 = transform(x1, y1), c2 = transform(x2, y2), end = transform(x, y)
                return .curve(c1.x, c1.y, c2.x, c2.y, end.x, end.y)
            case .close: return .close
            }
        }
    }

    // MARK: - Outlines

    /// The body path in SVG coordinates, after the cloaked spirit's changes.
    private static func outlineCommands(_ kind: FigureKind) -> [SVGCommand] {
        switch kind {
        case .solo:
            return soloPath
        case .cloaked:
            return mapped(cloakedPath) { x, y in
                // 1. Widen the lower body about the centre line, ramping from 1 at
                //    y 120 (just below the head) to 1 + widening at y 165.
                let widen = 1 + cloakWidening * clamp01((y - 120) / 45)
                var newX = 100 + (x - 100) * widen
                // 2. Sweep the lower body right, easing in from the neck (y 110) to the hem.
                let lower = clamp01((y - 110) / 100)
                newX += cloakSweep * pow(lower, 1.6)
                // 3. Lift the right end of the hem into a small curl.
                let newY = y - cloakCurl * clamp01((newX - 125) / 40) * lower
                return CGPoint(x: newX, y: newY)
            }
        }
    }

    /// The closed body outline in unit space. The first segment is `.move` and
    /// the last is `.close`.
    static func bodyOutline(_ kind: FigureKind) -> [PathSegment] {
        let space = space(kind)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { space.unit(x, y) }
        return outlineCommands(kind).map { command in
            switch command {
            case .move(let x, let y): return .move(point(x, y))
            case .curve(let x1, let y1, let x2, let y2, let x, let y):
                return .curve(to: point(x, y), control1: point(x1, y1), control2: point(x2, y2))
            case .close: return .close
            }
        }
    }

    /// `solo_spirit.svg`, "Body" path. Unchanged.
    private static let soloPath: [SVGCommand] = [
        .move(80, 25),
        .curve(45, 25, 32, 55, 35, 92),
        .curve(37, 122, 50, 152, 78, 156),
        .curve(106, 160, 130, 144, 140, 132),
        .curve(126, 118, 116, 95, 117, 65),
        .curve(117, 42, 102, 25, 80, 25),
        .close,
    ]

    /// `cloaked_spirit.svg`, "Cloaked Spirit Body" path, before widening and
    /// sweeping. The drape folds and centre crease of the SVG are intentionally left out.
    private static let cloakedPath: [SVGCommand] = [
        .move(100, 28),
        .curve(62, 28, 53, 52, 55, 82),
        .curve(56, 103, 64, 117, 70, 131),
        .curve(72, 136, 72, 142, 69, 150),
        .curve(63, 166, 58, 184, 60, 204),
        .curve(70, 209, 82, 203, 91, 200),
        .curve(97, 198, 103, 198, 109, 200),
        .curve(118, 203, 130, 209, 140, 204),
        .curve(142, 184, 137, 166, 131, 150),
        .curve(128, 142, 128, 136, 130, 131),
        .curve(136, 117, 144, 103, 145, 82),
        .curve(147, 52, 138, 28, 100, 28),
        .close,
    ]

    // MARK: - Face

    /// A figure's face in SVG coordinates.
    private struct Face {
        let eyes: [CGPoint]
        let eyeRadius: CGFloat
        let smileStart: CGPoint
        let smileControl: CGPoint
        let smileEnd: CGPoint
        let blush: [CGPoint]
        let blushRadius: CGFloat
        let highlight: CGPoint
        let highlightRadius: CGSize
        /// Centre of the small round sparkle highlight.
        let sparkle: CGPoint
        let sparkleRadius: CGFloat
    }

    private static func face(_ kind: FigureKind) -> Face {
        switch kind {
        case .solo:
            return Face(eyes: [CGPoint(x: 62, y: 78), CGPoint(x: 98, y: 78)], eyeRadius: 7.5,
                        smileStart: CGPoint(x: 74, y: 90), smileControl: CGPoint(x: 80, y: 98),
                        smileEnd: CGPoint(x: 86, y: 90),
                        blush: [CGPoint(x: 50, y: 86), CGPoint(x: 110, y: 86)], blushRadius: 5,
                        highlight: CGPoint(x: 68, y: 42), highlightRadius: CGSize(width: 20, height: 9),
                        sparkle: CGPoint(x: 96, y: 49), sparkleRadius: 3.2)
        case .cloaked:
            return Face(eyes: [CGPoint(x: 82, y: 80), CGPoint(x: 118, y: 80)], eyeRadius: 7.5,
                        smileStart: CGPoint(x: 94, y: 92), smileControl: CGPoint(x: 100, y: 99),
                        smileEnd: CGPoint(x: 106, y: 92),
                        blush: [CGPoint(x: 70, y: 88), CGPoint(x: 130, y: 88)], blushRadius: 5.5,
                        highlight: CGPoint(x: 88, y: 46), highlightRadius: CGSize(width: 22, height: 10),
                        sparkle: CGPoint(x: 120, y: 53), sparkleRadius: 3.4)
        }
    }

    /// The two eyes for a kind and expression, left eye first.
    static func eyes(_ kind: FigureKind, _ expression: FaceExpression) -> [EyeSpec] {
        let space = space(kind), face = face(kind)
        let radius = space.length(face.eyeRadius)
        let size: (x: CGFloat, y: CGFloat)
        switch expression {
        case .happy: size = (radius, radius)
        case .sleepy: size = (radius * 1.05, radius * 0.3)
        case .surprised: size = (radius * 1.2, radius * 1.2)
        }
        return face.eyes.map { EyeSpec(center: space.unit($0.x, $0.y), radiusX: size.x, radiusY: size.y) }
    }

    /// The gloss highlights: a flat main ellipse on the head first, then a
    /// small round sparkle.
    static func highlights(_ kind: FigureKind) -> [EyeSpec] {
        let space = space(kind), face = face(kind)
        return [
            EyeSpec(center: space.unit(face.highlight.x, face.highlight.y),
                    radiusX: space.length(face.highlightRadius.width),
                    radiusY: space.length(face.highlightRadius.height)),
            EyeSpec(center: space.unit(face.sparkle.x, face.sparkle.y),
                    radiusX: space.length(face.sparkleRadius), radiusY: space.length(face.sparkleRadius)),
        ]
    }

    /// Cheek blush and the mouth for a kind and expression.
    static func features(_ kind: FigureKind, _ expression: FaceExpression) -> [FeatureSpec] {
        let space = space(kind), face = face(kind)
        var details: [FeatureSpec] = face.blush.map {
            .blush(center: space.unit($0.x, $0.y), radius: space.length(face.blushRadius))
        }
        let start = space.unit(face.smileStart.x, face.smileStart.y)
        let end = space.unit(face.smileEnd.x, face.smileEnd.y)
        let control = space.unit(face.smileControl.x, face.smileControl.y)
        switch expression {
        case .happy:
            details.append(.smile(start: start, end: end, control: control))
        case .sleepy:
            // Flatten the smile towards a straight line.
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let flat = CGPoint(x: control.x, y: mid.y + (control.y - mid.y) * 0.35)
            details.append(.smile(start: start, end: end, control: flat))
        case .surprised:
            let center = CGPoint(x: control.x, y: start.y - space.length(2))
            details.append(.ring(center: center, radiusX: space.length(3.4), radiusY: space.length(4.4)))
        }
        return details
    }

    // MARK: - Helpers

    /// Every point of an outline, including control points.
    static func points(of segments: [PathSegment]) -> [CGPoint] {
        segments.flatMap { segment -> [CGPoint] in
            switch segment {
            case .move(let point), .line(let point): return [point]
            case .curve(let end, let c1, let c2): return [end, c1, c2]
            case .close: return []
            }
        }
    }
}
