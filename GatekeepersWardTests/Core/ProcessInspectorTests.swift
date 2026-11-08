import Darwin
import Foundation
import Testing
@testable import GatekeepersWard

/// Live tests for `ProcessInspector`. They inspect real processes the test
/// starts itself, so no TCC prompt or special permission is needed.
struct ProcessInspectorTests {
    @Test("Inspecting the test process returns its path, argv, cwd and lineage")
    func inspectsCurrentProcess() throws {
        let pid = getpid()
        let snapshot = ProcessInspector.inspect(pid: pid)
        #expect(!snapshot.exitedBeforeInspection)
        #expect(!snapshot.inspectionDenied)
        #expect(snapshot.executablePath.hasPrefix("/"))
        #expect(snapshot.arguments == CommandLine.arguments)
        #expect(snapshot.workingDirectory == FileManager.default.currentDirectoryPath)
        let last = try #require(snapshot.lineage.last)
        #expect(last.pid == pid)
        #expect(snapshot.lineage.contains { $0.pid == getppid() })
        #expect(!snapshot.lineage.contains { $0.pid == 1 })
    }

    @Test("A child process shows its own argv, cwd and the test process as parent")
    func inspectsChildProcess() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["5"]
        child.currentDirectoryURL = URL(fileURLWithPath: "/private/tmp")
        try child.run()
        defer { child.terminate() }

        let snapshot = ProcessInspector.inspect(pid: child.processIdentifier)
        #expect(snapshot.name == "sleep")
        #expect(snapshot.executablePath == "/bin/sleep")
        #expect(snapshot.arguments == ["/bin/sleep", "5"])
        #expect(snapshot.workingDirectory == "/private/tmp")
        let pids = snapshot.lineage.map(\.pid)
        #expect(pids.suffix(2) == [getpid(), child.processIdentifier])
    }

    @Test("An exited process degrades to an exited snapshot instead of failing")
    func exitedProcessDegrades() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try child.run()
        child.waitUntilExit()
        let snapshot = ProcessInspector.inspect(pid: child.processIdentifier)
        #expect(snapshot.exitedBeforeInspection)
        #expect(snapshot.arguments.isEmpty)
    }

    @Test("Invalid PIDs never crash", arguments: [pid_t(0), -1, pid_t.max])
    func invalidPIDs(pid: pid_t) {
        let snapshot = ProcessInspector.inspect(pid: pid)
        #expect(snapshot.exitedBeforeInspection)
    }

    @Test("A root-owned process is marked as denied, not exited")
    func otherUserProcessIsDenied() throws {
        // launchd (PID 1) is root-owned; its argv is not readable by us.
        let snapshot = ProcessInspector.inspect(pid: 1)
        #expect(!snapshot.exitedBeforeInspection)
        #expect(snapshot.inspectionDenied)
    }

    @Test("Command line quotes only arguments that need it")
    func commandLineQuoting() {
        let snapshot = ProcessSnapshot(
            pid: 1, name: "rg", executablePath: "/usr/local/bin/rg",
            arguments: ["rg", "AWS SECRET", "~/Documents", #"a"b"#],
            workingDirectory: nil, lineage: []
        )
        #expect(snapshot.commandLine == #"rg "AWS SECRET" ~/Documents "a\"b""#)
    }
}
