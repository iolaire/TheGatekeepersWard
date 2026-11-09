import CoreGraphics
import Foundation

/// Locates Apple's TCC alert through the window server list.
///
/// The list comes from `CGWindowListCopyWindowInfo`, which exposes owner name, layer and
/// bounds without the Accessibility permission. `kCGWindowName` is never read.
///
/// - Note: Verified on macOS 27.0.1 (Build 26A434) by dumping the window list while a
///   WardTrigger TCC dialog was up: owner name `UserNotificationCenter`, layer 8, about
///   260 x 282 pt (see `docs/devlog.md`). If a future macOS changes either value,
///   `locate()` times out and the HUD uses the fallback placement.
struct AlertLocator: Sendable {
    /// Verified owner name of the TCC alert window (macOS 27.0.1).
    static let defaultOwnerName = "UserNotificationCenter"
    /// Verified layer of the TCC alert window (macOS 27.0.1).
    static let defaultLayer = 8
    /// Default search timeout in seconds.
    static let defaultTimeout: TimeInterval = 1.0
    /// Default poll interval in seconds (at most 100 ms).
    static let defaultPollInterval: TimeInterval = 0.1

    /// Maximum time to search before giving up, in seconds.
    var timeout: TimeInterval
    /// Delay between window list queries, in seconds.
    var pollInterval: TimeInterval
    /// Owner name the alert window must have.
    var ownerName: String
    /// Layer the alert window must have.
    var layer: Int
    /// Source of window list entries, injectable for tests.
    var windowList: @Sendable () -> [WindowInfo]

    /// Creates a locator.
    /// - Parameters:
    ///   - timeout: Search timeout in seconds.
    ///   - pollInterval: Delay between queries in seconds.
    ///   - ownerName: Expected owner name of the alert window.
    ///   - layer: Expected layer of the alert window.
    ///   - windowList: Window list source; defaults to the window server.
    init(timeout: TimeInterval = AlertLocator.defaultTimeout,
         pollInterval: TimeInterval = AlertLocator.defaultPollInterval,
         ownerName: String = AlertLocator.defaultOwnerName,
         layer: Int = AlertLocator.defaultLayer,
         windowList: @escaping @Sendable () -> [WindowInfo] = AlertLocator.systemWindowList) {
        self.timeout = timeout
        self.pollInterval = pollInterval
        self.ownerName = ownerName
        self.layer = layer
        self.windowList = windowList
    }

    /// Reads the on-screen window list from the window server.
    ///
    /// Returns an empty array when the server yields no list.
    @Sendable
    static func systemWindowList() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.map { WindowInfo(dictionary: $0) }
    }

    /// Polls until the alert is found with settled bounds, or the timeout elapses.
    ///
    /// The alert zooms in from a tiny rect at its centre, so the first match can be a
    /// mid-animation frame. Bounds are returned only once two consecutive polls agree.
    /// If the alert is still moving at the timeout, the latest bounds are returned.
    /// Sleeps with `Task.sleep` between polls, so the calling thread is never blocked.
    /// - Returns: The alert's CG bounds, or `nil` if it never appeared or the task was cancelled.
    func locate() async -> CGRect? {
        let clock = ContinuousClock()
        let start = clock.now
        let limit = Duration.seconds(timeout)
        var candidate: CGRect?
        while true {
            if Task.isCancelled { return nil }
            let bounds = AlertMatcher.match(windowList(), ownerName: ownerName, layer: layer)
            if let bounds, bounds == candidate { return bounds }   // settled
            candidate = bounds
            if start.duration(to: clock.now) >= limit { return candidate }
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                return nil
            }
        }
    }
}
