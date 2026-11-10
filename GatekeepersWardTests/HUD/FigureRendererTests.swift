import AppKit
import Testing
@testable import GatekeepersWard

/// Rendering checks for `FigureRenderer` and `Sparkles`.
@Suite("FigureRenderer")
struct FigureRendererTests {
    private static let side = 240

    /// A transparent RGBA bitmap with the figure drawn at the given detail.
    private func render(_ kind: FigureKind, detail: FigureRenderer.Detail) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Self.side, pixelsHigh: Self.side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        FigureRenderer.draw(kind, .happy, in: NSRect(x: 0, y: 0, width: Self.side, height: Self.side), detail: detail)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Alpha (0–255) at a unit-space point (y up) of the figure.
    private func alpha(_ rep: NSBitmapImageRep, x: Double, y: Double) -> Int {
        let px = Int(x * Double(Self.side)), py = Int((1 - y) * Double(Self.side))
        return Int((rep.colorAt(x: px, y: py)?.alphaComponent ?? 0) * 255)
    }

    @Test("At full detail the tail fades: the lower body is far more transparent than the head (2.9)",
          arguments: [FigureKind.solo, .cloaked])
    func fullDetailTailFades(kind: FigureKind) throws {
        let rep = try #require(render(kind, detail: .full))
        // Sample inside the body in the same column: high (the head) and low (near the hem).
        let head = alpha(rep, x: 0.5, y: 0.62)
        let low = alpha(rep, x: 0.5, y: 0.1)
        #expect(head > 240)
        #expect(low < head - 60)
    }

    @Test("At compact detail the figure stays opaque down to the hem (2.9)", arguments: [FigureKind.solo, .cloaked])
    func compactStaysOpaque(kind: FigureKind) throws {
        let rep = try #require(render(kind, detail: .compact))
        #expect(alpha(rep, x: 0.5, y: 0.62) > 240)
        #expect(alpha(rep, x: 0.5, y: 0.14) > 240)
    }

    @Test("Full detail draws a violet aura outside the body, compact does not (2.3)")
    func auraOnlyAtFullDetail() throws {
        let full = try #require(render(.cloaked, detail: .full))
        let compact = try #require(render(.cloaked, detail: .compact))
        // Just left of the cloak's head, outside the outline: x 0.2 is within the aura at full detail.
        let probeX = 0.2, probeY = 0.62
        #expect(alpha(full, x: probeX, y: probeY) > 0)
        #expect(alpha(compact, x: probeX, y: probeY) == 0)
    }

    @Test("The interior is shaded: the hem is darker than the top of the head at full detail (2.8)")
    func interiorShading() throws {
        let rep = try #require(render(.solo, detail: .full))
        func red(_ x: Double, _ y: Double) -> Double {
            Double(rep.colorAt(x: Int(x * Double(Self.side)), y: Int((1 - y) * Double(Self.side)))?.redComponent ?? 0)
        }
        // Mid-body (lavender) versus the violet-tinted lower body: less red lower down.
        #expect(red(0.45, 0.3) < red(0.45, 0.62))
    }

    @Test("Sparkles are deterministic and star paths have eight points (3.1)")
    func sparkles() {
        #expect(Sparkles.sparks == Sparkles.sparks)
        #expect(Sparkles.wisps == Sparkles.wisps)
        #expect(!Sparkles.sparks.isEmpty && !Sparkles.wisps.isEmpty)
        let star = Sparkles.starPath(center: .zero, radius: 10)
        #expect(star.elementCount >= 8)
        // Long points reach the radius; the star is centred on the origin.
        #expect(abs(star.bounds.width - 20) < 0.001 && abs(star.bounds.height - 20) < 0.001)
        #expect(abs(star.bounds.midX) < 0.001 && abs(star.bounds.midY) < 0.001)
    }
}
