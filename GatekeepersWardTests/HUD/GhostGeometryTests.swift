import CoreGraphics
import Testing
@testable import GatekeepersWard

/// The shared spirit geometry is pure, so it is tested without any renderer.
@Suite("GhostGeometry")
struct GhostGeometryTests {
    private static let kinds: [FigureKind] = [.solo, .cloaked]
    private static let expressions: [FaceExpression] = [.happy, .sleepy, .surprised]

    private static func isMove(_ segment: PathSegment?) -> Bool {
        if case .move = segment { return true }
        return false
    }

    private static func isCurve(_ segment: PathSegment) -> Bool {
        if case .curve = segment { return true }
        return false
    }

    @Test("Outlines start with move, end with close and match the SVG curve counts (2.1, 2.2)", arguments: kinds)
    func outlineShape(kind: FigureKind) {
        let outline = GhostGeometry.bodyOutline(kind)
        #expect(Self.isMove(outline.first))
        #expect(outline.last == .close)
        // solo_spirit.svg has 5 curves; cloaked_spirit.svg has 11.
        #expect(outline.filter(Self.isCurve).count == (kind == .solo ? 5 : 11))
    }

    @Test("Every point, control points included, lies in the unit square (2.5)", arguments: kinds)
    func insideUnitSquare(kind: FigureKind) {
        for point in GhostGeometry.points(of: GhostGeometry.bodyOutline(kind)) {
            #expect(point.x >= 0 && point.x <= 1)
            #expect(point.y >= 0 && point.y <= 1)
        }
    }

    @Test("Each figure is centred and leaves a margin for the outline (2.5)", arguments: kinds)
    func centredWithMargin(kind: FigureKind) {
        let points = GhostGeometry.points(of: GhostGeometry.bodyOutline(kind))
        let xs = points.map(\.x), ys = points.map(\.y)
        #expect(abs(((xs.min() ?? 0) + (xs.max() ?? 1)) / 2 - 0.5) < 0.01)
        #expect(abs(((ys.min() ?? 0) + (ys.max() ?? 1)) / 2 - 0.5) < 0.01)
        #expect((ys.min() ?? 0) >= 0.05 && (ys.max() ?? 1) <= 0.95)
    }

    @Test("The cloak is widened: the hem is wider than the head (2.2)")
    func cloakIsWide() {
        let points = GhostGeometry.points(of: GhostGeometry.bodyOutline(.cloaked))
        func width(where include: (CGPoint) -> Bool) -> CGFloat {
            let xs = points.filter(include).map(\.x)
            return (xs.max() ?? 0) - (xs.min() ?? 0)
        }
        // Unit y is up: the hem is low (y < 0.2), the head is high (y > 0.6).
        #expect(width { $0.y < 0.2 } > width { $0.y > 0.6 })
    }

    @Test("The cloak sweeps right: the hem sits right of the head, the face does not move (2.7)")
    func cloakLeansRight() {
        let points = GhostGeometry.points(of: GhostGeometry.bodyOutline(.cloaked))
        func meanX(where include: (CGPoint) -> Bool) -> CGFloat {
            let xs = points.filter(include).map(\.x)
            return xs.reduce(0, +) / CGFloat(max(xs.count, 1))
        }
        // Unit y is up: the hem is low (y < 0.2), the head is high (y > 0.6).
        #expect(meanX { $0.y < 0.2 } > meanX { $0.y > 0.6 } + 0.03)
        // The eyes stay level and centred on the head, as in the SVG.
        let eyes = GhostGeometry.eyes(.cloaked, .happy)
        #expect(eyes[0].center.y == eyes[1].center.y)
    }

    @Test("The solo spirit keeps its SVG shape: its curve count and tail reach are unchanged (2.7)")
    func soloUnchanged() {
        let outline = GhostGeometry.bodyOutline(.solo)
        #expect(outline.filter(Self.isCurve).count == 5)
        // The tail tip (SVG 140, 132) is the right-most end point, low in the figure.
        let points = GhostGeometry.points(of: outline)
        let rightmost = points.max { $0.x < $1.x }
        #expect((rightmost?.y ?? 1) < 0.5)
    }

    @Test("The right end of the cloak's hem curls up (2.7)")
    func hemCurls() {
        let points = GhostGeometry.points(of: GhostGeometry.bodyOutline(.cloaked))
        // The lowest point of each half of the hem: the right side is lifted.
        let leftLowest = points.filter { $0.x < 0.5 }.map(\.y).min() ?? 1
        let rightLowest = points.filter { $0.x > 0.5 }.map(\.y).min() ?? 0
        #expect(rightLowest > leftLowest + 0.01)
    }

    @Test("Eyes sit inside the figure and left comes before right (2.1, 2.2)", arguments: kinds, expressions)
    func eyesInsideBody(kind: FigureKind, expression: FaceExpression) {
        let points = GhostGeometry.points(of: GhostGeometry.bodyOutline(kind))
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let maxY = points.map(\.y).max() ?? 1
        let eyes = GhostGeometry.eyes(kind, expression)
        #expect(eyes.count == 2)
        #expect(eyes[0].center.x < eyes[1].center.x)
        for eye in eyes {
            #expect(eye.rect.minX > minX && eye.rect.maxX < maxX)
            #expect(eye.rect.minY > 0.2 && eye.rect.maxY < maxY)
        }
    }

    @Test("Expressions give different eye heights (2.4)", arguments: kinds)
    func expressionsDiffer(kind: FigureKind) {
        let sleepy = GhostGeometry.eyes(kind, .sleepy)[0].radiusY
        let happy = GhostGeometry.eyes(kind, .happy)[0].radiusY
        let surprised = GhostGeometry.eyes(kind, .surprised)[0].radiusY
        #expect(sleepy < happy)
        #expect(happy < surprised)
    }

    @Test("Faces have two cheeks and a mouth that follows the expression (2.1, 2.2, 2.4)", arguments: kinds)
    func features(kind: FigureKind) {
        func count(_ features: [FeatureSpec], _ test: (FeatureSpec) -> Bool) -> Int { features.filter(test).count }
        for expression in Self.expressions {
            let features = GhostGeometry.features(kind, expression)
            #expect(count(features) { if case .blush = $0 { true } else { false } } == 2)
            let smiles = count(features) { if case .smile = $0 { true } else { false } }
            let rings = count(features) { if case .ring = $0 { true } else { false } }
            #expect(smiles == (expression == .surprised ? 0 : 1))
            #expect(rings == (expression == .surprised ? 1 : 0))
        }
    }

    @Test("Each figure has a main gloss highlight above the eyes and a small sparkle (2.2, 2.8)", arguments: kinds)
    func highlights(kind: FigureKind) {
        let highlights = GhostGeometry.highlights(kind)
        #expect(highlights.count == 2)
        let eyeY = GhostGeometry.eyes(kind, .happy).first?.center.y ?? 1
        for highlight in highlights { #expect(highlight.center.y > eyeY) }
        // The main highlight is a flat ellipse; the sparkle is round and smaller.
        #expect(highlights[0].radiusX > highlights[0].radiusY)
        #expect(highlights[1].radiusX == highlights[1].radiusY)
        #expect(highlights[1].radiusX < highlights[0].radiusX)
    }

    @Test("Geometry is deterministic (2.5)", arguments: kinds, expressions)
    func deterministic(kind: FigureKind, expression: FaceExpression) {
        #expect(GhostGeometry.bodyOutline(kind) == GhostGeometry.bodyOutline(kind))
        #expect(GhostGeometry.eyes(kind, expression) == GhostGeometry.eyes(kind, expression))
        #expect(GhostGeometry.features(kind, expression) == GhostGeometry.features(kind, expression))
    }
}
