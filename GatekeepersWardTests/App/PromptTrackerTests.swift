import Testing
@testable import GatekeepersWard

/// `PromptTracker` decides what the HUD shows as prompts open and close.
/// Content is a plain string here; the rules do not depend on its type.
@Suite("PromptTracker")
struct PromptTrackerTests {
    private func shown(_ change: PromptTracker<String>.Change) -> String? {
        if case .show(let content) = change { return content }
        return nil
    }

    private func isHide(_ change: PromptTracker<String>.Change) -> Bool {
        if case .hide = change { return true }
        return false
    }

    private func isNone(_ change: PromptTracker<String>.Change) -> Bool {
        if case .none = change { return true }
        return false
    }

    @Test("A new prompt is shown")
    func promptIsShown() {
        var tracker = PromptTracker<String>()
        #expect(shown(tracker.prompt(messageID: "1.1", content: "docs")) == "docs")
        #expect(!tracker.isEmpty)
    }

    @Test("Answering the only prompt hides the HUD")
    func resolveLastPromptHides() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "docs")
        #expect(isHide(tracker.resolve(messageID: "1.1")))
        #expect(tracker.isEmpty)
    }

    @Test("A second prompt replaces the first; answering it brings the first back")
    func concurrentPromptsStack() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "docs")
        #expect(shown(tracker.prompt(messageID: "2.2", content: "mic")) == "mic")
        #expect(shown(tracker.resolve(messageID: "2.2")) == "docs")
        #expect(isHide(tracker.resolve(messageID: "1.1")))
    }

    @Test("Answering a prompt that is not on screen changes nothing visible")
    func resolveHiddenPromptIsQuiet() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "docs")
        _ = tracker.prompt(messageID: "2.2", content: "mic")
        #expect(isNone(tracker.resolve(messageID: "1.1")))
        // The mic prompt is still the only one left.
        #expect(isHide(tracker.resolve(messageID: "2.2")))
    }

    @Test("A result for an unknown msgID is ignored")
    func unknownResultIgnored() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "docs")
        #expect(isNone(tracker.resolve(messageID: "9.9")))
        #expect(!tracker.isEmpty)
    }

    @Test("A repeated msgID replaces the earlier prompt instead of stacking")
    func repeatedMessageIDReplaces() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "first")
        _ = tracker.prompt(messageID: "1.1", content: "second")
        #expect(isHide(tracker.resolve(messageID: "1.1")))
    }

    @Test("Prompts without a msgID are tracked separately and cleared by expire")
    func legacyPromptsExpire() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: nil, content: "old-1")
        _ = tracker.prompt(messageID: nil, content: "old-2")
        #expect(!tracker.isEmpty)
        tracker.expire()
        #expect(tracker.isEmpty)
    }

    @Test("A result arriving after expiry is ignored")
    func lateResultAfterExpiry() {
        var tracker = PromptTracker<String>()
        _ = tracker.prompt(messageID: "1.1", content: "docs")
        tracker.expire()
        #expect(isNone(tracker.resolve(messageID: "1.1")))
    }
}
