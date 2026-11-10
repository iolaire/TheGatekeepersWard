import Foundation

/// Whether the Ward can currently see TCC prompts.
///
/// `TCCWatcher` publishes this so the menu bar can say so when `/usr/bin/log`
/// cannot be started or keeps exiting. Without it the Ward would look healthy
/// while silently watching nothing.
enum TCCWatcherStatus: Equatable, Sendable {
    /// `log stream` is running, or has only just been restarted once.
    case running
    /// `log stream` could not be started or keeps failing.
    ///
    /// - Parameters:
    ///   - failures: Consecutive failures so far.
    ///   - retryIn: Seconds until the next attempt.
    case failing(failures: Int, retryIn: TimeInterval)

    /// What to tell the user, or `nil` when everything is fine.
    var notice: WatcherNotice? {
        guard case .failing(_, let retryIn) = self else { return nil }
        let seconds = max(Int(retryIn.rounded(.up)), 1)
        return WatcherNotice(
            title: "Not watching for prompts",
            detail: "Gatekeeper's Ward cannot read the system log. Trying again in \(seconds) s.",
            tooltip: "Gatekeeper's Ward is not watching for prompts: it cannot read the system log. Trying again in \(seconds) s."
        )
    }
}

/// The words shown while the watcher is failing.
struct WatcherNotice: Equatable, Sendable {
    /// Short heading, shown as the first line of the menu notice.
    let title: String
    /// One sentence of explanation, shown under the heading.
    let detail: String
    /// The icon's tooltip and accessibility label.
    let tooltip: String
}
