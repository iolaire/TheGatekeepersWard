import AppKit

extension FortressHUDWindow {
    /// Margin from the screen corner used for the fallback placement.
    static let fallbackMargin: CGFloat = 16

    /// Top-right fallback origin on the main screen, used until the alert is found.
    func fallbackOrigin(for size: CGSize) -> NSPoint {
        guard let visible = NSScreen.main?.visibleFrame else { return frame.origin }
        return NSPoint(x: visible.maxX - size.width - Self.fallbackMargin,
                       y: visible.maxY - size.height - Self.fallbackMargin)
    }

    /// Starts the alert search; moves the panel beside the alert if found, then fades in.
    func startLocating(size: CGSize) {
        locateTask?.cancel()
        locateTask = Task { @MainActor [weak self] in
            let bounds = await AlertLocator().locate()
            guard !Task.isCancelled, let self else { return }
            if let bounds { self.moveBesideAlert(bounds, size: size) }
            self.fadeIn()
        }
    }

    /// Moves the panel using `PlacementCalculator` on the screen holding the alert centre.
    private func moveBesideAlert(_ alertCG: CGRect, size: CGSize) {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return }
        // CG global coords (top-left origin) to AppKit (bottom-left origin).
        let centre = NSPoint(x: alertCG.midX, y: primaryHeight - alertCG.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let origin = PlacementCalculator.origin(
            alertCG: alertCG, hudSize: size,
            primaryScreenHeight: primaryHeight, visibleFrame: visible)
        setFrameOrigin(origin)
    }

    /// Shows the panel: instantly under Reduce Motion, otherwise a 0.2 s fade.
    private func fadeIn() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 1
        }
    }
}
