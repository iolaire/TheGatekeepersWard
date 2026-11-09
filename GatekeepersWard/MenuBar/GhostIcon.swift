import AppKit

/// Draws the menu bar ghost as a 22×22 pt full-colour image in the Castle Keep
/// palette. It is not a template image, so it uses only fixed sRGB colours and
/// looks the same on light and dark menu bars. SF Symbols has no ghost, and
/// SwiftPM cannot bundle an asset catalog, so it is drawn in code.
enum GhostIcon {
    // Fixed sRGB values matching `CastlePalette` (which exposes SwiftUI colours only).
    private static let ectoplasmLight = srgb(0xE0, 0xE7, 0xFF)
    private static let ectoplasmDark = srgb(0xC7, 0xD2, 0xFE)
    private static let kiroViolet = srgb(0x8B, 0x5C, 0xF6)
    private static let torchlightAmber = srgb(0xF5, 0x9E, 0x0B)

    private static func srgb(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }

    /// Side length of the rendered image in points (menu bar is ~22–24 pt tall).
    private static let canvas: CGFloat = 22
    /// Scale applied to the 18 pt-grid artwork.
    private static let scale: CGFloat = 1.3

    /// The ghost's pose.
    enum Pose {
        /// Half-closed eyes.
        case idle
        /// Wide eyes, lantern raised.
        case alert
        /// Wide eyes, lantern lowered (second alert frame).
        case alertBlink
    }

    /// Renders the ghost.
    static func image(_ pose: Pose) -> NSImage {
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { _ in
            // Artwork is authored in an 18 pt grid with 2 pt of padding; scale it up
            // so the ghost fills the menu bar height.
            let transform = NSAffineTransform()
            transform.translateX(by: 1, yBy: 1)
            transform.scale(by: scale)
            transform.translateX(by: -2, yBy: -2)
            transform.concat()
            let body = body()
            NSGradient(starting: ectoplasmLight, ending: ectoplasmDark)?.draw(in: body, angle: 270)
            kiroViolet.setStroke()
            body.lineWidth = 1
            body.stroke()
            // Cut the eyes out of the body so the menu bar shows through.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.black.setFill()
            eyes(pose).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            if pose != .idle {
                torchlightAmber.setFill()
                lantern(raised: pose == .alert).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Dome head, straight sides, three scalloped tails.
    private static func body() -> NSBezierPath {
        let path = NSBezierPath()
        let left: CGFloat = 2, right: CGFloat = 12, bottom: CGFloat = 2, shoulder: CGFloat = 10
        path.move(to: NSPoint(x: left, y: bottom))
        path.line(to: NSPoint(x: left, y: shoulder))
        path.appendArc(withCenter: NSPoint(x: (left + right) / 2, y: shoulder), radius: (right - left) / 2,
                       startAngle: 180, endAngle: 0, clockwise: true)
        path.line(to: NSPoint(x: right, y: bottom))
        let scallop = (right - left) / 3
        for index in 0..<3 {
            let x = right - CGFloat(index) * scallop
            path.curve(to: NSPoint(x: x - scallop, y: bottom),
                       controlPoint1: NSPoint(x: x - scallop * 0.25, y: bottom + 2.2),
                       controlPoint2: NSPoint(x: x - scallop * 0.75, y: bottom + 2.2))
        }
        path.close()
        return path
    }

    private static func eyes(_ pose: Pose) -> NSBezierPath {
        let height: CGFloat = pose == .idle ? 1.0 : 2.6
        let path = NSBezierPath()
        for x in [CGFloat(4.6), 8.0] {
            path.appendOval(in: NSRect(x: x, y: 9.4, width: 1.6, height: height))
        }
        return path
    }

    /// A small lantern held out to the right.
    private static func lantern(raised: Bool) -> NSBezierPath {
        let y: CGFloat = raised ? 9 : 6
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 12, y: y + 1))
        path.line(to: NSPoint(x: 14.5, y: y + 1))
        path.lineWidth = 1
        path.appendRect(NSRect(x: 13.6, y: y - 3, width: 2.6, height: 3.4))
        path.appendRect(NSRect(x: 14.3, y: y + 0.4, width: 1.2, height: 0.9))
        return path
    }
}
