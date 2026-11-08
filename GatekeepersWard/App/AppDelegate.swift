import AppKit
import os

private let logger = Logger(subsystem: "com.gatekeepersward.app", category: "App")

/// Connects the pieces: `TCCWatcher` → `ProcessInspector` → HUD and menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let watcher = TCCWatcher()
    private var menuBar: MenuBarController?
    private var hud: FortressHUDWindow?
    private var watchTask: Task<Void, Never>?
    /// `msgID` of the prompt the HUD is showing, so only its result hides it.
    private var shownMessageID: String?

    /// Creates the menu bar item and starts watching the TCC log.
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        hud = FortressHUDWindow()
        watchTask = Task { [weak self] in
            guard let self else { return }
            await self.watcher.start()
            for await event in self.watcher.events {
                await self.handle(event)
            }
        }
        logger.info("Gatekeeper's Ward is watching")
    }

    /// Stops the `log stream` subprocess.
    func applicationWillTerminate(_ notification: Notification) {
        watchTask?.cancel()
        let watcher = self.watcher
        // Best effort: terminate the child before the process exits.
        let done = DispatchSemaphore(value: 0)
        Task.detached {   // detached: the main actor is blocked by wait() below
            await watcher.stop()
            done.signal()
        }
        _ = done.wait(timeout: .now() + 1)
    }

    private func handle(_ event: TCCWatcherEvent) async {
        switch event {
        case .prompt(let prompt):
            let content = await ProcessInspector.shared.hudContent(for: prompt)
            logger.info("prompt for \(prompt.service.rawKey, privacy: .public)")
            shownMessageID = prompt.messageID
            hud?.present(content)
            menuBar?.recordPrompt(RecentSpirit(
                name: content.spirit?.name ?? "unknown",
                vault: prompt.service.vaultName,
                date: prompt.detectedAt
            ))
        case .resolved(let result):
            guard result.messageID == shownMessageID else { return }
            shownMessageID = nil
            hud?.dismiss()
            menuBar?.endAlert()
        }
    }
}

/// Public entry point used by the `GatekeepersWardApp` executable.
public enum GatekeepersWardApp {
    /// Runs the menu bar app. Never returns.
    @MainActor
    public static func run() -> Never {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
        // `kill`/`pkill` send SIGTERM, which would end the process without
        // applicationWillTerminate and orphan the `log stream` child. Route it
        // through a normal quit instead.
        signal(SIGTERM, SIG_IGN)
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler { NSApp.terminate(nil) }
        termSource.resume()
        withExtendedLifetime(termSource) { app.run() }
        exit(0)
    }
}
