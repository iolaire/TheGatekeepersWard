import AppKit

/// One entry in the menu's recent-events list.
struct RecentSpirit: Equatable {
    /// Process name, e.g. `rg`.
    let name: String
    /// The vault it asked for.
    let vault: String
    /// When the prompt was seen.
    let date: Date
}

/// The menu bar ghost and its dropdown (`.kiro/steering/swiftui-hud-design.md` §6).
///
/// The ghost is a template image (`GhostIcon`) so macOS tints it for light
/// and dark menu bars. Idle: sleepy eyes. Alert: wide eyes, and the lantern
/// rises and falls every 0.8 s until the prompt resolves.
@MainActor
final class MenuBarController: NSObject {
    /// Maximum entries kept in the recent list.
    static let historyLimit = 10

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var history: [RecentSpirit] = []
    private var alertTimer: Timer?
    private var alertFrame = false

    /// Installs the status item in idle state.
    override init() {
        super.init()
        statusItem.button?.appearsDisabled = false
        setIcon(.idle, description: Self.idleDescription)
        rebuildMenu()
    }

    /// Adds a prompt to the history and switches the ghost to alert.
    func recordPrompt(_ spirit: RecentSpirit) {
        history.insert(spirit, at: 0)
        history = Array(history.prefix(Self.historyLimit))
        rebuildMenu()
        startAlert()
    }

    /// Returns the ghost to idle.
    func endAlert() {
        alertTimer?.invalidate()
        alertTimer = nil
        setIcon(.idle, description: Self.idleDescription)
    }

    private static let idleDescription = "Gatekeeper's Ward, watching"
    private static let alertDescription = "Gatekeeper's Ward, a spirit is at the gate"

    private func startAlert() {
        alertTimer?.invalidate()
        alertFrame = false
        setIcon(.alert, description: Self.alertDescription)
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.alertFrame.toggle()
                self.setIcon(self.alertFrame ? .alertBlink : .alert, description: Self.alertDescription)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        alertTimer = timer
    }

    private func setIcon(_ pose: GhostIcon.Pose, description: String) {
        let image = GhostIcon.image(pose)
        image.accessibilityDescription = description
        statusItem.button?.image = image
        statusItem.button?.toolTip = description
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "Recent Spirits", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        if history.isEmpty {
            let empty = NSMenuItem(title: "No Spirits Detected", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            for spirit in history {
                let when = formatter.localizedString(for: spirit.date, relativeTo: Date())
                let item = NSMenuItem(title: "\(spirit.name) → \(spirit.vault) (\(when))", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "").target = self
        menu.addItem(withTitle: "About Gatekeeper's Ward", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func clearHistory() {
        history.removeAll()
        rebuildMenu()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Gatekeeper's Ward",
            .credits: NSAttributedString(string: "Know who knocks before you drop the gates.\nhttps://github.com/iolaire/TheGatekeepersWard"),
        ])
    }
}
