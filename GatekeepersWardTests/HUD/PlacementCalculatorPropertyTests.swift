import Foundation
import Testing
@testable import GatekeepersWard

/// PBT coverage for `PlacementCalculator` (hud-placement-and-menubar-theme,
/// Requirements 3.1–3.8). Properties 2–4 are appended below by later tasks.
struct PlacementCalculatorPropertyTests {
    /// Iteration count for the property loops: 200 in CI, 1000 locally.
    private static var propertyIterations: Int {
        ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    }

    /// Draws an integer-valued `CGFloat` in `range`, so geometry is exact and
    /// equality checks need no tolerance.
    private static func value(
        _ range: ClosedRange<Int>, rng: inout SeededRNG
    ) -> CGFloat {
        CGFloat(Int.random(in: range, using: &rng))
    }

    // Feature: hud-placement-and-menubar-theme, Property 1: Coordinate conversion and adjacency
    /// **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
    @Test("Property 1: HUD top matches the flipped alert top and sits 10 pt right of the alert")
    func coordinateConversionAndAdjacency() {
        var rng = SeededRNG(seed: 0xA1E7_0001)
        for _ in 0..<Self.propertyIterations {
            let primaryHeight = Self.value(600...2200, rng: &rng)
            let alert = CGRect(
                x: Self.value(0...3000, rng: &rng),
                y: Self.value(0...Int(primaryHeight) - 50, rng: &rng),
                width: Self.value(50...600, rng: &rng),
                height: Self.value(50...500, rng: &rng)
            )
            let hud = CGSize(
                width: Self.value(100...800, rng: &rng),
                height: Self.value(100...900, rng: &rng)
            )

            // Visible frame surrounds the alert and the right-hand HUD slot
            // with room to spare, so no flip or clamp can occur.
            let expectedX = alert.maxX + PlacementCalculator.gap
            let expectedTop = primaryHeight - alert.minY
            let minX = alert.minX - Self.value(0...200, rng: &rng)
            let maxX = expectedX + hud.width + Self.value(0...500, rng: &rng)
            let maxY = expectedTop + Self.value(0...200, rng: &rng)
            let minY = expectedTop - hud.height - Self.value(0...500, rng: &rng)
            let visible = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

            let origin = PlacementCalculator.origin(
                alertCG: alert,
                hudSize: hud,
                primaryScreenHeight: primaryHeight,
                visibleFrame: visible
            )
            let frame = CGRect(origin: origin, size: hud)

            #expect(frame.maxY == expectedTop, "top edge \(frame.maxY) != \(expectedTop) for alert \(alert)")
            #expect(frame.minX == expectedX, "left edge \(frame.minX) != \(expectedX) for alert \(alert)")
            #expect(frame.minX - alert.maxX == PlacementCalculator.gap)
        }
    }

    // Feature: hud-placement-and-menubar-theme, Property 2: Left flip when the right side overflows
    /// **Validates: Requirements 3.5**
    @Test("Property 2: HUD flips to 10 pt left of the alert when the right side overflows")
    func leftFlipWhenRightOverflows() {
        var rng = SeededRNG(seed: 0xA1E7_0002)
        for _ in 0..<Self.propertyIterations {
            let primaryHeight = Self.value(600...2200, rng: &rng)
            let alert = CGRect(
                x: Self.value(400...3000, rng: &rng),
                y: Self.value(0...Int(primaryHeight) - 50, rng: &rng),
                width: Self.value(50...600, rng: &rng),
                height: Self.value(50...500, rng: &rng)
            )
            let hud = CGSize(
                width: Self.value(100...350, rng: &rng),
                height: Self.value(100...900, rng: &rng)
            )

            // Left slot fits: minX at or below the left slot's left edge.
            let leftEdge = alert.minX - PlacementCalculator.gap - hud.width
            let minX = leftEdge - Self.value(0...300, rng: &rng)
            // Right slot overflows while the left slot's right edge still fits.
            let rightEnd = alert.maxX + PlacementCalculator.gap + hud.width
            let maxX = Self.value(Int(alert.minX)...Int(rightEnd) - 1, rng: &rng)
            // Vertical frame is generous so vertical clamping is irrelevant.
            let top = primaryHeight - alert.minY
            let visible = CGRect(
                x: minX,
                y: top - hud.height - Self.value(0...500, rng: &rng),
                width: maxX - minX,
                height: hud.height + Self.value(0...500, rng: &rng) + Self.value(0...200, rng: &rng)
            )

            // Preconditions of the property.
            guard alert.maxX + PlacementCalculator.gap + hud.width > visible.maxX,
                  leftEdge >= visible.minX,
                  alert.minX - PlacementCalculator.gap <= visible.maxX else { continue }

            let origin = PlacementCalculator.origin(
                alertCG: alert,
                hudSize: hud,
                primaryScreenHeight: primaryHeight,
                visibleFrame: visible
            )
            let frame = CGRect(origin: origin, size: hud)

            #expect(
                frame.maxX == alert.minX - PlacementCalculator.gap,
                "right edge \(frame.maxX) != \(alert.minX - PlacementCalculator.gap) for alert \(alert), visible \(visible)"
            )
        }
    }

    // Feature: hud-placement-and-menubar-theme, Property 3: Result is contained in the visible frame
    /// **Validates: Requirements 3.6, 3.7, 4.4**
    @Test("Property 3: result lies inside the visible frame when the HUD fits")
    func resultContainedInVisibleFrame() {
        var rng = SeededRNG(seed: 0xA1E7_0003)
        for _ in 0..<Self.propertyIterations {
            let primaryHeight = Self.value(600...2200, rng: &rng)
            // The alert may sit anywhere, including partly or fully outside
            // the visible frame, so every clamp path is exercised.
            let alert = CGRect(
                x: Self.value(-500...4000, rng: &rng),
                y: Self.value(-200...Int(primaryHeight) + 200, rng: &rng),
                width: Self.value(50...600, rng: &rng),
                height: Self.value(50...500, rng: &rng)
            )
            let visible = CGRect(
                x: Self.value(-1500...3000, rng: &rng),
                y: Self.value(-1000...1500, rng: &rng),
                width: Self.value(300...2500, rng: &rng),
                height: Self.value(300...1500, rng: &rng)
            )
            // HUD fits the visible frame in both dimensions.
            let hud = CGSize(
                width: Self.value(50...Int(visible.width), rng: &rng),
                height: Self.value(50...Int(visible.height), rng: &rng)
            )

            let origin = PlacementCalculator.origin(
                alertCG: alert,
                hudSize: hud,
                primaryScreenHeight: primaryHeight,
                visibleFrame: visible
            )
            let frame = CGRect(origin: origin, size: hud)

            #expect(frame.minX >= visible.minX, "minX \(frame.minX) < \(visible.minX) for alert \(alert), hud \(hud)")
            #expect(frame.maxX <= visible.maxX, "maxX \(frame.maxX) > \(visible.maxX) for alert \(alert), hud \(hud)")
            #expect(frame.minY >= visible.minY, "minY \(frame.minY) < \(visible.minY) for alert \(alert), hud \(hud)")
            #expect(frame.maxY <= visible.maxY, "maxY \(frame.maxY) > \(visible.maxY) for alert \(alert), hud \(hud)")
        }
    }

    // Feature: hud-placement-and-menubar-theme, Property 4: Oversized HUD aligns to top-left
    /// **Validates: Requirements 3.8**
    @Test("Property 4: oversized HUD aligns to the visible frame left and/or top edge")
    func oversizedHUDAlignsTopLeft() {
        var rng = SeededRNG(seed: 0xA1E7_0004)
        for _ in 0..<Self.propertyIterations {
            let primaryHeight = Self.value(600...2200, rng: &rng)
            let alert = CGRect(
                x: Self.value(-500...4000, rng: &rng),
                y: Self.value(-200...Int(primaryHeight) + 200, rng: &rng),
                width: Self.value(50...600, rng: &rng),
                height: Self.value(50...500, rng: &rng)
            )
            let visible = CGRect(
                x: Self.value(-1500...3000, rng: &rng),
                y: Self.value(-1000...1500, rng: &rng),
                width: Self.value(300...2500, rng: &rng),
                height: Self.value(300...1500, rng: &rng)
            )
            // At least one dimension is strictly larger than the visible frame.
            let wider = Bool.random(using: &rng)
            let taller = wider ? Bool.random(using: &rng) : true
            let hud = CGSize(
                width: wider
                    ? visible.width + Self.value(1...800, rng: &rng)
                    : Self.value(50...Int(visible.width), rng: &rng),
                height: taller
                    ? visible.height + Self.value(1...800, rng: &rng)
                    : Self.value(50...Int(visible.height), rng: &rng)
            )

            let origin = PlacementCalculator.origin(
                alertCG: alert,
                hudSize: hud,
                primaryScreenHeight: primaryHeight,
                visibleFrame: visible
            )
            let frame = CGRect(origin: origin, size: hud)

            if wider {
                #expect(frame.minX == visible.minX, "minX \(frame.minX) != \(visible.minX) for alert \(alert), hud \(hud)")
            }
            if taller {
                #expect(frame.maxY == visible.maxY, "maxY \(frame.maxY) != \(visible.maxY) for alert \(alert), hud \(hud)")
            }
        }
    }
}
