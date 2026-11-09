import Testing
@testable import GatekeepersWard

/// The restart backoff keeps a broken `log stream` from being relaunched in a
/// tight loop while still recovering quickly from a one-off exit.
@Suite("TCCWatcher restart backoff")
struct TCCWatcherRestartTests {
    @Test("The first restart waits 2 seconds, then the delay doubles")
    func delaysDouble() {
        let delays = (1...5).map { TCCWatcher.restartDelay(afterFailures: $0) }
        #expect(delays == [2, 4, 8, 16, 32])
    }

    @Test("The delay is capped at 60 seconds", arguments: [6, 7, 20, 1_000])
    func delayIsCapped(failures: Int) {
        #expect(TCCWatcher.restartDelay(afterFailures: failures) == 60)
    }

    @Test("Zero or negative failure counts still give the base delay", arguments: [0, -1, -100])
    func nonPositiveFailures(failures: Int) {
        #expect(TCCWatcher.restartDelay(afterFailures: failures) == 2)
    }
}
