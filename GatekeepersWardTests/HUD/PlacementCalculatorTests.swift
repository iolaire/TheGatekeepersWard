import Foundation
import Testing
@testable import GatekeepersWard

/// Example-based tests for `PlacementCalculator`.
struct PlacementCalculatorTests {
    /// Primary screen height used by most cases.
    private let primaryHeight: CGFloat = 1000
    /// Visible frame with a 25 pt menu bar at the top (AppKit coordinates).
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 975)
    private let hud = CGSize(width: 300, height: 400)

    private func origin(_ alert: CGRect, hud size: CGSize? = nil) -> CGPoint {
        PlacementCalculator.origin(
            alertCG: alert,
            hudSize: size ?? hud,
            primaryScreenHeight: primaryHeight,
            visibleFrame: visible
        )
    }

    @Test("HUD sits to the right of the alert when it fits")
    func rightSide() {
        let p = origin(CGRect(x: 500, y: 200, width: 260, height: 200))
        #expect(p == CGPoint(x: 770, y: 400))
    }

    @Test("HUD flips to the left when the right side overflows")
    func leftSide() {
        let p = origin(CGRect(x: 1200, y: 200, width: 200, height: 200))
        #expect(p == CGPoint(x: 890, y: 400))
    }

    @Test("HUD top is clamped to the visible frame top")
    func verticalClampTop() {
        let p = origin(CGRect(x: 500, y: 0, width: 260, height: 200))
        #expect(p.y == visible.maxY - hud.height)
    }

    @Test("HUD bottom is clamped to the visible frame bottom")
    func verticalClampBottom() {
        let p = origin(CGRect(x: 500, y: 900, width: 260, height: 100))
        #expect(p.y == visible.minY)
    }

    @Test("Flipped-left HUD is clamped to the visible frame left edge")
    func horizontalClamp() {
        // Right overflows; left flip would give x = -210, clamped to 0.
        let p = origin(CGRect(x: 100, y: 200, width: 1300, height: 200))
        #expect(p.x == visible.minX)
    }

    @Test("Oversized HUD aligns to the visible frame top-left")
    func oversizedHUD() {
        let big = CGSize(width: 2000, height: 2000)
        let p = origin(CGRect(x: 500, y: 200, width: 260, height: 200), hud: big)
        #expect(p.x == visible.minX)
        #expect(p.y + big.height == visible.maxY)
    }

    @Test("Coordinate conversion on a known secondary screen")
    func knownScreenConversion() {
        let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let p = PlacementCalculator.origin(
            alertCG: CGRect(x: 1500, y: 100, width: 300, height: 150),
            hudSize: CGSize(width: 400, height: 300),
            primaryScreenHeight: 1080,
            visibleFrame: secondary
        )
        // x = 1800 + 10; top = 1080 - 100 = 980; y = 980 - 300.
        #expect(p == CGPoint(x: 1810, y: 680))
    }

    @Test("Same inputs always give the same origin")
    func determinism() {
        let alert = CGRect(x: 321, y: 123, width: 260, height: 190)
        let first = origin(alert)
        for _ in 0..<10 {
            #expect(origin(alert) == first)
        }
    }
}
