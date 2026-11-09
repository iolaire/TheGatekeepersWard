/// Tracks which TCC prompts are open and what the HUD should show.
///
/// macOS can hold several prompts at once. The HUD shows the newest one; when
/// that prompt is answered the previous one comes back, and only when none
/// are left does the HUD hide and the ghost go idle. Pure and synchronous so
/// the rules are testable without AppKit.
struct PromptTracker<Content> {
    /// What the app should do after a tracker update.
    enum Change {
        /// Leave the HUD as it is.
        case none
        /// Show this content (a new prompt, or an older one that is current again).
        case show(Content)
        /// No prompts are open: hide the HUD and end the ghost alert.
        case hide
    }

    private struct Entry {
        let id: String
        let content: Content
    }

    private var open: [Entry] = []
    private var legacyCount = 0

    /// `true` when no prompt is open.
    var isEmpty: Bool { open.isEmpty }

    /// Records a new prompt and makes it the one shown.
    ///
    /// Prompts from older macOS wordings carry no `msgID` and never produce a
    /// result line, so they get a private id and end only through `expire()`.
    /// A prompt that repeats an open `msgID` replaces the earlier one.
    mutating func prompt(messageID: String?, content: Content) -> Change {
        let id: String
        if let messageID {
            id = messageID
        } else {
            legacyCount += 1
            id = "legacy-\(legacyCount)"
        }
        open.removeAll { $0.id == id }
        open.append(Entry(id: id, content: content))
        return .show(content)
    }

    /// Records the answer to the prompt with `messageID`.
    ///
    /// Unknown ids are ignored. Answering the prompt on screen reveals the
    /// previous open prompt, or hides the HUD if there is none. Answering a
    /// prompt that is not on screen only forgets it.
    mutating func resolve(messageID: String) -> Change {
        guard let index = open.firstIndex(where: { $0.id == messageID }) else { return .none }
        let wasShown = index == open.count - 1
        open.remove(at: index)
        guard wasShown else { return .none }
        if let previous = open.last { return .show(previous.content) }
        return .hide
    }

    /// Forgets every open prompt, for when the HUD timed out on its own.
    mutating func expire() {
        open.removeAll()
    }
}
