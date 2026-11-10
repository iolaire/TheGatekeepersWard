import SwiftUI

/// The illustrated strip at the top of the Fortress HUD: the gate scene with
/// three spirits floating in front of it.
///
/// Decorative, so hidden from VoiceOver. The torches flicker, the sparkles
/// twinkle and the spirits bob gently. With Reduce Motion on the timeline is
/// paused and the scene is drawn once, still. When the HUD is dismissed its
/// view tree is removed (see `FortressHUDWindow.dismiss()`), which stops the
/// animation.
struct GateBanner: View {
    /// Height of the banner in points.
    static let height: CGFloat = 88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { context, size in
                    var scene = context
                    GateScene.draw(&scene, size: size, time: time)
                }
                spirits(time: time)
            }
        }
        .frame(width: HUDMetrics.width, height: Self.height)
        .clipped()
        .accessibilityHidden(true)
    }

    /// The three floating spirits, each bobbing out of step with the others.
    private func spirits(time: Double) -> some View {
        ZStack {
            floating(.solo, .happy, size: 80, x: 118, y: 54, phase: 0, time: time)
            floating(.cloaked, .happy, size: 108, x: 210, y: 45, phase: 1.7, time: time)
            floating(.solo, .surprised, size: 54, x: 318, y: 32, phase: 3.1, time: time)
        }
    }

    private func floating(_ kind: FigureKind, _ expression: FaceExpression, size: CGFloat,
                          x: CGFloat, y: CGFloat, phase: Double, time: Double) -> some View {
        FigureImage(kind: kind, expression: expression, size: size)
            .position(x: x, y: y + CGFloat(sin(time * 1.5 + phase)) * 2.5)
    }
}
