import AppKit
import Foundation
import SwiftUI
import Testing
@testable import GatekeepersWard

/// Unit tests for the Fortress HUD panel's focus-safety configuration and sizing.
@MainActor
struct FortressHUDWindowTests {
    private let prompt = TCCPrompt(service: .documentsFolder, clientPID: nil, responsiblePID: nil,
                                   messageID: "1.1", detectedAt: Date(timeIntervalSince1970: 0))

    /// Smallest content: no process identified, so only header and status show.
    private func smallContent() -> HUDContent {
        HUDContent(prompt: prompt, spirit: nil, masterApp: nil, riskTags: [], status: .veiled)
    }

    /// Larger content: a spirit with a lineage, a long command and a working directory.
    private func largeContent() -> HUDContent {
        let lineage = (1...3).map { ProcessNode(pid: pid_t($0), name: "proc\($0)", executablePath: "/bin/proc\($0)") }
        let args = ["rg"] + (0..<40).map { "--argument-number-\($0)" }
        let spirit = ProcessSnapshot(pid: 99, name: "rg", executablePath: "/bin/rg", arguments: args,
                                     workingDirectory: "/Users/test/project", lineage: lineage,
                                     exitedBeforeInspection: false, inspectionDenied: false)
        return HUDContent(prompt: prompt, spirit: spirit, masterApp: nil, riskTags: [], status: .paused)
    }

    private func fittingSize(of content: HUDContent) -> CGSize {
        let hosting = NSHostingView(rootView: FortressHUDView(content: content))
        hosting.layoutSubtreeIfNeeded()
        return hosting.fittingSize
    }

    @Test("Panel never steals focus: style mask, level, key and main flags")
    func focusSafeConfiguration() {
        let window = FortressHUDWindow()
        #expect(window.styleMask.contains(.nonactivatingPanel))
        #expect(window.styleMask.contains(.borderless))
        #expect(window.level == .floating)
        #expect(window.canBecomeKey == false)
        #expect(window.canBecomeMain == false)
    }

    @Test("Presenting twice with different content sizes uses each size")
    func presentUsesEachContentSize() {
        let window = FortressHUDWindow()
        defer { window.dismiss(); window.orderOut(nil) }

        let small = smallContent()
        let large = largeContent()
        let smallSize = fittingSize(of: small)
        let largeSize = fittingSize(of: large)
        #expect(smallSize != largeSize)

        window.present(small)
        #expect(window.frame.size == smallSize)

        window.present(large)
        #expect(window.frame.size == largeSize)
    }
}
