import Darwin
import Foundation
import os

private let logger = Logger(subsystem: "com.gatekeepersward.app", category: "ProcessInspector")

/// Reads process details with public Darwin APIs only: `sysctl` and
/// `libproc`. No entitlements, no `task_for_pid`, no signals. Read-only.
///
/// While a TCC prompt is on screen the requesting process is blocked inside
/// `tccd`, so it is still in the process table when this runs.
actor ProcessInspector {
    /// Shared instance; the inspector holds no state, so one is enough.
    static let shared = ProcessInspector()

    /// Upper bound on lineage depth, guarding against PID reuse loops.
    static let maximumLineageDepth = 32

    /// Builds a snapshot of `pid`, degrading instead of failing.
    ///
    /// - Parameter pid: The process to inspect.
    /// - Returns: A snapshot. If the process is gone, `exitedBeforeInspection`
    ///   is `true`; if it exists but its arguments are unreadable,
    ///   `inspectionDenied` is `true`.
    func snapshot(pid: pid_t) -> ProcessSnapshot {
        Self.inspect(pid: pid)
    }

    /// Synchronous implementation of `snapshot(pid:)`, usable from tests.
    static func inspect(pid: pid_t) -> ProcessSnapshot {
        guard pid > 0, let info = kernelInfo(pid: pid) else {
            return ProcessSnapshot(
                pid: pid, name: "<exited>", executablePath: "<exited>",
                arguments: [], workingDirectory: nil, lineage: [],
                exitedBeforeInspection: true
            )
        }
        let path = executablePath(pid: pid)
        let procArgs = processArguments(pid: pid)
        let name = displayName(path: path ?? procArgs?.executablePath, fallback: info.command)
        return ProcessSnapshot(
            pid: pid,
            name: name,
            executablePath: path ?? procArgs?.executablePath ?? "<restricted>",
            arguments: procArgs?.arguments ?? [],
            workingDirectory: workingDirectory(pid: pid),
            lineage: lineage(of: pid),
            inspectionDenied: procArgs == nil
        )
    }

    /// The ancestor chain of `pid`, oldest first and `pid` last. Stops at
    /// `launchd` (PID 1), which is not included.
    static func lineage(of pid: pid_t) -> [ProcessNode] {
        var chain: [ProcessNode] = []
        var visited: Set<pid_t> = []
        var current = pid
        while current > 1, chain.count < maximumLineageDepth, visited.insert(current).inserted,
              let info = kernelInfo(pid: current) {
            let path = executablePath(pid: current)
            chain.append(ProcessNode(
                pid: current,
                name: displayName(path: path, fallback: info.command),
                executablePath: path
            ))
            current = info.parentPID
        }
        return chain.reversed()
    }

    /// The parent PID and kernel command name of a process.
    struct KernelInfo: Equatable {
        /// Parent process ID (`e_ppid`).
        let parentPID: pid_t
        /// Kernel short name (`p_comm`, at most 16 bytes).
        let command: String
    }

    /// Reads `kinfo_proc` via `sysctl(CTL_KERN, KERN_PROC, KERN_PROC_PID)`.
    ///
    /// - Returns: `nil` when the process does not exist.
    static func kernelInfo(pid: pid_t) -> KernelInfo? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0,
              size == MemoryLayout<kinfo_proc>.stride
        else { return nil }   // size 0 means no such process
        let command = withUnsafeBytes(of: info.kp_proc.p_comm) { raw -> String in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
        return KernelInfo(parentPID: info.kp_eproc.e_ppid, command: command)
    }

    /// Reads and parses `sysctl(KERN_PROCARGS2)` with the two-phase
    /// size-then-fetch pattern.
    ///
    /// - Returns: `nil` when the kernel refuses (other-user process) or the
    ///   process has exited.
    static func processArguments(pid: pid_t) -> ProcArgsResult? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            logger.debug("KERN_PROCARGS2 size query failed for pid \(pid, privacy: .public): errno \(errno, privacy: .public)")
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &size, nil, 0) == 0 else {
            logger.debug("KERN_PROCARGS2 fetch failed for pid \(pid, privacy: .public): errno \(errno, privacy: .public)")
            return nil
        }
        return parseProcArgsBuffer(Array(buffer.prefix(size)))
    }

    /// Reads the executable path with `proc_pidpath`.
    static func executablePath(pid: pid_t) -> String? {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = buffer.withUnsafeMutableBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return 0 }
            return proc_pidpath(pid, base, UInt32(raw.count))
        }
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)), as: UTF8.self)
    }

    /// Reads the current working directory with
    /// `proc_pidinfo(PROC_PIDVNODEPATHINFO)`.
    ///
    /// - Returns: `nil` for other-user processes (`EPERM`) or exited ones.
    static func workingDirectory(pid: pid_t) -> String? {
        var info = proc_vnodepathinfo()
        let expected = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, expected) == expected else {
            return nil
        }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw -> String in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return path.isEmpty ? nil : path
    }

    /// The file name of `path`, or `fallback` when the path is unknown.
    static func displayName(path: String?, fallback: String) -> String {
        guard let path, !path.isEmpty else { return fallback }
        let name = (path as NSString).lastPathComponent
        return name.isEmpty ? fallback : name
    }
}
