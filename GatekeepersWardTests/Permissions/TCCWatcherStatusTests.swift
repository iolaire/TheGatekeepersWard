import Foundation
import Testing
@testable import GatekeepersWard

/// The watcher tells the UI when it cannot read the log (ward-app 1.9).
@Suite("TCCWatcher status")
struct TCCWatcherStatusTests {
    // MARK: Decision (1.9)

    @Test("A single failed run restarts quietly (1.9)")
    func oneFailureIsQuiet() {
        #expect(TCCWatcher.status(afterFailures: 1, retryIn: 2, couldNotStart: false) == .running)
    }

    @Test("Two failures in a row are reported (1.9)", arguments: [2, 3, 10])
    func repeatedFailuresAreReported(failures: Int) {
        #expect(TCCWatcher.status(afterFailures: failures, retryIn: 8, couldNotStart: false)
                == .failing(failures: failures, retryIn: 8))
    }

    @Test("A launch that threw is reported straight away (1.9)")
    func failedLaunchIsReportedAtOnce() {
        #expect(TCCWatcher.status(afterFailures: 1, retryIn: 2, couldNotStart: true)
                == .failing(failures: 1, retryIn: 2))
    }

    // MARK: Words (1.10)

    @Test("A running watcher has no notice (1.10)")
    func runningHasNoNotice() {
        #expect(TCCWatcherStatus.running.notice == nil)
    }

    @Test("The notice says the Ward is not watching and when it will try again (1.10)")
    func noticeText() throws {
        let notice = try #require(TCCWatcherStatus.failing(failures: 3, retryIn: 8).notice)
        #expect(notice.title == "Not watching for prompts")
        #expect(notice.detail.contains("8 s"))
        #expect(notice.tooltip.contains("not watching"))
        #expect(notice.tooltip.contains("8 s"))
    }

    @Test("Fractions of a second round up and the wait is never shown as 0 (1.10)")
    func secondsRoundUp() throws {
        #expect(try #require(TCCWatcherStatus.failing(failures: 2, retryIn: 3.2).notice).detail.contains("4 s"))
        #expect(try #require(TCCWatcherStatus.failing(failures: 2, retryIn: 0.1).notice).detail.contains("1 s"))
        #expect(try #require(TCCWatcherStatus.failing(failures: 2, retryIn: 0).notice).detail.contains("1 s"))
    }

    // MARK: A real failed launch (1.9)

    @Test("A watcher whose binary is missing publishes a failing status at once (1.9)")
    func missingBinary() async throws {
        let watcher = TCCWatcher(executable: URL(fileURLWithPath: "/nonexistent/ward-test-log"))
        await watcher.start()
        defer { Task { await watcher.stop() } }

        let first = await firstStatus(of: watcher, timeout: 5)
        #expect(first == .failing(failures: 1, retryIn: TCCWatcher.restartDelay(afterFailures: 1)))
        #expect(first?.notice != nil)
    }

    /// The first status the watcher publishes, or `nil` after `timeout` seconds.
    private func firstStatus(of watcher: TCCWatcher, timeout: TimeInterval) async -> TCCWatcherStatus? {
        await withTaskGroup(of: TCCWatcherStatus?.self) { group in
            group.addTask {
                for await status in watcher.statuses { return status }
                return nil
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}
