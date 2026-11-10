import AppKit
import Testing
@testable import GatekeepersWard

/// `GhostIcon` is a full-colour, non-template ghost-and-spirit image that must
/// look the same under light and dark appearances.
@Suite("GhostIcon")
struct GhostIconTests {
    private static let poses: [GhostIcon.Pose] = [.idle, .alert, .alertBlink]
    private static let scale = 8
    private static let width = 24 * scale
    private static let height = 22 * scale

    /// An RGBA pixel buffer (premultiplied, sRGB) rendered from the icon.
    private struct Bitmap {
        let bytes: [UInt8]

        func pixel(x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
            let offset = (y * GhostIconTests.width + x) * 4
            return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]), Int(bytes[offset + 3]))
        }

        /// Counts fully opaque pixels within `tolerance` of the target colour,
        /// optionally limited to the pixel columns `columns`.
        func count(near target: (Int, Int, Int), tolerance: Int = 10, columns: Range<Int>? = nil) -> Int {
            var total = 0
            for y in 0..<GhostIconTests.height {
                for x in columns ?? 0..<GhostIconTests.width {
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
            bitmapDataPlanes: nil, pixelsWide: Self.width, pixelsHigh: Self.height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: Self.width * 4, bitsPerPixel: 32)?
                .retagging(with: .sRGB),
              let context = NSGraphicsContext(bitmapImageRep: rep),
              let data = rep.bitmapData else { return nil }
        rep.size = GhostIcon.canvas
        let draw = {
            let previous = NSGraphicsContext.current
            NSGraphicsContext.current = context
            // The bitmap context maps one unit to one pixel, so draw at the full pixel size.
            GhostIcon.image(pose).draw(in: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
            context.flushGraphics()
            NSGraphicsContext.current = previous
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(draw)
        } else {
            draw()
        }
        return Bitmap(bytes: Array(UnsafeBufferPointer(start: data, count: Self.width * Self.height * 4)))
    }

    @Test("The icon is about 24 by 22 pt and within the 40 pt limit (5.2)")
    func size() {
        let size = GhostIcon.image(.idle).size
        #expect(size.width == 24 && size.height == 22)
        #expect(size.width <= 40)
    }

    @Test("Every pose is a non-template image (5.3)", arguments: poses)
    func notTemplate(pose: GhostIcon.Pose) {
        #expect(GhostIcon.image(pose).isTemplate == false)
    }

    @Test("Normal frames have a light body and a Midnight Violet outline (5.3)", arguments: [GhostIcon.Pose.idle, .alert])
    func bodyAndOutline(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        #expect(bitmap.count(near: (0xD3, 0xDC, 0xFF), tolerance: 12) > 0)
        #expect(bitmap.count(near: (0x3B, 0x18, 0x5F), tolerance: 12) > 0)
    }

    @Test("The inverted alert frame has a dark body and a light outline (5.10)")
    func invertedFrame() throws {
        let bitmap = try #require(render(.alertBlink))
        #expect(bitmap.count(near: (0x35, 0x14, 0x5F), tolerance: 14) > 0)
        #expect(bitmap.count(near: (0xE0, 0xE7, 0xFF), tolerance: 12) > 0)
        // No light body: the light colour only appears as outline and features.
        let normal = try #require(render(.alert))
        #expect(bitmap.count(near: (0xD3, 0xDC, 0xFF), tolerance: 12) < normal.count(near: (0xD3, 0xDC, 0xFF), tolerance: 12) / 4)
    }

    @Test("The two alert frames swap light and dark bodies, so the icon pulses (5.10)")
    func alertPulses() throws {
        let normal = try #require(render(.alert))
        let inverted = try #require(render(.alertBlink))
        // A point inside each body, away from the eyes and the mouth.
        let probes: [(NSRect, CGPoint)] = [(GhostIcon.soloFrame, CGPoint(x: 0.4, y: 0.3)),
                                           (GhostIcon.cloakedFrame, CGPoint(x: 0.55, y: 0.33))]
        for (frame, unit) in probes {
            let point = GhostIcon.canvasPoint(unit, in: frame)
            let px = Int(point.x * Double(Self.scale)), py = Int((22 - point.y) * Double(Self.scale))
            let light = normal.pixel(x: px, y: py), dark = inverted.pixel(x: px, y: py)
            #expect(light.a == 255 && dark.a == 255)
            #expect(light.r + light.g + light.b > 600)   // light body in the normal frame
            #expect(dark.r + dark.g + dark.b < 300)      // dark body in the inverted frame
        }
    }

    @Test("Both figures are drawn: the left and right halves each contain body pixels (5.1)", arguments: poses)
    func bothFiguresPresent(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        let body = pose == .alertBlink ? (0x35, 0x14, 0x5F) : (0xD3, 0xDC, 0xFF)
        // The solo spirit occupies the left ~10 pt; the cloaked spirit's body lies beyond 15 pt.
        #expect(bitmap.count(near: body, tolerance: 14, columns: 0..<(10 * Self.scale)) > 0)
        #expect(bitmap.count(near: body, tolerance: 14, columns: (15 * Self.scale)..<Self.width) > 0)
    }

    @Test("Eyes are drawn opaque and contrast with the body, so they show on light and dark bars (5.5, 5.6, 5.7)",
          arguments: poses)
    func eyesContrast(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        let figures: [(FigureKind, NSRect)] = [(.solo, GhostIcon.soloFrame), (.cloaked, GhostIcon.cloakedFrame)]
        for (kind, frame) in figures {
            for eye in GhostGeometry.eyes(kind, pose.expression) {
                let point = GhostIcon.canvasPoint(eye.center, in: frame)
                let px = Int(point.x * Double(Self.scale))
                // The drawing has y up; the pixel buffer has y down.
                let py = Int((22 - point.y) * Double(Self.scale))
                let pixel = bitmap.pixel(x: px, y: py)
                #expect(pixel.a == 255)
                if pose == .alertBlink {
                    #expect(pixel.r > 0xC0)   // light eyes on the dark body
                } else {
                    #expect(pixel.r < 0x90)   // dark eyes on the light body
                }
            }
        }
    }

    @Test("Eyes are large enough to see: at least 2.5 pt wide in the alert pose (9.1)")
    func eyesAreLarge() throws {
        let bitmap = try #require(render(.alert))
        let eye = try #require(GhostGeometry.eyes(.solo, .surprised).first)
        let point = GhostIcon.canvasPoint(eye.center, in: GhostIcon.soloFrame)
        let py = Int((22 - point.y) * Double(Self.scale))
        var left = Int(point.x * Double(Self.scale)), right = left
        func isDark(_ x: Int) -> Bool {
            let p = bitmap.pixel(x: x, y: py)
            return p.a == 255 && p.r < 0x90
        }
        while left > 0, isDark(left - 1) { left -= 1 }
        while right < Self.width - 1, isDark(right + 1) { right += 1 }
        #expect(Double(right - left + 1) / Double(Self.scale) >= 2.5)
    }

    @Test("Alert poses open the eyes wider than idle (5.5, 5.6)")
    func alertEyesWider() {
        for kind in [FigureKind.solo, .cloaked] {
            let idle = GhostGeometry.eyes(kind, GhostIcon.Pose.idle.expression)[0].radiusY
            let alert = GhostGeometry.eyes(kind, GhostIcon.Pose.alert.expression)[0].radiusY
            #expect(alert > idle)
        }
    }

    @Test("Amber lantern appears only in alert poses (5.5, 5.6)", arguments: poses)
    func amberPresence(pose: GhostIcon.Pose) throws {
        let bitmap = try #require(render(pose))
        let amber = bitmap.count(near: (0xF5, 0x9E, 0x0B))
        if pose == .idle {
            #expect(amber == 0)
        } else {
            #expect(amber > 0)
        }
    }

    @Test("Pixels are identical under aqua and darkAqua (5.3)", arguments: poses)
    func appearanceIndependent(pose: GhostIcon.Pose) throws {
        let aquaAppearance = try #require(NSAppearance(named: .aqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))
        let aqua = try #require(render(pose, appearance: aquaAppearance))
        let dark = try #require(render(pose, appearance: darkAppearance))
        #expect(aqua.bytes == dark.bytes)
    }
}
