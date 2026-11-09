import CoreGraphics
import Foundation
import Testing
@testable import GatekeepersWard

/// PBT coverage for `AlertMatcher` (hud-placement-and-menubar-theme,
/// Requirements 2.2, 2.3, 2.7).
struct AlertMatcherPropertyTests {
    /// Iteration count for the property loops: 200 in CI, 1000 locally.
    private static var propertyIterations: Int {
        ProcessInfo.processInfo.environment["CI"] != nil ? 200 : 1000
    }

    private static let targetOwner = "UserNotificationCenter"
    private static let targetLayer = 2
    private static let owners: [String?] = [targetOwner, targetOwner, "Finder", "Dock", "", nil]
    private static let layers: [Int?] = [targetLayer, targetLayer, 0, 3, 25, -1, nil]

    /// Draws random bounds: missing, zero width, zero height, negative size, or valid.
    private static func randomBounds(rng: inout SeededRNG) -> CGRect? {
        let x = CGFloat(Int.random(in: -500...3000, using: &rng))
        let y = CGFloat(Int.random(in: -500...2000, using: &rng))
        let w = CGFloat(Int.random(in: 1...800, using: &rng))
        let h = CGFloat(Int.random(in: 1...600, using: &rng))
        switch Int.random(in: 0..<7, using: &rng) {
        case 0: return nil
        case 1: return CGRect(x: x, y: y, width: 0, height: h)
        case 2: return CGRect(x: x, y: y, width: w, height: 0)
        case 3: return CGRect(x: x, y: y, width: 0, height: 0)
        case 4: return CGRect(x: x, y: y, width: -w, height: h)
        default: return CGRect(x: x, y: y, width: w, height: h)
        }
    }

    /// Draws a random window entry mixing matching and non-matching fields.
    private static func randomWindow(rng: inout SeededRNG) -> WindowInfo {
        WindowInfo(
            ownerName: owners.randomElement(using: &rng) ?? nil,
            layer: layers.randomElement(using: &rng) ?? nil,
            bounds: randomBounds(rng: &rng)
        )
    }

    // Feature: hud-placement-and-menubar-theme, Property 5: Alert matching selects only valid matching windows
    /// **Validates: Requirements 2.2, 2.3, 2.7**
    @Test("Property 5: alert matching selects only valid matching windows")
    func matchSelectsFirstValidMatchingWindow() {
        var rng = SeededRNG(seed: 0xA1E7_0005)
        for _ in 0..<Self.propertyIterations {
            let count = Int.random(in: 0...12, using: &rng)
            let windows = (0..<count).map { _ in Self.randomWindow(rng: &rng) }

            // Independent oracle: first entry satisfying every condition.
            let expected = windows.first { window in
                guard window.ownerName == Self.targetOwner,
                      window.layer == Self.targetLayer,
                      let b = window.bounds else { return false }
                return b.width > 0 && b.height > 0
            }?.bounds

            let result = AlertMatcher.match(
                windows, ownerName: Self.targetOwner, layer: Self.targetLayer
            )
            #expect(result == expected)

            if let result {
                #expect(result.width > 0 && result.height > 0)
                #expect(windows.contains {
                    $0.ownerName == Self.targetOwner
                        && $0.layer == Self.targetLayer
                        && $0.bounds == result
                })
            }
        }
    }

    @Test("Property 5: empty list and all-invalid lists yield nil")
    func emptyAndInvalidListsYieldNil() {
        #expect(AlertMatcher.match([], ownerName: Self.targetOwner, layer: Self.targetLayer) == nil)
        let invalid = [
            WindowInfo(ownerName: Self.targetOwner, layer: Self.targetLayer, bounds: nil),
            WindowInfo(ownerName: Self.targetOwner, layer: Self.targetLayer,
                       bounds: CGRect(x: 0, y: 0, width: 0, height: 10)),
            WindowInfo(ownerName: "Finder", layer: Self.targetLayer,
                       bounds: CGRect(x: 0, y: 0, width: 10, height: 10)),
        ]
        #expect(AlertMatcher.match(invalid, ownerName: Self.targetOwner, layer: Self.targetLayer) == nil)
    }
}
