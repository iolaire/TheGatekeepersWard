import Foundation

/// Computes the Fortress HUD origin beside Apple's TCC alert.
///
/// Pure and deterministic: no AppKit or window-server dependency, so the
/// geometry can be unit tested without a screen.
struct PlacementCalculator {
    /// Horizontal gap between the alert and the HUD, in points.
    static let gap: CGFloat = 10

    /// Returns the AppKit origin (bottom-left) for the HUD panel.
    ///
    /// The HUD top is aligned with the alert top and the HUD sits `gap` points
    /// to the right of the alert. If that overflows the visible frame, the HUD
    /// flips to the left of the alert. The result is then clamped inside the
    /// visible frame. An oversized HUD aligns to the visible frame top-left.
    ///
    /// - Parameters:
    ///   - alertCG: Alert bounds in CG global coordinates (origin top-left of
    ///     the primary screen, y increasing downward).
    ///   - hudSize: The HUD panel size.
    ///   - primaryScreenHeight: Height of the primary screen, used for the y flip.
    ///   - visibleFrame: Target screen visible frame in AppKit coordinates
    ///     (origin bottom-left, y increasing upward).
    /// - Returns: The AppKit origin for the HUD panel.
    static func origin(
        alertCG: CGRect,
        hudSize: CGSize,
        primaryScreenHeight: CGFloat,
        visibleFrame: CGRect
    ) -> CGPoint {
        // Horizontal: prefer right of the alert, flip left on overflow.
        var x = alertCG.maxX + gap
        if x + hudSize.width > visibleFrame.maxX {
            x = alertCG.minX - gap - hudSize.width
        }
        // Upper bound first, lower bound last: oversized HUD aligns left.
        x = min(x, visibleFrame.maxX - hudSize.width)
        x = max(x, visibleFrame.minX)

        // Vertical: flip CG top edge to AppKit top edge.
        var top = primaryScreenHeight - alertCG.minY
        top = min(top, visibleFrame.maxY)
        top = max(top, visibleFrame.minY + hudSize.height)
        // Final min: oversized HUD aligns its top to the visible frame top.
        top = min(top, visibleFrame.maxY)

        return CGPoint(x: x, y: top - hudSize.height)
    }
}
