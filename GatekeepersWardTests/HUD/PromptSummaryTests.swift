import Foundation
import Testing
@testable import GatekeepersWard

/// The plain-language request text: sentences, plist reading and how they reach the HUD content.
@Suite("Request text")
struct PromptSummaryTests {
    private static let services: [TCCService] = [
        .documentsFolder, .desktopFolder, .downloadsFolder, .addressBook, .calendar, .reminders,
        .photos, .camera, .microphone, .appleEvents, .screenCapture, .unknown("kTCCServiceFuture"),
    ]

    // MARK: Sentences (8.1)

    @Test("The microphone sentence matches Apple's wording (8.1)")
    func microphoneSentence() {
        #expect(PromptSummary.headline(service: .microphone, appName: "WardTrigger")
                == "Allow “WardTrigger” to access your microphone?")
    }

    @Test("Every service gets a question that names the app and avoids service keys (8.1)", arguments: services)
    func everyServiceReadsNaturally(service: TCCService) {
        let sentence = PromptSummary.headline(service: service, appName: "Cursor")
        #expect(sentence.hasPrefix("Allow “Cursor” to "))
        #expect(sentence.hasSuffix("?"))
        #expect(!sentence.contains("kTCC"))
    }

    @Test("Folder services name the folder (8.1)")
    func folderSentences() {
        #expect(PromptSummary.headline(service: .documentsFolder, appName: "Cursor").contains("Documents folder"))
        #expect(PromptSummary.headline(service: .desktopFolder, appName: "Cursor").contains("Desktop folder"))
        #expect(PromptSummary.headline(service: .downloadsFolder, appName: "Cursor").contains("Downloads folder"))
    }

    @Test("Without a name the sentence says an app, without quotes (8.2)")
    func unnamedApp() {
        #expect(PromptSummary.headline(service: .camera, appName: nil) == "Allow an app to access your camera?")
    }

    // MARK: Plist keys and bundle lookup (8.3, 8.4)

    @Test("Each known service has at least one usage description key; unknown has none (8.4)", arguments: services)
    func usageKeys(service: TCCService) {
        let keys = PromptSummary.usageDescriptionKeys(for: service)
        if case .unknown = service { #expect(keys.isEmpty) } else { #expect(!keys.isEmpty) }
    }

    @Test("The outermost .app is the bundle, and non-app paths have none (8.3)")
    func bundleLookup() {
        let helper = "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/Cursor Helper"
        #expect(AppBundleInfo.bundleURL(forExecutable: helper)?.path == "/Applications/Cursor.app")
        #expect(AppBundleInfo.bundleURL(forExecutable: "/opt/homebrew/bin/rg") == nil)
        #expect(AppBundleInfo.bundleURL(forExecutable: "<exited>") == nil)
        #expect(AppBundleInfo.bundleURL(forExecutable: "/tmp/.app/x") == nil)
    }

    @Test("The display name wins over the bundle name, and usage descriptions are collected (8.3, 8.4)")
    func plistValues() {
        let info = AppBundleInfo(values: [
            "CFBundleName": "plain", "CFBundleDisplayName": "Fancy Name",
            "NSMicrophoneUsageDescription": "Needed to record voice notes.",
            "NSCalendarsUsageDescription": "old", "NSCalendarsFullAccessUsageDescription": "full",
            "CFBundleVersion": "1",
        ])
        #expect(info.displayName == "Fancy Name")
        #expect(info.usageDescription(for: .microphone) == "Needed to record voice notes.")
        // The newer full-access key is preferred.
        #expect(info.usageDescription(for: .calendar) == "full")
        #expect(info.usageDescription(for: .camera) == nil)
        #expect(AppBundleInfo(values: ["CFBundleName": "Only"]).displayName == "Only")
    }

    @Test("A real Info.plist inside a temporary .app is read from disk (8.3, 8.4, 8.5)")
    func readsFromDisk() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ward-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = root.appendingPathComponent("Demo.app/Contents")
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleName": "Demo", "NSContactsUsageDescription": "To find your friends."]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))

        let executable = contents.appendingPathComponent("MacOS/Demo").path
        let info = try #require(AppBundleInfo.read(forExecutable: executable))
        #expect(info.displayName == "Demo")
        #expect(info.usageDescription(for: .addressBook) == "To find your friends.")
        // An app without a readable Info.plist gives nothing rather than failing.
        #expect(AppBundleInfo.read(forExecutable: root.appendingPathComponent("Missing.app/Contents/MacOS/x").path) == nil)
    }

    // MARK: Wiring into the HUD content (8.2)

    private func prompt(client: Int?, responsible: Int?, service: TCCService = .microphone) -> TCCPrompt {
        TCCPrompt(service: service, clientPID: client, responsiblePID: responsible, messageID: "1.1",
                  detectedAt: Date(timeIntervalSince1970: 0))
    }

    private func snapshot(_ pid: pid_t, _ name: String, path: String) -> ProcessSnapshot {
        ProcessSnapshot(pid: pid, name: name, executablePath: path, arguments: [name], workingDirectory: nil,
                        lineage: [ProcessNode(pid: pid, name: name, executablePath: path)])
    }

    @Test("A child under an app: the sentence names the responsible app and shows its reason (8.2, 8.4)")
    func namesTheResponsibleApp() {
        let content = HUDContent.build(
            prompt: prompt(client: 2, responsible: 1),
            inspect: { pid in
                pid == 1 ? snapshot(1, "Cursor", path: "/Applications/Cursor.app/Contents/MacOS/Cursor")
                         : snapshot(2, "rg", path: "/opt/homebrew/bin/rg")
            },
            bundleInfo: { path in
                path.contains("Cursor.app")
                    ? AppBundleInfo(displayName: "Cursor",
                                    usageDescriptions: ["NSMicrophoneUsageDescription": "For voice input."])
                    : nil
            })
        #expect(content.displayedRequest.headline == "Allow “Cursor” to access your microphone?")
        #expect(content.displayedRequest.purpose == "For voice input.")
    }

    @Test("A self-responsible tool without a bundle falls back to the process name (8.2, 8.3)")
    func fallsBackToProcessName() {
        let content = HUDContent.build(
            prompt: prompt(client: 7, responsible: 7),
            inspect: { snapshot($0, "rg", path: "/opt/homebrew/bin/rg") },
            bundleInfo: { _ in nil })
        #expect(content.displayedRequest.headline == "Allow “rg” to access your microphone?")
        #expect(content.displayedRequest.purpose == nil)
    }

    @Test("With no PID at all the sentence says an app (8.2)")
    func noProcess() {
        let content = HUDContent.build(prompt: prompt(client: nil, responsible: nil),
                                       inspect: { _ in Issue.record("must not inspect"); return snapshot(0, "x", path: "x") },
                                       bundleInfo: { _ in nil })
        #expect(content.displayedRequest.headline == "Allow an app to access your microphone?")
    }

    @Test("Hand-built content still shows a generic sentence (8.1)")
    func handBuiltContent() {
        let content = HUDContent(prompt: prompt(client: nil, responsible: nil, service: .documentsFolder),
                                 spirit: nil, masterApp: nil, riskTags: [], status: .veiled)
        #expect(content.requestText == nil)
        #expect(content.displayedRequest.headline == "Allow an app to access files in your Documents folder?")
    }
}
