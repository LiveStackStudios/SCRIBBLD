import SwiftUI

/// Button surfaces that read as "filled with a marker / colored pencil",
/// not as a thin tint behind text. The previous implementation used a
/// 12% watercolor wash which made every CTA look empty on device — the
/// reference SCRIBBLD mockups show buttons with a clear *solid fill*
/// PLUS sparse hand-drawn stroke marks across the fill, suggesting
/// the surface was colored in with a wide marker.
///
/// Composition:
///   1. Solid base color (90%+ opacity, slightly varied on press)
///   2. `DiagonalPencilHatch` — dense parallel diagonal pencil
///      strokes with per-stroke pressure variation. Strokes overflow
///      the button bounds by ~3pt for the "colored outside the
///      lines" effect from the reference hangman pole shading.
///   3. `SketchBorderShape` outline in a darker shade of the fill.
///   4. Label text in cream (light) since the surface is now colored.

/// Standard primary CTA. Used for "Start Game", "Send Invite", lobby
/// host's "Start Game", "Join Game" — anything that's the main action
/// on a screen.
struct PencilButtonStyle: ButtonStyle {
    var color: Color = .inkBlue
    var textColor: Color = .cream
    var height: CGFloat = 54
    var cornerRadius: CGFloat = Radius.button
    var seed: UInt64 = 42

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caveat(24, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(PencilFilledSurface(color: color,
                                             cornerRadius: cornerRadius,
                                             seed: seed,
                                             pressed: configuration.isPressed))
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Emphasis variant — bigger text, taller surface — for the in-game
/// "¡STOP!" and lobby Start Game.
struct PencilButtonFilledStyle: ButtonStyle {
    var color: Color = .redPen
    var textColor: Color = .cream
    var height: CGFloat = 60
    var cornerRadius: CGFloat = Radius.button
    var seed: UInt64 = 71

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caveat(30, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(PencilFilledSurface(color: color,
                                             cornerRadius: cornerRadius,
                                             seed: seed,
                                             pressed: configuration.isPressed))
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Shared background composition: a colored-pencil "filled in" panel.
/// Used by both the button styles AND any other selected/active
/// surface that wants the same look (segmented pickers, pricing
/// tiles, lobby slots…). Apply via `.pencilFill(color:…)` modifier
/// — see bottom of file.
///
/// Layers (bottom → top):
///   1. Solid color fill — `color` shifted ~8% darker so the surface
///      reads as deliberately filled, not the original brand color.
///   2. `DiagonalPencilHatch` — close-spaced wobbly diagonal strokes
///      with per-stroke pressure variation, drawn in a frame inflated
///      by ~3pt via negative padding so strokes "color outside the
///      lines" like a real colored pencil.
///   3. Sketched outline at the natural bounds, on top of the hatch,
///      so the visible border separates fill from pencil bleed.
struct PencilFilledSurface: View {
    let color: Color
    var cornerRadius: CGFloat = Radius.button
    var seed: UInt64 = 42
    /// Pass `true` only when used as a *button* background to add the
    /// subtle press-feedback opacity dip. Static surfaces pass false.
    var pressed: Bool = false

    /// How far the hatch overflows past the button bounds. ~3pt is
    /// the sweet spot for "colored slightly outside the lines."
    private let overflow: CGFloat = 3

    /// Base fill is the brand color exactly as passed — no darkening.
    /// The "colored in" feel comes from the darker pencil strokes on
    /// top, not from a darker base.
    private var baseFill: Color { color }
    /// Hatch + outline shade — noticeably darker so each individual
    /// pencil stroke is clearly visible against the brand-color fill.
    /// Per design feedback: it's the STROKES that should read as
    /// darker pencil pressure, not the surface.
    private var darker: Color { color.adjustedBrightness(by: -0.35) }

    var body: some View {
        ZStack {
            // 1. Solid color base — clipped to the surface shape so
            //    the fill itself stays inside the border.
            (pressed ? baseFill.opacity(0.88) : baseFill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // 2. Dense diagonal pencil hatching in a darker tone.
            //    Negative padding expands the drawing frame past the
            //    button bounds so individual strokes visibly cross
            //    the border — the "colored outside the lines" effect.
            DiagonalPencilHatch(color: darker, seed: seed)
                .padding(-overflow)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // 3. Wobbly border on top — darker shade so the outline
            //    is clearly visible separating fill from overflow.
            SketchBorderShape(cornerRadius: cornerRadius, jitter: 1.6, seed: seed &+ 17)
                .stroke(
                    darker,
                    style: SwiftUI.StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )
        }
    }
}

/// Dense diagonal pencil hatching — the colored-pencil "fill in" look.
/// Strokes are wobbly, closely spaced, and vary in width + opacity
/// (simulating pressure variation as the pencil moves). Each stroke
/// starts and ends WAY outside the bounding box, then the host view's
/// frame crops them — so the strokes naturally come in and go out at
/// random angles relative to the visible edge, like a real hand-drawn
/// shading pass. Endpoints never "sit" at the border.
struct DiagonalPencilHatch: View {
    var color: Color
    var seed: UInt64
    /// Average gap between parallel strokes. Smaller = denser shading.
    var spacing: CGFloat = 4.5
    /// Stroke angle, in degrees clockwise from horizontal. 38° matches
    /// the reference hangman pole shading.
    var angle: CGFloat = 38

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                var rng = SeededRandom(seed: seed)
                let rad = angle * .pi / 180
                let dx = cos(rad)
                let dy = sin(rad)
                // Perpendicular to the stroke direction — used to
                // step from one parallel stroke to the next.
                let px = -dy
                let py = dx
                // Long enough that every stroke starts/ends past the
                // bounding box, regardless of orientation.
                let extent = sqrt(size.width * size.width + size.height * size.height) + 16

                // Step from -diag to +diag in `spacing` increments.
                var offset: CGFloat = -extent
                while offset < extent {
                    // Center of this stroke, offset perpendicular to
                    // the stroke direction by `offset`.
                    let cx = size.width / 2 + px * offset
                    let cy = size.height / 2 + py * offset
                    // Endpoints far outside the bounding box so the
                    // visible stroke section enters and exits the
                    // canvas naturally.
                    let start = CGPoint(x: cx - dx * extent, y: cy - dy * extent)
                    let end   = CGPoint(x: cx + dx * extent, y: cy + dy * extent)

                    let path = HandDrawn.wobblyPath(
                        from: start, to: end,
                        wobble: 0.9, segmentLength: 14, rng: &rng
                    )
                    // Pressure variation per stroke: random opacity
                    // 0.18–0.55 and random width 0.7–1.4 mimic the
                    // way a real pencil presses harder/lighter as
                    // your hand moves.
                    let opacity = rng.next(0.18, 0.55)
                    let lineWidth = rng.next(0.7, 1.4)
                    ctx.stroke(
                        path,
                        with: .color(color.opacity(Double(opacity))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    // Random per-step jitter so the spacing isn't a
                    // perfect picket fence — reads more handmade.
                    offset += spacing + rng.next(-0.9, 0.9)
                }
            }
            // Tiny blur softens the strokes just enough that they
            // read as pencil grain rather than razor-sharp ink.
            .blur(radius: 0.4)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private extension Color {
    /// HSB brightness shift — used for the darker outline and the
    /// marker-stroke overlay color.
    func adjustedBrightness(by delta: CGFloat) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s),
                     brightness: Double(max(0, min(1, b + delta))),
                     opacity: Double(a))
    }
}

extension View {
    /// Apply colored-pencil styling to a button's label. Use when you
    /// have a `Button { … } label: { Text(…) }` and want the sketch
    /// feel without rewriting the button as a custom view.
    func pencilButton(
        color: Color = .inkBlue,
        height: CGFloat = 54,
        cornerRadius: CGFloat = Radius.button,
        seed: UInt64 = 42
    ) -> some View {
        buttonStyle(PencilButtonStyle(
            color: color,
            height: height,
            cornerRadius: cornerRadius,
            seed: seed
        ))
    }

    /// Apply the colored-pencil hatch surface as a `.background(...)`
    /// on any view — segmented picker pills, pricing tiles, lobby
    /// slots — anywhere we want "this option is selected" to read as
    /// a deliberately colored-in surface.
    func pencilFill(
        color: Color = .inkBlue,
        cornerRadius: CGFloat = Radius.button,
        seed: UInt64 = 42
    ) -> some View {
        background(
            PencilFilledSurface(
                color: color,
                cornerRadius: cornerRadius,
                seed: seed,
                pressed: false
            )
        )
    }
}

#Preview {
    VStack(spacing: 18) {
        Button("Start Game") {}.buttonStyle(PencilButtonStyle(color: .inkBlue, seed: 1))
        Button("Send Invite") {}.buttonStyle(PencilButtonStyle(color: .redPen, seed: 2))
        Button("Join Game") {}.buttonStyle(PencilButtonStyle(color: .inkGreen, seed: 3))
        Button("¡ STOP !") {}.buttonStyle(PencilButtonFilledStyle(color: .redPen, seed: 4))
    }
    .padding(24)
    .background(Color.cream)
}
