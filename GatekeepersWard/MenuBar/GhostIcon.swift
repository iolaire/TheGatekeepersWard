import AppKit

/// Draws the menu bar ghost as an 18×18 pt template image, so macOS tints it
/// for light and dark menu bars. SF Symbols has no ghost, and SwiftPM cannot
/// bundle an asset catalog, so it is drawn in code.
enum GhostIcon {
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
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            body().fill()
            // Cut the eyes out of the body so the menu bar shows through.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            eyes(pose).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            if pose != .idle {
                lantern(raised: pose == .alert).fill()
            }
            return true
        }
        image.isTemplate = true
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
