import SwiftUI

/// Draws the Gate_Banner backdrop: a brick wall, an arched opening with a
/// violet portcullis, two torches, wisps and sparkles. Everything is vector
/// and uses only Castle Keep palette roles.
///
/// `time` drives the torch flicker and the sparkle twinkle; pass 0 for a
/// still image (Reduce Motion, tests).
enum GateScene {
    /// Radius of the arched opening.
    private static let archRadius: CGFloat = 52
    /// Spacing of the portcullis bars.
    private static let barSpacing: CGFloat = 14

    /// Paints the whole scene.
    static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        drawWall(&context, size: size)
        drawGate(&context, size: size)
        drawTorch(&context, x: 46, time: time, phase: 0)
        drawTorch(&context, x: size.width - 46, time: time, phase: 2.1)
        drawSparkles(&context, size: size, time: time)
    }

    // MARK: - Wall

    private static func drawWall(_ context: inout GraphicsContext, size: CGSize) {
        let slate = CastlePalette.obsidianSlate
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(slate))
        let rowHeight: CGFloat = 16, brickWidth: CGFloat = 36
        for row in 0...Int(size.height / rowHeight) {
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : -brickWidth / 2
            var column = 0
            while x < size.width {
                // A fixed pattern, so the wall looks hand-laid but never changes.
                let shade = Double((row * 7 + column * 13) % 5) / 5
                let rect = CGRect(x: x + 1, y: CGFloat(row) * rowHeight + 1, width: brickWidth - 2, height: rowHeight - 2)
                context.fill(Path(roundedRect: rect, cornerRadius: 2),
                             with: .color(CastleTone.wroughtIron.color.opacity(0.25 + 0.3 * shade)))
                x += brickWidth
                column += 1
            }
        }
        // Darken the outer edges so the gate and the figures stand out.
        let edge = slate.opacity(0.85)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(stops: [.init(color: edge, location: 0), .init(color: .clear, location: 0.3),
                             .init(color: .clear, location: 0.7), .init(color: edge, location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
    }

    // MARK: - Gate

    /// The arch outline: straight sides, then a round top built from two Bézier quarter arcs.
    private static func archPath(centerX: CGFloat, springY: CGFloat, bottom: CGFloat) -> Path {
        let r = archRadius, k = 0.5523 * archRadius
        var path = Path()
        path.move(to: CGPoint(x: centerX - r, y: bottom))
        path.addLine(to: CGPoint(x: centerX - r, y: springY))
        path.addCurve(to: CGPoint(x: centerX, y: springY - r),
                      control1: CGPoint(x: centerX - r, y: springY - k), control2: CGPoint(x: centerX - k, y: springY - r))
        path.addCurve(to: CGPoint(x: centerX + r, y: springY),
                      control1: CGPoint(x: centerX + k, y: springY - r), control2: CGPoint(x: centerX + r, y: springY - k))
        path.addLine(to: CGPoint(x: centerX + r, y: bottom))
        return path
    }

    /// The height of the arch's top edge above a given x.
    private static func archTop(x: CGFloat, centerX: CGFloat, springY: CGFloat) -> CGFloat {
        let dx = min(abs(x - centerX), archRadius)
        return springY - (archRadius * archRadius - dx * dx).squareRoot()
    }

    private static func drawGate(_ context: inout GraphicsContext, size: CGSize) {
        let centerX = size.width / 2, springY: CGFloat = 46
        let arch = archPath(centerX: centerX, springY: springY, bottom: size.height)
        let violet = CastleTone.kiroViolet.color
        // The dark opening, with a violet glow rising from the floor.
        context.fill(arch, with: .color(CastlePalette.obsidianSlate.opacity(0.94)))
        context.fill(arch, with: .linearGradient(
            Gradient(colors: [.clear, violet.opacity(0.3)]),
            startPoint: CGPoint(x: 0, y: springY), endPoint: CGPoint(x: 0, y: size.height)))
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: violet.opacity(0.9), radius: 5))
            layer.stroke(arch, with: .color(violet), lineWidth: 2.4)
            // Bars with spear tips.
            for index in -3...3 {
                let x = centerX + CGFloat(index) * barSpacing
                let top = archTop(x: x, centerX: centerX, springY: springY) + 12
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: size.height))
                bar.addLine(to: CGPoint(x: x, y: top))
                layer.stroke(bar, with: .color(violet), lineWidth: 2.2)
                var tip = Path()
                tip.move(to: CGPoint(x: x - 3.2, y: top))
                tip.addLine(to: CGPoint(x: x, y: top - 9))
                tip.addLine(to: CGPoint(x: x + 3.2, y: top))
                tip.closeSubpath()
                layer.fill(tip, with: .color(violet))
            }
            // Two cross rails and scrolls along the base.
            for y in [springY + 8, springY + 34] {
                var rail = Path()
                rail.move(to: CGPoint(x: centerX - archRadius + 4, y: y))
                rail.addLine(to: CGPoint(x: centerX + archRadius - 4, y: y))
                layer.stroke(rail, with: .color(violet), lineWidth: 2)
            }
            for index in -3..<3 {
                let x = centerX + (CGFloat(index) + 0.5) * barSpacing
                layer.stroke(Path(ellipseIn: CGRect(x: x - 3.4, y: size.height - 11, width: 6.8, height: 6.8)),
                             with: .color(violet.opacity(0.9)), lineWidth: 1.4)
            }
        }
    }

    // MARK: - Torches, wisps, sparkles

    private static func drawTorch(_ context: inout GraphicsContext, x: CGFloat, time: Double, phase: Double) {
        let amber = CastleTone.torchlightAmber.color
        let cupTop: CGFloat = 52
        // Two out-of-step sines make the flicker feel irregular.
        let flicker = time == 0 ? 0 : sin(time * 9 + phase) * 0.12 + sin(time * 5.3 + phase * 2) * 0.08
        let glowCenter = CGPoint(x: x, y: cupTop - 10)
        context.fill(Path(ellipseIn: CGRect(x: glowCenter.x - 36, y: glowCenter.y - 36, width: 72, height: 72)),
                     with: .radialGradient(Gradient(colors: [amber.opacity(0.45 + flicker), amber.opacity(0)]),
                                           center: glowCenter, startRadius: 0, endRadius: 36))
        // Bracket and cup.
        let iron = CastleTone.spectralEctoplasm.color.opacity(0.35)
        context.fill(Path(CGRect(x: x - 2.5, y: cupTop + 6, width: 5, height: 34)), with: .color(iron))
        var cup = Path()
        cup.move(to: CGPoint(x: x - 7, y: cupTop))
        cup.addLine(to: CGPoint(x: x + 7, y: cupTop))
        cup.addLine(to: CGPoint(x: x + 4, y: cupTop + 8))
        cup.addLine(to: CGPoint(x: x - 4, y: cupTop + 8))
        cup.closeSubpath()
        context.fill(cup, with: .color(iron))
        // Flame, and a lighter core.
        context.fill(flame(x: x, base: cupTop + 1, height: 22 * (1 + flicker), width: 7), with: .color(amber))
        context.fill(flame(x: x, base: cupTop, height: 12 * (1 + flicker), width: 3.6),
                     with: .color(CastleTone.spectralEctoplasm.color.opacity(0.85)))
    }

    /// A teardrop flame standing on `base`.
    private static func flame(x: CGFloat, base: CGFloat, height: CGFloat, width: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: x, y: base - height))
        path.addCurve(to: CGPoint(x: x + width, y: base - height * 0.27),
                      control1: CGPoint(x: x + width * 0.3, y: base - height * 0.64),
                      control2: CGPoint(x: x + width, y: base - height * 0.55))
        path.addCurve(to: CGPoint(x: x, y: base + 1),
                      control1: CGPoint(x: x + width, y: base - 1), control2: CGPoint(x: x + width * 0.4, y: base + 1))
        path.addCurve(to: CGPoint(x: x - width, y: base - height * 0.27),
                      control1: CGPoint(x: x - width * 0.4, y: base + 1), control2: CGPoint(x: x - width, y: base - 1))
        path.addCurve(to: CGPoint(x: x, y: base - height),
                      control1: CGPoint(x: x - width, y: base - height * 0.55),
                      control2: CGPoint(x: x - width * 0.3, y: base - height * 0.64))
        return path
    }

    private static func drawSparkles(_ context: inout GraphicsContext, size: CGSize, time: Double) {
        for (index, spark) in Sparkles.bannerSparks.enumerated() {
            let center = CGPoint(x: spark.x * size.width, y: (1 - spark.y) * size.height)
            let twinkle = time == 0 ? 1 : 0.6 + 0.4 * sin(time * 2.2 + Double(index) * 1.7)
            let color = spark.tone.castleTone.color
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: color.opacity(0.9), radius: 3))
                layer.fill(starPath(center: center, radius: spark.size * size.width), with: .color(color.opacity(twinkle)))
            }
        }
    }

    /// A four-point star.
    static func starPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            let length = index.isMultiple(of: 2) ? radius : radius * 0.3
            let point = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

extension Sparkles.Tone {
    /// The palette role for this sparkle colour.
    var castleTone: CastleTone {
        switch self {
        case .white: return .spectralEctoplasm
        case .violet: return .kiroViolet
        case .amber: return .torchlightAmber
        }
    }
}
