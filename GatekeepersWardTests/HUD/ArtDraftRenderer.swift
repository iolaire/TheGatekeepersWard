import AppKit
import Foundation
import SwiftUI
import Testing
@testable import GatekeepersWard

/// Renders review images of the Castle Keep art into `docs/Planning/Styles/drafts/`.
///
/// Skipped unless `WARD_RENDER_DRAFTS=1`, so normal test runs write nothing:
///
///     WARD_RENDER_DRAFTS=1 swift test --filter ArtDraftRenderer
@Suite("ArtDraftRenderer", .enabled(if: ProcessInfo.processInfo.environment["WARD_RENDER_DRAFTS"] == "1"))
struct ArtDraftRenderer {
    private static let slate = CastleNSColors.obsidianSlate

    /// `docs/Planning/Styles/drafts` next to this repository's docs.
    private static var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/Planning/Styles/drafts", isDirectory: true)
    }

    @Test("Render the menu bar icon, the character sheet and the pair")
    func render() throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        try write(menuBarSheet(), named: "menubar-icon-poses.png")
        try write(characterSheet(), named: "character-sheet.png")
        try write(pairLogo(), named: "ghost-pair.png")
    }

    @Test("Render the Fortress HUD with no process and with sample data")
    @MainActor
    func renderHUD() throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        let prompt = TCCPrompt(service: .documentsFolder, clientPID: nil, responsiblePID: nil,
                               messageID: "1.1", detectedAt: Date(timeIntervalSince1970: 0))
        var empty = HUDContent(prompt: prompt, spirit: nil, masterApp: nil, riskTags: [], status: .veiled)
        empty.requestText = RequestText(headline: PromptSummary.headline(service: .microphone, appName: "WardTrigger"),
                                        purpose: "WardTrigger requests microphone access to trigger the Microphone TCC prompt for Gatekeeper's Ward testing.")
        try write(hudImage(empty), named: "hud-no-process.png")

        // Made-up data, only to show the layout.
        let lineage = [
            ProcessNode(pid: 14201, name: "Cursor", executablePath: nil),
            ProcessNode(pid: 14390, name: "node", executablePath: nil),
            ProcessNode(pid: 14471, name: "zsh", executablePath: nil),
            ProcessNode(pid: 14582, name: "rg", executablePath: nil),
        ]
        let arguments = ["rg", "AWS_SECRET", "/Users/dev/Documents", "--max-depth", "4", "production.env"]
        let spirit = ProcessSnapshot(pid: 14582, name: "rg", executablePath: "/opt/homebrew/bin/rg", arguments: arguments,
                                     workingDirectory: "/Users/dev/project", lineage: lineage)
        let tags = RiskTagger.tags(for: arguments)
        let master = ProcessNode(pid: 14201, name: "Cursor", executablePath: nil)
        var sample = HUDContent(prompt: prompt, spirit: spirit, masterApp: master, riskTags: tags, status: .suspicious)
        sample.requestText = RequestText(
            headline: "Allow “Cursor” to access files in your Documents folder?",
            purpose: "Cursor reads files in your projects to answer questions about your code.")
        try write(hudImage(sample), named: "hud-sample.png")

        // A long command: the command box grows to show it.
        let longArguments = ["rg", "-n", "--hidden", "--glob", "!node_modules", "--glob", "!.git",
                             "AWS_SECRET_ACCESS_KEY|aws_access_key_id|BEGIN RSA PRIVATE KEY", "/Users/dev/Documents/Work",
                             "/Users/dev/Documents/Personal", "/Users/dev/Documents/Taxes", "--max-depth", "6"]
        let longSpirit = ProcessSnapshot(pid: 14582, name: "rg", executablePath: "/opt/homebrew/bin/rg",
                                         arguments: longArguments, workingDirectory: "/Users/dev/project", lineage: lineage)
        var long = HUDContent(prompt: prompt, spirit: longSpirit, masterApp: master,
                              riskTags: RiskTagger.tags(for: longArguments), status: .suspicious)
        long.requestText = sample.requestText
        try write(hudImage(long), named: "hud-long-command.png")
    }

    /// Renders the HUD at 2x on a dark desktop-like backdrop.
    @MainActor
    private func hudImage(_ content: HUDContent) -> Data? {
        let view = FortressHUDView(content: content)
            .padding(24)
            .background(Color(white: 0.16))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    // MARK: - Files

    private func write(_ data: Data?, named name: String) throws {
        let png = try #require(data)
        try png.write(to: Self.outputDirectory.appendingPathComponent(name))
    }

    /// Draws into a fresh bitmap (one unit per pixel) and returns PNG data.
    private func bitmap(width: Int, height: Int, _ draw: () -> Void) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Menu bar poses

    /// Each pose on a dark and a light menu bar, enlarged 8x and at 2x (Retina) size.
    private func menuBarSheet() -> Data? {
        let poses: [(String, GhostIcon.Pose)] = [("idle", .idle), ("alert", .alert), ("alertBlink", .alertBlink)]
        let zoom: CGFloat = 8
        let cell = NSSize(width: 24 * zoom + 120, height: 22 * zoom + 40)
        let width = Int(cell.width * 3), height = Int(cell.height * 2 + 130)
        let bars = [NSColor(white: 0.11, alpha: 1), NSColor(white: 0.93, alpha: 1)]
        return bitmap(width: width, height: height) {
            NSColor(white: 0.5, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            for (row, bar) in bars.enumerated() {
                for (column, (name, pose)) in poses.enumerated() {
                    let origin = NSPoint(x: cell.width * CGFloat(column), y: CGFloat(height) - cell.height * CGFloat(row + 1))
                    bar.setFill()
                    NSRect(origin: origin, size: cell).fill()
                    GhostIcon.image(pose).draw(in: NSRect(x: origin.x + 20, y: origin.y + 20,
                                                          width: 24 * zoom, height: 22 * zoom))
                    label(name + (row == 0 ? " (dark bar)" : " (light bar)"), at: NSPoint(x: origin.x + 20, y: origin.y + 4),
                          color: row == 0 ? .white : .black, size: 13)
                }
            }
            // Real size at 2x pixel density (48 x 44 px), as a Retina menu bar shows it.
            for (column, (name, pose)) in poses.enumerated() {
                for (row, bar) in bars.enumerated() {
                    let origin = NSPoint(x: 20 + cell.width * CGFloat(column) + CGFloat(row) * 90, y: 60)
                    bar.setFill()
                    NSRect(x: origin.x - 6, y: origin.y - 6, width: 60, height: 56).fill()
                    GhostIcon.image(pose).draw(in: NSRect(x: origin.x, y: origin.y, width: 48, height: 44))
                }
                label(name + " at 2x pixel size", at: NSPoint(x: 20 + cell.width * CGFloat(column), y: 20), color: .white, size: 13)
            }
        }
    }

    // MARK: - Characters

    /// Both characters in every expression at full detail.
    private func characterSheet() -> Data? {
        let expressions: [(String, FaceExpression)] = [("happy", .happy), ("sleepy", .sleepy), ("surprised", .surprised)]
        let size: CGFloat = 300, margin: CGFloat = 30
        let width = Int(3 * (size + margin) + margin), height = Int(2 * (size + margin) + margin + 30)
        return bitmap(width: width, height: height) {
            Self.slate.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            for (row, kind) in [FigureKind.solo, .cloaked].enumerated() {
                for (column, (name, expression)) in expressions.enumerated() {
                    let frame = NSRect(x: margin + CGFloat(column) * (size + margin),
                                       y: CGFloat(height) - 30 - CGFloat(row + 1) * (size + margin),
                                       width: size, height: size)
                    FigureRenderer.draw(kind, expression, in: frame, detail: .full)
                    label("\(kind == .solo ? "solo" : "cloaked") · \(name)",
                          at: NSPoint(x: frame.minX, y: frame.minY - 22), color: CastleNSColors.spectralEctoplasm, size: 14)
                }
            }
        }
    }

    /// The pair together, as the HUD header logo will show it, at three sizes.
    private func pairLogo() -> Data? {
        let width = 900, height = 420
        return bitmap(width: width, height: height) {
            Self.slate.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            // Large pair with sparkles and wisps around it, then HUD header sizes.
            let large = NSRect(x: 230, y: 30, width: 360, height: 360)
            Sparkles.drawWisps(in: large)
            Sparkles.drawSparks(in: large)
            drawPair(at: large.origin, cloakedSize: large.width, expression: .happy)
            for (index, size) in [CGFloat(150), 96, 60].enumerated() {
                drawPair(at: NSPoint(x: 660 + CGFloat(index) * 60, y: 250 - CGFloat(index) * 90),
                         cloakedSize: size, expression: .happy)
            }
        }
    }

    /// The solo spirit in front of the cloaked spirit, as in the menu bar icon and HUD header.
    private func drawPair(at origin: NSPoint, cloakedSize c: CGFloat, expression: FaceExpression) {
        FigureRenderer.draw(.cloaked, expression, in: NSRect(x: origin.x, y: origin.y, width: c, height: c), detail: .full)
        FigureRenderer.draw(.solo, expression,
                            in: NSRect(x: origin.x - 0.358 * c, y: origin.y + 0.015 * c, width: 0.75 * c, height: 0.75 * c),
                            detail: .full)
    }

    private func label(_ text: String, at point: NSPoint, color: NSColor, size: CGFloat) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .regular),
            .foregroundColor: color,
        ])
    }
}
