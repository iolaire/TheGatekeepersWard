import SwiftUI

/// The Castle Keep palette (`.kiro/steering/project.md`).
///
/// The steering doc asks for `Colors.xcassets`, but `swift build` cannot
/// compile asset catalogs, so the values live here instead. This is the only
/// place hex values appear; views use `CastleTone` roles.
enum CastlePalette {
    /// The colour for a palette role.
    static func color(_ tone: CastleTone) -> Color {
        switch tone {
        case .spectralEctoplasm: return rgb(0xE0, 0xE7, 0xFF)
        case .ectoplasmShade: return rgb(0xC7, 0xD2, 0xFE)
        case .kiroViolet: return rgb(0x8B, 0x5C, 0xF6)
        case .torchlightAmber: return rgb(0xF5, 0x9E, 0x0B)
        case .mischiefCrimson: return rgb(0xF4, 0x3F, 0x5E)
        case .wroughtIron: return rgb(0x2D, 0x31, 0x39)
        }
    }

    /// Panel background, `#0E1013`.
    static let obsidianSlate = rgb(0x0E, 0x10, 0x13)

    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }
}

extension CastleTone {
    /// The SwiftUI colour for this role.
    var color: Color { CastlePalette.color(self) }
}
