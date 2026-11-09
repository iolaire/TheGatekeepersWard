import AppKit
import SwiftUI

/// The floating, non-activating panel that holds the Fortress HUD.
///
/// It never becomes key or main, so Apple's TCC dialog keeps keyboard focus
/// (`.kiro/steering/swiftui-hud-design.md` §2).
@MainActor
final class FortressHUDWindow: NSPanel {
    /// How long the HUD stays up if no result is seen.
    static let autoDismissDelay: TimeInterval = 30

    private var dismissTask: Task<Void, Never>?
    /// In-flight alert search; cancelled on a new `present` and on `dismiss()`.
    var locateTask: Task<Void, Never>?

    /// Called when the HUD hides itself after `autoDismissDelay`, so the owner
    /// can drop its state for the prompts that timed out.
    var onAutoDismiss: (() -> Void)?

    /// Creates a hidden panel.
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        // An accessory app is never "active", so the default would hide us.
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Shows `content` near the top-right of the main screen without taking
    /// focus, and schedules the auto-dismiss.
    func present(_ content: HUDContent) {
        let hosting = NSHostingView(rootView: FortressHUDView(content: content))
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        contentView = hosting
        setContentSize(size)
        setFrameOrigin(fallbackOrigin(for: size))
        alphaValue = 0   // faded in after the first locate result or timeout
        orderFrontRegardless()   // never makeKeyAndOrderFront
        startLocating(size: size)
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.autoDismissDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.dismiss()
            self?.onAutoDismiss?()
        }
    }

    /// Fades the panel out (0.25 s) and hides it.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        locateTask?.cancel()
        locateTask = nil
        guard isVisible else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.orderOut(nil) }
        })
    }
}
