import Foundation
import Testing
@testable import GatekeepersWard

/// Thread-safe call counter for injected window list closures.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    /// Increments and returns the new count.
    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }

    /// Current count.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Example-based tests for `AlertLocator.locate()`.
struct AlertLocatorTests {
    private let owner = "UserNotificationCenter"
    private let layer = 8
    private let alertBounds = CGRect(x: 500, y: 200, width: 260, height: 200)

    private func alertWindow() -> WindowInfo {
        WindowInfo(ownerName: owner, layer: layer, bounds: alertBounds)
    }

    @Test("Alert first seen on the third poll is returned once its bounds repeat")
    func foundOnThirdPoll() async {
        let counter = CallCounter()
        let alert = alertWindow()
        let locator = AlertLocator(
            timeout: 2.0,
            pollInterval: 0.01,
            ownerName: owner,
            layer: layer,
            windowList: { counter.next() >= 3 ? [alert] : [] }
        )
        let result = await locator.locate()
        #expect(result == alertBounds)
        #expect(counter.count == 4)   // seen on 3, confirmed settled on 4
    }

    @Test("Zoom-in animation frames are skipped until the bounds settle")
    func waitsForAnimationToSettle() async {
        let counter = CallCounter()
        let owner = self.owner, layer = self.layer, final = alertBounds
        // Grows from a speck at the centre to full size over three polls.
        let frames = [0.05, 0.4, 0.8].map { scale in
            CGRect(x: final.midX - final.width * scale / 2, y: final.midY - final.height * scale / 2,
                   width: final.width * scale, height: final.height * scale)
        }
        let locator = AlertLocator(
            timeout: 2.0, pollInterval: 0.01, ownerName: owner, layer: layer,
            windowList: {
                let call = counter.next()
                let rect = call <= frames.count ? frames[call - 1] : final
                return [WindowInfo(ownerName: owner, layer: layer, bounds: rect)]
            }
        )
        let result = await locator.locate()
        #expect(result == final)
    }

    @Test("Returns the latest bounds if the alert is still moving at the timeout")
    func stillMovingAtTimeout() async {
        let counter = CallCounter()
        let owner = self.owner, layer = self.layer
        let locator = AlertLocator(
            timeout: 0.05, pollInterval: 0.01, ownerName: owner, layer: layer,
            windowList: {
                let call = CGFloat(counter.next())
                return [WindowInfo(ownerName: owner, layer: layer,
                                   bounds: CGRect(x: call, y: 0, width: 100, height: 100))]
            }
        )
        let result = await locator.locate()
        #expect(result != nil)
        #expect(result?.minX == CGFloat(counter.count))
    }

    @Test("Returns nil after the timeout when the alert never appears")
    func neverFound() async {
        let counter = CallCounter()
        let other = WindowInfo(ownerName: "Finder", layer: 0, bounds: CGRect(x: 0, y: 0, width: 10, height: 10))
        let locator = AlertLocator(
            timeout: 0.05,
            pollInterval: 0.01,
            ownerName: owner,
            layer: layer,
            windowList: { _ = counter.next(); return [other] }
        )
        let result = await locator.locate()
        #expect(result == nil)
        #expect(counter.count >= 2)
    }

    @Test("Empty window list returns nil")
    func emptyList() async {
        let locator = AlertLocator(
            timeout: 0.03,
            pollInterval: 0.01,
            ownerName: owner,
            layer: layer,
            windowList: { [] }
        )
        let result = await locator.locate()
        #expect(result == nil)
    }

    @Test("Default poll interval is at most 100 ms")
    func defaultPollInterval() {
        #expect(AlertLocator.defaultPollInterval <= 0.1)
        #expect(AlertLocator().pollInterval <= 0.1)
    }
}
