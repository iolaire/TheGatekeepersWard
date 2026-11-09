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
    /// Open prompts, so each result only affects its own prompt.
    private var prompts = PromptTracker<HUDContent>()

    /// Creates the menu bar item and starts watching the TCC log.
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        hud = FortressHUDWindow()
        // The HUD gave up waiting: forget the prompts and settle the ghost.
        hud?.onAutoDismiss = { [weak self] in
            self?.prompts.expire()
            self?.menuBar?.endAlert()
        }
        watchTask = Task { [weak self] in
            guard let self else { return }
            await self.watcher.start()
            for await event in self.watcher.events {
                await self.handle(event)
            }
        }
        logger.info("Gatekeeper's Ward is watching")
    }

    /// Stops the `log stream` subprocess before quitting, without blocking the
    /// main thread: AppKit waits for `reply(toApplicationShouldTerminate:)`.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        watchTask?.cancel()
        let watcher = self.watcher
        Task {
            await watcher.stop()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    private func handle(_ event: TCCWatcherEvent) async {
        switch event {
        case .prompt(let prompt):
            let content = await ProcessInspector.shared.hudContent(for: prompt)
            logger.info("prompt for \(prompt.service.rawKey, privacy: .public)")
            apply(prompts.prompt(messageID: prompt.messageID, content: content))
            menuBar?.recordPrompt(RecentSpirit(
                name: content.spirit?.name ?? "unknown",
                vault: prompt.service.vaultName,
                date: prompt.detectedAt
            ))
        case .resolved(let result):
            apply(prompts.resolve(messageID: result.messageID))
        }
    }

    /// Moves the HUD and ghost to match a `PromptTracker` decision.
    private func apply(_ change: PromptTracker<HUDContent>.Change) {
        switch change {
        case .none:
            break
        case .show(let content):
            hud?.present(content)
        case .hide:
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
