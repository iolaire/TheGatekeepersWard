import Darwin
import Foundation

/// A Castle Keep palette role. Views turn these into colours via
/// `CastlePalette`; keeping them as an enum makes UI rules unit-testable.
enum CastleTone: Equatable, Sendable {
    /// Ghosts, body text.
    case spectralEctoplasm
    /// Headers, lineage nodes.
    case kiroViolet
    /// "Paused" badge, lantern glow.
    case torchlightAmber
    /// Risky arguments.
    case mischiefCrimson
    /// Borders, arrows.
    case wroughtIron
}

/// The HUD status line. Strings are the canonical copy from
/// `.kiro/steering/swiftui-hud-design.md` §7.
enum HUDStatus: Equatable, Sendable {
    /// The process is waiting on the prompt.
    case paused
    /// The process is waiting and has risky arguments.
    case suspicious
    /// The process exited before it could be inspected.
    case slipped
    /// The process could not be identified or inspected.
    case veiled

    /// The status text shown in the HUD.
    var text: String {
        switch self {
        case .paused: return "Spirit Paused at the Gate"
        case .suspicious: return "Suspicious Spirit at the Gate"
        case .slipped: return "Spirit Slipped Through Before Inspection"
        case .veiled: return "Spirit's Origins Are Veiled"
        }
    }

    /// The badge colour.
    var tone: CastleTone {
        self == .suspicious ? .mischiefCrimson : .torchlightAmber
    }
}

extension TCCService {
    /// The lore name of the protected resource. Documents, Contacts, Camera
    /// and Microphone use the canonical copy from steering §7; the steering
    /// has no names for the others, so they get descriptive ones.
    var vaultName: String {
        switch self {
        case .documentsFolder: return "Documents Vault"
        case .addressBook: return "Contacts Registry"
        case .camera: return "Seeing-Glass"
        case .microphone: return "Voice Chamber"
        case .desktopFolder: return "Desktop Vault"
        case .downloadsFolder: return "Downloads Vault"
        case .calendar: return "Calendar Scrolls"
        case .reminders: return "Reminders Ledger"
        case .photos: return "Portrait Gallery"
        case .screenCapture: return "Scrying Mirror"
        case .appleEvents: return "Automation Vault"
        case .unknown: return "Unknown Vault"
        }
    }
}

/// The SF Symbol and colour for a process in the lineage (steering §4).
struct SpiritIcon: Equatable, Sendable {
    /// SF Symbol name.
    let symbol: String
    /// Palette role.
    let tone: CastleTone

    private static let table: [(names: Set<String>, icon: SpiritIcon)] = [
        (["rg", "grep", "find", "fd"], SpiritIcon(symbol: "magnifyingglass", tone: .spectralEctoplasm)),
        (["bash", "zsh", "sh", "fish"], SpiritIcon(symbol: "key.fill", tone: .kiroViolet)),
        (["python", "python3", "ruby", "node", "bun"], SpiritIcon(symbol: "curlybraces", tone: .torchlightAmber)),
        (["curl", "wget", "nc", "ncat"], SpiritIcon(symbol: "antenna.radiowaves.left.and.right", tone: .mischiefCrimson)),
        (["git"], SpiritIcon(symbol: "arrow.triangle.branch", tone: .kiroViolet)),
        (["ssh", "scp", "sftp"], SpiritIcon(symbol: "lock.open.fill", tone: .torchlightAmber)),
    ]

    private static let agentNames = ["cursor", "claude", "kiro", "copilot"]

    /// Picks the icon for a process name (case-insensitive). AI agents match
    /// by prefix so `Cursor Helper` or `claude-code` still count.
    static func forProcess(named name: String) -> SpiritIcon {
        let lowered = name.lowercased()
        if let hit = table.first(where: { $0.names.contains(lowered) }) {
            return hit.icon
        }
        if agentNames.contains(where: { lowered.hasPrefix($0) }) {
            return SpiritIcon(symbol: "sparkles", tone: .kiroViolet)
        }
        return SpiritIcon(symbol: "app.dashed", tone: .spectralEctoplasm)
    }
}

/// Everything the HUD shows for one prompt. Built off the main thread.
struct HUDContent: Equatable, Sendable {
    /// The prompt being explained.
    let prompt: TCCPrompt
    /// The process that asked, when it could be identified.
    let spirit: ProcessSnapshot?
    /// The responsible app, when it differs from the spirit.
    let masterApp: ProcessNode?
    /// Flagged arguments of the spirit.
    let riskTags: [RiskTag]
    /// The status line.
    let status: HUDStatus

    /// Builds the content, inspecting the client (or, if unknown, the
    /// responsible) process.
    ///
    /// - Parameters:
    ///   - prompt: The detected prompt.
    ///   - inspect: The inspection function; injectable for tests.
    static func build(
        prompt: TCCPrompt,
        inspect: (pid_t) -> ProcessSnapshot = ProcessInspector.inspect
    ) -> HUDContent {
        guard let pid = prompt.clientPID ?? prompt.responsiblePID else {
            return HUDContent(prompt: prompt, spirit: nil, masterApp: nil, riskTags: [], status: .veiled)
        }
        let spirit = inspect(pid_t(pid))
        var masterApp: ProcessNode?
        if let responsible = prompt.responsiblePID, responsible != pid {
            let master = inspect(pid_t(responsible))
            masterApp = ProcessNode(pid: master.pid, name: master.name, executablePath: master.executablePath)
        }
        let tags = RiskTagger.tags(for: spirit.arguments)
        let status: HUDStatus
        if spirit.exitedBeforeInspection {
            status = .slipped
        } else if spirit.inspectionDenied {
            status = .veiled
        } else {
            status = tags.isEmpty ? .paused : .suspicious
        }
        return HUDContent(prompt: prompt, spirit: spirit, masterApp: masterApp, riskTags: tags, status: status)
    }
}

extension ProcessInspector {
    /// Builds HUD content on the inspector actor, off the main thread.
    func hudContent(for prompt: TCCPrompt) -> HUDContent {
        HUDContent.build(prompt: prompt)
    }
}
