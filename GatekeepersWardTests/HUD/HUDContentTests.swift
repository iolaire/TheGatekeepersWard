import Darwin
import Foundation
import Testing
@testable import GatekeepersWard

/// Tests for the HUD's pure display rules.
struct HUDContentTests {
    private func prompt(client: Int?, responsible: Int?) -> TCCPrompt {
        TCCPrompt(service: .documentsFolder, clientPID: client, responsiblePID: responsible,
                  messageID: "1.1", detectedAt: Date(timeIntervalSince1970: 0))
    }

    private func snapshot(_ pid: pid_t, _ name: String, _ arguments: [String],
                          exited: Bool = false, denied: Bool = false) -> ProcessSnapshot {
        ProcessSnapshot(pid: pid, name: name, executablePath: "/bin/\(name)", arguments: arguments,
                        workingDirectory: nil, lineage: [], exitedBeforeInspection: exited,
                        inspectionDenied: denied)
    }

    @Test("Child under an agent: spirit is the child, master is the agent, risky args flagged")
    func childUnderAgent() {
        let content = HUDContent.build(prompt: prompt(client: 14582, responsible: 14201)) { pid in
            pid == 14582
                ? snapshot(pid, "rg", ["rg", "AWS_SECRET", "~/Documents/prod.env"])
                : snapshot(pid, "Cursor", ["Cursor"])
        }
        #expect(content.spirit?.name == "rg")
        #expect(content.masterApp?.name == "Cursor")
        #expect(content.riskTags.count == 2)
        #expect(content.status == .suspicious)
        #expect(content.status.text == "Suspicious Spirit at the Gate")
    }

    @Test("Self-responsible app has no separate master app")
    func selfResponsible() {
        let content = HUDContent.build(prompt: prompt(client: 7, responsible: 7)) {
            snapshot($0, "WardTrigger", ["WardTrigger", "docs"])
        }
        #expect(content.masterApp == nil)
        #expect(content.status == .paused)
    }

    @Test("Status reflects exited, denied and unknown processes")
    func degradedStatuses() {
        let exited = HUDContent.build(prompt: prompt(client: 5, responsible: nil)) {
            snapshot($0, "x", [], exited: true)
        }
        #expect(exited.status == .slipped)
        let denied = HUDContent.build(prompt: prompt(client: 5, responsible: nil)) {
            snapshot($0, "x", [], denied: true)
        }
        #expect(denied.status == .veiled)
        let unknown = HUDContent.build(prompt: prompt(client: nil, responsible: nil)) { _ in
            Issue.record("must not inspect without a PID")
            return snapshot(0, "x", [])
        }
        #expect(unknown.status == .veiled)
        #expect(unknown.spirit == nil)
    }

    @Test("Only the responsible PID known: inspect that app")
    func responsibleOnly() {
        let content = HUDContent.build(prompt: prompt(client: nil, responsible: 42)) {
            snapshot($0, "Cursor", ["Cursor"])
        }
        #expect(content.spirit?.pid == 42)
        #expect(content.masterApp == nil)
    }

    @Test("Spirit icons follow the steering table", arguments: [
        ("rg", "magnifyingglass"), ("zsh", "key.fill"), ("node", "curlybraces"),
        ("curl", "antenna.radiowaves.left.and.right"), ("git", "arrow.triangle.branch"),
        ("ssh", "lock.open.fill"), ("Cursor", "sparkles"), ("claude", "sparkles"),
        ("Cursor Helper (Plugin)", "sparkles"), ("WardTrigger", "app.dashed"),
    ])
    func spiritIcons(name: String, symbol: String) {
        #expect(SpiritIcon.forProcess(named: name).symbol == symbol)
    }

    @Test("Vault names use the canonical copy")
    func vaultNames() {
        #expect(TCCService.documentsFolder.vaultName == "Documents Vault")
        #expect(TCCService.addressBook.vaultName == "Contacts Registry")
        #expect(TCCService.microphone.vaultName == "Voice Chamber")
        #expect(TCCService(rawKey: "kTCCServiceCamera").vaultName == "Seeing-Glass")
        #expect(TCCService(rawKey: "kTCCServiceNew").vaultName == "Unknown Vault")
    }
}
