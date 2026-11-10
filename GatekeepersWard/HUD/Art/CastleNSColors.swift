import AppKit

/// Fixed sRGB copies of the Castle Keep palette for AppKit drawing.
///
/// `CastlePalette` exposes SwiftUI colours only, and the menu bar icon and
/// figure renderer need `NSColor`. These are fixed values (never dynamic or
/// system colours) so drawings look identical under light and dark appearances.
enum CastleNSColors {
    /// Spectral Ectoplasm, `#E0E7FF`.
    static let spectralEctoplasm = srgb(0xE0, 0xE7, 0xFF)
    /// The Ectoplasm Shade, `#C7D2FE` (`CastleTone.ectoplasmShade`).
    static let ectoplasmShade = srgb(0xC7, 0xD2, 0xFE)
    /// Kiro Violet, `#8B5CF6`.
    static let kiroViolet = srgb(0x8B, 0x5C, 0xF6)
    /// Torchlight Amber, `#F59E0B`.
    static let torchlightAmber = srgb(0xF5, 0x9E, 0x0B)
    /// Obsidian Slate, `#0E1013`.
    static let obsidianSlate = srgb(0x0E, 0x10, 0x13)
    /// Mischief Crimson, `#F43F5E`.
    static let mischiefCrimson = srgb(0xF4, 0x3F, 0x5E)
    /// Spirit Ink, `#2E1065`: eyes, mouth and the inner outline of the spirits.
    static let spiritInk = srgb(0x2E, 0x10, 0x65)
    /// Midnight Violet, `#3B185F`: the outer outline of the spirits.
    static let midnightViolet = srgb(0x3B, 0x18, 0x5F)
    /// Blush Pink, `#F472B6`: the spirits' cheeks.
    static let blushPink = srgb(0xF4, 0x72, 0xB6)

    /// An opaque sRGB colour from 0–255 components.
    static func srgb(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}
