import AppKit
import Testing
@testable import GatekeepersWard

/// `GhostIcon` is a full-colour, non-template image that must look the same
/// under light and dark appearances.
@Suite("GhostIcon")
struct GhostIconTests {
    private static let poses: [GhostIcon.Pose] = [.idle, .alert, .alertBlink]
    private static let scale = 8
    private static let side = 22 * scale

    /// An RGBA pixel buffer (premultiplied, sRGB) rendered from the icon.
    private struct Bitmap {
        let bytes: [UInt8]

        func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            let offset = (y * GhostIconTests.side + x) * 4
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]), Int(bytes[offset + 3]))
        }

        /// Counts fully opaque pixels within `tolerance` of the target colour.
        func count(near target: (Int, Int, Int), tolerance: Int = 10) -> Int {
            var total = 0
            for y in 0..<GhostIconTests.side {
                for x in 0..<GhostIconTests.side {
                    let p = pixel(x: x, y: y)
                    if p.a == 255,
                       abs(p.r - target.0) <= tolerance,
                       abs(p.g - target.1) <= tolerance,
                       abs(p.b - target.2) <= tolerance {
                        total += 1
                    }
                }
            }
            return total
        }
    }

    private func render(_ pose: GhostIcon.Pose, appearance: NSAppearance? = nil) -> Bitmap? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Self.side, pixelsHigh: Self.side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: Self.side * 4, bitsPerPixel: 32)?
                .retagging(with: .sRGB),
              let context = NSGraphicsContext(bitmapImageRep: rep),
              let data = rep.bitmapData else { return nil }
        rep.size = NSSize(width: 22, height: 22)
        let draw = {
            let previous = NSGraphicsContext.current
            NSGraphicsContext.current = context
            GhostIcon.image(pose).draw(in: NSRect(x: 0, y: 0, width: 22, height: 22))
            context.flushGraphics()
            NSGraphicsContext.current = previous
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(draw)
        } else {
            draw()
        }
        return Bitmap(bytes: Array(UnsafeBufferPointer(start: data, count: Self.side * Self.side * 4)))
    }

    @Test("Every pose is a non-template image (1.1)", arguments: poses)
    func notTemplate(pose: GhostIcon.Pose) {
        #expect(GhostIcon.image(pose).isTemplate == false)
    }

    @Test("Body gradient and violet outline colours are present (1.2, 1.3)", arguments: poses)
    func bodyAndOutline(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        #expect(bitmap.count(near: (0xD3, 0xDC, 0xFF), tolerance: 12) > 0)
        #expect(bitmap.count(near: (0x8B, 0x5C, 0xF6)) > 0)
    }

    @Test("Eye area is transparent (1.4)", arguments: poses)
    func eyesTransparent(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        // Eye centre in points: x 5.4, y 9.9 (idle) or 10.7 (alert); y is up in the drawing.
        let eyeY = pose == .idle ? 9.9 : 10.7
        for eyeX in [5.4, 8.8] {
            let px = Int((1 + 1.3 * (eyeX - 2)) * Double(Self.scale))
            let py = Int((22 - (1 + 1.3 * (eyeY - 2))) * Double(Self.scale))
            #expect(bitmap.pixel(x: px, y: py).a == 0)
        }
    }

    @Test("Amber lantern appears only in alert poses (1.5, 1.6)", arguments: poses)
    func amberPresence(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        let amber = bitmap.count(near: (0xF5, 0x9E, 0x0B))
        if pose == .idle {
            #expect(amber == 0)
        } else {
            #expect(amber > 0)
        }
    }

    @Test("Pixels are identical under aqua and darkAqua (1.7)", arguments: poses)
    func appearanceIndependent(pose: GhostIcon.Pose) throws {
        let aquaAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))
        let aqua = try #require(render(pose, appearance: aquaAppearance))
        let dark = try #require(render(pose, appearance: darkAppearance))
        #expect(aqua.bytes == dark.bytes)
    }
}
