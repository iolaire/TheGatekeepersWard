import Darwin
import Foundation

/// One process in a lineage chain (e.g. `cursor`, `node`, `zsh`, `rg`).
struct ProcessNode: Equatable, Sendable {
    /// The process ID.
    let pid: pid_t
    /// Short display name: the executable's file name when known, otherwise
    /// the kernel's 16-character `p_comm` name.
    let name: String
    /// Full executable path, when the kernel reports one.
    let executablePath: String?
}

/// Everything Gatekeeper's Ward could learn about one process at the moment a
/// TCC prompt was on screen. Immutable; built by `ProcessInspector`.
struct ProcessSnapshot: Equatable, Sendable {
    /// The inspected process ID.
    let pid: pid_t
    /// Display name of the inspected process.
    let name: String
    /// Executable path, `"<exited>"` if the process was gone, or
    /// `"<restricted>"` if the kernel refused to describe it.
    let executablePath: String
    /// The argument vector (argv), including `argv[0]`. Empty when unknown.
    let arguments: [String]
    /// Current working directory, when readable.
    let workingDirectory: String?
    /// Ancestors first, inspected process last
    /// (e.g. `[cursor, node, zsh, rg]`). `launchd` is omitted.
    let lineage: [ProcessNode]
    /// `true` when the process had already exited before inspection ran.
    let exitedBeforeInspection: Bool
    /// `true` when the process exists but its arguments could not be read
    /// (for example, it belongs to another user).
    let inspectionDenied: Bool

    /// Creates a snapshot. Only `ProcessInspector` and tests construct these.
    init(
        pid: pid_t,
        name: String,
        executablePath: String,
        arguments: [String],
        workingDirectory: String?,
        lineage: [ProcessNode],
        exitedBeforeInspection: Bool = false,
        inspectionDenied: Bool = false
    ) {
        self.pid = pid
        self.name = name
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.lineage = lineage
        self.exitedBeforeInspection = exitedBeforeInspection
        self.inspectionDenied = inspectionDenied
    }

    /// The command line as a shell-like string, quoting arguments that
    /// contain spaces or quotes. Empty when the arguments are unknown.
    var commandLine: String {
        arguments.map(Self.shellQuoted).joined(separator: " ")
    }

    /// Quotes one argument for display if it contains characters a shell
    /// would split or interpret.
    static func shellQuoted(_ argument: String) -> String {
        let needsQuoting = argument.isEmpty || argument.contains { character in
            character.isWhitespace || "\"'\\$`".contains(character)
        }
        guard needsQuoting else { return argument }
        let escaped = argument
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
