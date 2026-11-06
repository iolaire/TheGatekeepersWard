import Foundation
import Testing

/// End-to-end smoke test that invokes the built WardTrigger binary directly
/// (Requirement 1.5: no arguments → exit code 1 + usage summary on stdout).
struct WardTriggerSmokeTests {
    /// Locates the built WardTrigger executable. Prefers the default SPM
    /// build layouts; falls back to asking the build system for the bin path.
    private static func binaryPath() -> String? {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // GatekeepersWardTests/WardTrigger/
            .deletingLastPathComponent() // GatekeepersWardTests/
            .deletingLastPathComponent() // repository root

        let candidates = [
            repoRoot.appendingPathComponent(".build/out/Products/Debug/WardTrigger"),
            repoRoot.appendingPathComponent(".build/debug/WardTrigger"),
            repoRoot.appendingPathComponent(".build/arm64-apple-macosx/debug/WardTrigger"),
        ]
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }

        // Fallback: ask swift build where the debug products live.
        let swiftBuild = Process()
        swiftBuild.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        swiftBuild.arguments = ["swift", "build", "--show-bin-path"]
        swiftBuild.currentDirectoryURL = repoRoot
        let pipe = Pipe()
        swiftBuild.standardOutput = pipe
        swiftBuild.standardError = FileHandle.nullDevice
        guard (try? swiftBuild.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        swiftBuild.waitUntilExit()
        guard swiftBuild.terminationStatus == 0 else { return nil }
        let binPath = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !binPath.isEmpty else { return nil }
        return URL(fileURLWithPath: binPath).appendingPathComponent("WardTrigger").path
    }

    @Test("Binary with no arguments exits 1 and prints the usage summary")
    func noArgumentsExitsWithCode1AndPrintsUsage() throws {
        let path = try #require(
            Self.binaryPath(),
            "WardTrigger binary not found — run `swift build` first"
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = []
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        #expect(process.terminationStatus == 1)
        let output = String(decoding: data, as: UTF8.self)
        #expect(output.contains("docs"))
        #expect(output.contains("contacts"))
        #expect(output.contains("mic"))
    }
}
