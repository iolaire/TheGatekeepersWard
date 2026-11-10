import Foundation

/// What an app's `Info.plist` says about itself: its display name and the
/// reasons it gives for each protected resource.
///
/// Apple's permission dialog shows the same name and the same reason text, so
/// reading them lets the HUD say what the dialog says. Only the `Info.plist`
/// file is read; no permission is needed and the app is never launched.
struct AppBundleInfo: Equatable, Sendable {
    /// `CFBundleDisplayName`, else `CFBundleName`.
    let displayName: String?
    /// Every `NS…UsageDescription` entry, by key.
    let usageDescriptions: [String: String]

    /// The reason the app gives for the requested service, if its `Info.plist` has one.
    func usageDescription(for service: TCCService) -> String? {
        for key in PromptSummary.usageDescriptionKeys(for: service) {
            if let text = usageDescriptions[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return text
            }
        }
        return nil
    }

    /// The outermost `.app` bundle that contains an executable, or `nil` when
    /// the executable is not inside one (for example `/opt/homebrew/bin/rg`).
    ///
    /// The outermost bundle is used because that is the app people know: a
    /// helper inside `Cursor.app` is shown as Cursor.
    static func bundleURL(forExecutable path: String) -> URL? {
        let components = (path as NSString).pathComponents
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") && $0.count > 4 }) else { return nil }
        return URL(fileURLWithPath: NSString.path(withComponents: Array(components[...index])), isDirectory: true)
    }

    /// Reads the bundle information for an executable, or `nil` when it is not
    /// inside an app or the `Info.plist` cannot be read.
    static func read(forExecutable path: String) -> AppBundleInfo? {
        guard let bundle = bundleURL(forExecutable: path) else { return nil }
        let plist = bundle.appendingPathComponent("Contents/Info.plist")
        guard let values = NSDictionary(contentsOf: plist) as? [String: Any] else { return nil }
        return AppBundleInfo(values: values)
    }

    /// Builds the info from the decoded top-level `Info.plist` dictionary.
    init(values: [String: Any]) {
        func text(_ key: String) -> String? {
            (values[key] as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        displayName = text("CFBundleDisplayName") ?? text("CFBundleName")
        var usage: [String: String] = [:]
        for (key, value) in values where key.hasSuffix("UsageDescription") || key == "NSScreenCaptureDescription" {
            if let string = value as? String { usage[key] = string }
        }
        usageDescriptions = usage
    }

    /// Creates the info directly (for tests).
    init(displayName: String?, usageDescriptions: [String: String]) {
        self.displayName = displayName
        self.usageDescriptions = usageDescriptions
    }
}
