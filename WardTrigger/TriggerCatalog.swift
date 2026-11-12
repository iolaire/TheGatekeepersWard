import Foundation

/// One TCC trigger: its CLI subcommand, the TCC service it exercises, a
/// usage-line description, and the function that fires it.
struct TriggerSpec: Sendable {
    /// The lowercase CLI subcommand (e.g. `docs`).
    let name: String
    /// The `kTCCService*` key the trigger is expected to produce.
    let serviceKey: String
    /// One-line description shown in the usage summary.
    let summary: String
    /// Fires the trigger.
    let run: @Sendable () -> Void
}

/// Every TCC trigger WardTrigger supports, in usage-summary order. The
/// dispatcher, usage text, and tests all read from this single list.
let wardTriggerCatalog: [TriggerSpec] = [
    TriggerSpec(
        name: "docs", serviceKey: "kTCCServiceSystemPolicyDocumentsFolder",
        summary: "Attempt to read ~/Documents/.ward_canary — triggers the Documents folder TCC prompt.",
        run: triggerDocuments),
    TriggerSpec(
        name: "desktop", serviceKey: "kTCCServiceSystemPolicyDesktopFolder",
        summary: "List ~/Desktop read-only — triggers the Desktop folder TCC prompt.",
        run: triggerDesktop),
    TriggerSpec(
        name: "downloads", serviceKey: "kTCCServiceSystemPolicyDownloadsFolder",
        summary: "List ~/Downloads read-only — triggers the Downloads folder TCC prompt.",
        run: triggerDownloads),
    TriggerSpec(
        name: "contacts", serviceKey: "kTCCServiceAddressBook",
        summary: "Request Contacts access via CNContactStore — triggers the Contacts TCC prompt.",
        run: triggerContacts),
    TriggerSpec(
        name: "calendar", serviceKey: "kTCCServiceCalendar",
        summary: "Request Calendar access via EventKit — triggers the Calendar TCC prompt.",
        run: triggerCalendar),
    TriggerSpec(
        name: "reminders", serviceKey: "kTCCServiceReminders",
        summary: "Request Reminders access via EventKit — triggers the Reminders TCC prompt.",
        run: triggerReminders),
    TriggerSpec(
        name: "photos", serviceKey: "kTCCServicePhotos",
        summary: "Request Photos access via PHPhotoLibrary — triggers the Photos TCC prompt.",
        run: triggerPhotos),
    TriggerSpec(
        name: "mic", serviceKey: "kTCCServiceMicrophone",
        summary: "Request Microphone access via AVFoundation — triggers the Microphone TCC prompt.",
        run: triggerMicrophone),
    TriggerSpec(
        name: "camera", serviceKey: "kTCCServiceCamera",
        summary: "Request Camera access via AVFoundation — triggers the Camera TCC prompt.",
        run: triggerCamera),
    TriggerSpec(
        name: "events", serviceKey: "kTCCServiceAppleEvents",
        summary: "Send Finder an Apple event (like osascript) — triggers the Automation TCC prompt.",
        run: triggerAppleEvents),
    TriggerSpec(
        name: "screen", serviceKey: "kTCCServiceScreenCapture",
        summary: "Request screen recording via CoreGraphics — triggers the Screen Recording TCC prompt.",
        run: triggerScreenCapture),
]
