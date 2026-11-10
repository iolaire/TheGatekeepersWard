import AppKit
import Foundation
import SwiftUI
import Testing
@testable import GatekeepersWard

/// Tests for the pure helpers behind the HUD sections, and for the card's natural size.
@MainActor
@Suite("HUD sections")
struct HUDSectionTests {
    private let prompt = TCCPrompt(service: .documentsFolder, clientPID: nil, responsiblePID: nil,
                                   messageID: "1.1", detectedAt: Date(timeIntervalSince1970: 0))

    private func chain(_ count: Int) -> [ProcessNode] {
        (1...count).map { ProcessNode(pid: pid_t($0), name: "proc\($0)", executablePath: nil) }
    }

    private func content(lineage: [ProcessNode], arguments: [String], master: ProcessNode? = nil) -> HUDContent {
        let spirit = ProcessSnapshot(pid: 99, name: "rg", executablePath: "/bin/rg", arguments: arguments,
                                     workingDirectory: "/Users/test/project", lineage: lineage)
        let tags = RiskTagger.tags(for: arguments)
        return HUDContent(prompt: prompt, spirit: spirit, masterApp: master, riskTags: tags,
                          status: tags.isEmpty ? .paused : .suspicious)
    }

    /// The height the card wants when nothing clamps it, and its width.
    private func naturalSize(of content: HUDContent) -> CGSize {
        let hosting = NSHostingView(rootView: FortressHUDView(content: content, maxHeight: .infinity))
        hosting.layoutSubtreeIfNeeded()
        return hosting.fittingSize
    }

    // MARK: Size (3.9)

    @Test("The card is 400 pt wide; typical content stays under 720 pt and the worst case under the 900 pt cap (3.9)")
    func fitsTheBudget() {
        let risky = ["rg", "AWS_SECRET", "/Users/dev/Documents", "--max-depth", "4", "production.env", "id_rsa"]
        let reason = "WardTrigger requests microphone access to trigger the Microphone prompt for testing."
        func withRequest(_ content: HUDContent) -> HUDContent {
            var copy = content
            copy.requestText = RequestText(headline: "Allow “WardTrigger” to access your microphone?", purpose: reason)
            return copy
        }
        let cases: [(String, HUDContent, CGFloat)] = [
            ("no process", withRequest(HUDContent(prompt: prompt, spirit: nil, masterApp: nil, riskTags: [], status: .veiled)), 720),
            ("typical", withRequest(content(lineage: chain(4), arguments: risky, master: chain(1)[0])), 720),
            ("long chain and command", withRequest(content(
                lineage: chain(14), arguments: risky + Array(repeating: "--flag-value", count: 40),
                master: ProcessNode(pid: 500, name: "Terminal", executablePath: nil))), HUDMetrics.maxHeight),
        ]
        for (name, content, limit) in cases {
            let size = naturalSize(of: content)
            #expect(size.width == HUDMetrics.width, "\(name) width")
            #expect(size.height <= limit, "\(name) height \(size.height)")
        }
    }

    @Test("A longer command makes the card taller instead of cutting the command off (3.8)")
    func commandGrows() {
        let short = naturalSize(of: content(lineage: chain(3), arguments: ["rg", "pattern"]))
        let medium = naturalSize(of: content(lineage: chain(3),
                                             arguments: ["rg"] + Array(repeating: "--some-longer-flag-name", count: 8)))
        let long = naturalSize(of: content(lineage: chain(3),
                                           arguments: ["rg"] + Array(repeating: "--some-longer-flag-name", count: 24)))
        #expect(medium.height > short.height)
        #expect(long.height > medium.height)
    }

    // MARK: Lineage (3.5)

    @Test("A short chain shows every process, indented one level per row (3.5)")
    func shortChain() {
        let rows = LineageLayout.rows(for: chain(4))
        #expect(rows.count == 4)
        for (index, row) in rows.enumerated() {
            guard case .process(_, let depth, let isRequester) = row else {
                Issue.record("unexpected summary row")
                return
            }
            #expect(depth == min(index, LineageLayout.maxDepth))
            #expect(isRequester == (index == 3))
        }
    }

    @Test("A long chain keeps the first process, a summary and the last few, asker last (3.5)")
    func longChain() {
        let lineage = chain(14)
        let rows = LineageLayout.rows(for: lineage)
        #expect(rows.count == LineageLayout.maxRows)
        let tail = LineageLayout.maxRows - 2
        #expect(rows[1] == .hidden(count: 14 - 1 - tail, depth: 1))
        guard case .process(let first, _, _) = rows[0], case .process(let last, _, let isRequester) = rows[LineageLayout.maxRows - 1] else {
            Issue.record("unexpected rows")
            return
        }
        #expect(first == lineage[0])
        #expect(last == lineage[13])
        #expect(isRequester)
    }

    @Test("Indentation never exceeds the maximum depth (3.5)")
    func depthIsCapped() {
        for row in LineageLayout.rows(for: chain(30)) {
            switch row {
            case .process(_, let depth, _), .hidden(_, let depth): #expect(depth <= LineageLayout.maxDepth)
            }
        }
    }

    @Test("An empty chain has no rows (3.5)")
    func emptyChain() {
        #expect(LineageLayout.rows(for: []).isEmpty)
    }

    // MARK: Master app line

    @Test("The master app line is hidden when it is the first process of the lineage")
    func masterAppDedup() {
        let lineage = chain(3)
        #expect(content(lineage: lineage, arguments: ["rg"], master: lineage[0]).visibleMasterApp == nil)
        let other = ProcessNode(pid: 500, name: "Terminal", executablePath: nil)
        #expect(content(lineage: lineage, arguments: ["rg"], master: other).visibleMasterApp == other)
        #expect(content(lineage: lineage, arguments: ["rg"]).visibleMasterApp == nil)
    }

    // MARK: Risk legend (3.7)

    @Test("The legend lists each present category once, in a fixed order (3.7)")
    func legendRows() {
        let tags = RiskTagger.tags(for: ["curl", "id_rsa", "x.pem", "base64", ".ssh"])
        let rows = RiskLegend.rows(for: tags)
        #expect(rows.map(\.category) == [.credentialFile, .secretPath, .networkTool, .encoding])
        #expect(Set(rows.map(\.label)).count == rows.count)
    }

    @Test("The legend is empty when nothing was flagged (3.7)")
    func legendEmpty() {
        #expect(RiskLegend.rows(for: []).isEmpty)
        #expect(RiskLegend.rows(for: RiskTagger.tags(for: ["rg", "hello"])).isEmpty)
    }

    // MARK: Instruction pills (4.1 to 4.5)

    @Test("The pills carry the canonical copy and colours (4.1, 4.2)")
    func pillCopy() {
        #expect(InstructionCopy.caption == "Answer in Apple's dialog")
        #expect(InstructionCopy.pills.map(\.meaning) == ["Lower Portcullis", "Let Spirit Pass"])
        #expect(InstructionCopy.pills.map(\.tone) == [.mischiefCrimson, .torchlightAmber])
    }

    @Test("The pills never use Block or Banish wording (4.4)")
    func pillWording() {
        let text = (InstructionCopy.pills.flatMap { [$0.appleButton, $0.meaning] } + [InstructionCopy.caption,
                                                                                       InstructionCopy.accessibilityLabel])
            .joined(separator: " ")
        #expect(!text.contains("Block"))
        #expect(!text.contains("Banish"))
    }

    @Test("VoiceOver reads the pills as one sentence (4.5)")
    func pillAccessibility() {
        let label = InstructionCopy.accessibilityLabel
        #expect(label.contains("Answer in Apple's dialog"))
        #expect(label.contains("Lower Portcullis"))
        #expect(label.contains("Let Spirit Pass"))
    }
}
