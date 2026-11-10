import Foundation

/// The plain-language text of a permission request: the sentence and, when
/// the app gave one, its stated reason.
struct RequestText: Equatable, Sendable {
    /// For example `Allow “WardTrigger” to access your microphone?`.
    let headline: String
    /// The app's own reason from its `Info.plist`, as Apple's dialog shows it.
    let purpose: String?
}

/// Turns a TCC service and an app name into the wording of Apple's dialog,
/// so people do not have to read service keys.
enum PromptSummary {
    /// The sentence for a request.
    ///
    /// - Parameters:
    ///   - service: What is being requested.
    ///   - appName: The app asking, or `nil` when it could not be identified.
    static func headline(service: TCCService, appName: String?) -> String {
        let who = appName.map { "“\($0)”" } ?? "an app"
        switch service {
        case .appleEvents: return "Allow \(who) to control another app?"
        case .screenCapture: return "Allow \(who) to record your screen and audio?"
        case .unknown: return "Allow \(who) to access a protected part of your Mac?"
        default: return "Allow \(who) to access \(resource(for: service))?"
        }
    }

    /// The thing being accessed, as a phrase that follows "access".
    static func resource(for service: TCCService) -> String {
        switch service {
        case .documentsFolder: return "files in your Documents folder"
        case .desktopFolder: return "files in your Desktop folder"
        case .downloadsFolder: return "files in your Downloads folder"
        case .addressBook: return "your contacts"
        case .calendar: return "your calendar"
        case .reminders: return "your reminders"
        case .photos: return "your photos"
        case .camera: return "your camera"
        case .microphone: return "your microphone"
        case .appleEvents: return "another app"
        case .screenCapture: return "your screen"
        case .unknown: return "a protected part of your Mac"
        }
    }

    /// The `Info.plist` keys in which an app explains a request, best match first.
    static func usageDescriptionKeys(for service: TCCService) -> [String] {
        switch service {
        case .documentsFolder: return ["NSDocumentsFolderUsageDescription"]
        case .desktopFolder: return ["NSDesktopFolderUsageDescription"]
        case .downloadsFolder: return ["NSDownloadsFolderUsageDescription"]
        case .addressBook: return ["NSContactsUsageDescription"]
        case .calendar: return ["NSCalendarsFullAccessUsageDescription", "NSCalendarsUsageDescription"]
        case .reminders: return ["NSRemindersFullAccessUsageDescription", "NSRemindersUsageDescription"]
        case .photos: return ["NSPhotoLibraryUsageDescription"]
        case .camera: return ["NSCameraUsageDescription"]
        case .microphone: return ["NSMicrophoneUsageDescription"]
        case .appleEvents: return ["NSAppleEventsUsageDescription"]
        case .screenCapture: return ["NSScreenCaptureDescription"]
        case .unknown: return []
        }
    }

    /// The request text for a service, naming the app and adding its reason when known.
    static func requestText(service: TCCService, appName: String?, info: AppBundleInfo?) -> RequestText {
        RequestText(headline: headline(service: service, appName: appName),
                    purpose: info?.usageDescription(for: service))
    }
}
