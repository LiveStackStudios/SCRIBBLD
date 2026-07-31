import SwiftUI

struct HangmanView: View {
    @StateObject private var vm = HangmanViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var presentPostGame = false

    private let keyboardRows: [[Character]] = [
        Array("QWERTYUIOP"),
        Array("ASDFGHJKL"),
        Array("ZXCVBNM")
    ]

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.18).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                topBar
                subtitle
                drawingCard
                wrongLettersRow
                statusRow
                BannerAdView(adUnitID: AdConfig.Banner.home)
                Spacer(minLength: 4)
                keyboard
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(Color.inkBlue)
                }
            }
        }
        .navigationDestination(isPresented: $presentPostGame) {
            PostGameView(result: makeResult(), restart: {
                presentPostGame = false
                vm.reset()
            })
        }
        .onChange(of: vm.isFinished) { _, finished in
            guard finished else { return }
            appState.record(makeResult())
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                presentPostGame = true
            }
        }
    }

    private var topBar: some View {
        // Language toggle lives in the Home top bar now — the global
        // pref applies to every game on entry. Hangman just reflects
        // it via `vm.language`. Removed the prior dead-icon row.
        HStack {
            HStack(spacing: 4) {
                ScribbldWordmark(size: 24)
                Image(systemName: "pencil.tip")
                    .foregroundStyle(Color.inkBlue)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.4)).frame(height: 0.6).offset(y: 6)
        }
        .padding(.bottom, 6)
    }

    private var subtitle: some View {
        Text(subtitleText)
            .font(.dmSans(12, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Color.softGray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitleText: String {
        switch vm.language {
        case .english:   return "WORD GAME / HANGMAN"
        case .spanish:   return "JUEGO DE PALABRAS / AHORCADO"
        case .bilingual: return "WORD GAME / AHORCADO"
        }
    }

    private var drawingCard: some View {
        VStack(spacing: 12) {
            GallowsView(stage: vm.stage)
                .frame(height: 220)
                .overlay(NotebookLines().allowsHitTesting(false))

            Text(vm.revealed)
                .font(.caveat(34, weight: .bold))
                .foregroundStyle(vm.wonOrLost == .win ? Color.inkGreen : Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .padding(.trailing, 4)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Color.inkBlue.opacity(0.18), lineWidth: 0.7))
    }

    private var wrongLettersRow: some View {
        HStack(spacing: 8) {
            ForEach(vm.wrong, id: \.self) { letter in
                ZStack {
                    Text(String(letter))
                        .font(.dmSans(18, weight: .bold))
                        .foregroundStyle(Color.inkBlue)
                    HandDrawnStrikethrough(
                        color: Color.redPen,
                        lineWidth: 1.8,
                        seed: UInt64(letter.asciiValue ?? 0) &* 23
                    )
                    .frame(width: 26, height: 22)
                }
                .frame(width: 26, height: 22)
            }
        }
        .frame(minHeight: 28)
    }

    private var statusRow: some View {
        HStack {
            Text("\(guessesLeftLabel): \(vm.guessesLeft)")
            Spacer()
            Text("\(categoryLabel): \(vm.category.displayName(in: vm.language).uppercased())")
        }
        .font(.dmSans(11, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(Color.softGray)
    }

    private var guessesLeftLabel: String {
        switch vm.language {
        case .english:   return "GUESSES LEFT"
        case .spanish:   return "INTENTOS"
        case .bilingual: return "GUESSES LEFT"
        }
    }

    private var categoryLabel: String {
        switch vm.language {
        case .english:   return "CATEGORY"
        case .spanish:   return "CATEGORÍA"
        case .bilingual: return "CATEGORY"
        }
    }

    private var keyboard: some View {
        VStack(spacing: 8) {
            ForEach(keyboardRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    if rowIndex == 1 { Spacer(minLength: 14) }
                    ForEach(keyboardRows[rowIndex], id: \.self) { letter in
                        KeyboardKey(letter: letter, state: state(for: letter)) {
                            vm.guess(letter)
                        }
                    }
                    if rowIndex == 1 { Spacer(minLength: 14) }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private func state(for letter: Character) -> KeyboardKey.State {
        let l = Character(letter.uppercased())
        if !vm.guessed.contains(l) { return .available }
        if vm.word.contains(l) { return .correct }
        return .wrong
    }

    private func makeResult() -> GameResult {
        let outcome = vm.wonOrLost ?? .draw
        return GameResult(
            game: .hangman,
            outcome: outcome,
            score: outcome == .win ? 1_000 : 200,
            correctAnswers: vm.word.count - vm.word.filter { !vm.guessed.contains($0) }.count,
            totalAnswers: vm.word.count,
            durationSeconds: 80,
            date: Date()
        )
    }
}

struct GallowsView: View {
    let stage: Int

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 7777)
            let baseY = size.height - 18
            let postX: CGFloat = 64
            let topY: CGFloat = 18
            let beamX: CGFloat = postX + 90

            // Reference (SCRIBBLD — Hangman) shows pole/beam/base as
            // 2D wobbly rectangles with diagonal hatch fill inside,
            // and the figure as several parallel pencil strokes
            // (head = 2 overlapping circles, body/arms/legs = 3-stroke
            // bundles). These helpers replicate that pencil-pressure
            // look.

            // Filled beam: outline rect + diagonal hatch fill.
            // `width` is the thickness perpendicular to the AB direction.
            func filledBeam(from a: CGPoint, to b: CGPoint, width: CGFloat) {
                let dx = b.x - a.x
                let dy = b.y - a.y
                let len = max(0.001, sqrt(dx * dx + dy * dy))
                let ux = dx / len, uy = dy / len
                let px = -uy, py = ux
                let h = width / 2
                let p1 = CGPoint(x: a.x + px * h, y: a.y + py * h)
                let p2 = CGPoint(x: b.x + px * h, y: b.y + py * h)
                let p3 = CGPoint(x: b.x - px * h, y: b.y - py * h)
                let p4 = CGPoint(x: a.x - px * h, y: a.y - py * h)

                // Wobbly outline — four sides.
                let outlineStyle = StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
                for (sa, sb) in [(p1, p2), (p2, p3), (p3, p4), (p4, p1)] {
                    let path = HandDrawn.wobblyPath(from: sa, to: sb,
                                                     wobble: 0.7, segmentLength: 8, rng: &rng)
                    ctx.stroke(path, with: .color(.inkBlue), style: outlineStyle)
                }

                // Diagonal hatch inside the beam — clip to the
                // rectangle then sweep wobbly diagonals across it.
                var rectPath = Path()
                rectPath.move(to: p1)
                rectPath.addLine(to: p2)
                rectPath.addLine(to: p3)
                rectPath.addLine(to: p4)
                rectPath.closeSubpath()

                var clipCtx = ctx
                clipCtx.clip(to: rectPath)
                // Stroke endpoints set well outside the rectangle so
                // the visible part starts and ends naturally inside.
                let hatchExtent = max(width, len) + 60
                let hatchSpacing: CGFloat = 4.5
                // Step along the rectangle's long axis, drawing
                // diagonal lines perpendicular-ish.
                let cx = (a.x + b.x) / 2
                let cy = (a.y + b.y) / 2
                // Use 45° diagonals in screen space — looks natural.
                let dAngle: CGFloat = 0.785398 // ≈ 45° in radians
                let hdx = cos(dAngle), hdy = sin(dAngle)
                var offset: CGFloat = -hatchExtent
                while offset < hatchExtent {
                    let ox = cx + hdy * offset
                    let oy = cy - hdx * offset
                    let hatchA = CGPoint(x: ox - hdx * hatchExtent, y: oy - hdy * hatchExtent)
                    let hatchB = CGPoint(x: ox + hdx * hatchExtent, y: oy + hdy * hatchExtent)
                    let path = HandDrawn.wobblyPath(
                        from: hatchA, to: hatchB,
                        wobble: 0.5, segmentLength: 14, rng: &rng
                    )
                    let opacity = rng.next(0.35, 0.7)
                    let lw = rng.next(0.7, 1.2)
                    clipCtx.stroke(
                        path,
                        with: .color(Color.inkBlue.opacity(Double(opacity))),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round)
                    )
                    offset += hatchSpacing + rng.next(-0.6, 0.6)
                }
            }

            // Multiple parallel wobbly strokes — body/arms/legs.
            // Each pass is offset perpendicular to the line direction
            // by a tiny amount + has its own wobble; together they
            // look like the bundle-of-pencil-strokes in the reference.
            func multiLine(from a: CGPoint, to b: CGPoint, passes: Int = 3, spread: CGFloat = 1.2) {
                let dx = b.x - a.x, dy = b.y - a.y
                let len = max(0.001, sqrt(dx * dx + dy * dy))
                let nx = -dy / len, ny = dx / len
                for i in 0..<passes {
                    let t = (CGFloat(i) - CGFloat(passes - 1) / 2) * spread
                    let offA = CGPoint(x: a.x + nx * t, y: a.y + ny * t)
                    let offB = CGPoint(x: b.x + nx * t, y: b.y + ny * t)
                    let path = HandDrawn.wobblyPath(
                        from: offA, to: offB,
                        wobble: 0.9, segmentLength: 9, rng: &rng
                    )
                    ctx.stroke(path,
                               with: .color(Color.inkBlue.opacity(i == passes / 2 ? 0.95 : 0.55)),
                               style: StrokeStyle(lineWidth: i == passes / 2 ? 1.8 : 1.2, lineCap: .round))
                }
            }

            // Multiple overlapping wobbly circles — the head.
            func multiCircle(in rect: CGRect, passes: Int = 2) {
                for i in 0..<passes {
                    let dx = rng.next(-1.5, 1.5)
                    let dy = rng.next(-1.5, 1.5)
                    let r = rect.offsetBy(dx: dx, dy: dy)
                    let path = SketchCircle(
                        seed: UInt64(7777 + i * 53),
                        wobbleScale: 1.3
                    ).path(in: r)
                    ctx.stroke(path,
                               with: .color(Color.inkBlue.opacity(i == 0 ? 0.95 : 0.65)),
                               style: StrokeStyle(lineWidth: i == 0 ? 1.9 : 1.4, lineCap: .round, lineJoin: .round))
                }
            }

            // Stage 1: base (filled rectangle)
            if stage >= 1 {
                filledBeam(
                    from: CGPoint(x: postX - 30, y: baseY),
                    to:   CGPoint(x: postX + 56, y: baseY),
                    width: 12
                )
            }
            // Stage 2: vertical post (filled rectangle)
            if stage >= 2 {
                filledBeam(
                    from: CGPoint(x: postX, y: baseY - 6),
                    to:   CGPoint(x: postX, y: topY + 4),
                    width: 12
                )
            }
            // Stage 3: top beam (filled rectangle) + L-bracket
            if stage >= 3 {
                filledBeam(
                    from: CGPoint(x: postX - 4, y: topY),
                    to:   CGPoint(x: beamX,     y: topY),
                    width: 10
                )
                // L-bracket knee brace in the inside corner.
                let braceA = CGPoint(x: postX + 8, y: topY + 6)
                let braceB = CGPoint(x: postX + 20, y: topY + 6)
                let braceC = CGPoint(x: postX + 8, y: topY + 24)
                let braceStyle = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                ctx.stroke(HandDrawn.wobblyPath(from: braceB, to: braceC, wobble: 0.6, segmentLength: 6, rng: &rng),
                           with: .color(Color.inkBlue), style: braceStyle)
                ctx.stroke(HandDrawn.wobblyPath(from: braceA, to: braceB, wobble: 0.5, segmentLength: 6, rng: &rng),
                           with: .color(Color.inkBlue.opacity(0.7)), style: braceStyle)
                ctx.stroke(HandDrawn.wobblyPath(from: braceA, to: braceC, wobble: 0.5, segmentLength: 6, rng: &rng),
                           with: .color(Color.inkBlue.opacity(0.7)), style: braceStyle)
            }
            // Stage 4: rope (single thin line)
            if stage >= 4 {
                let ropeStyle = StrokeStyle(lineWidth: 1.5, lineCap: .round)
                let rope = HandDrawn.wobblyPath(
                    from: CGPoint(x: beamX, y: topY + 8),
                    to:   CGPoint(x: beamX, y: topY + 30),
                    wobble: 0.4, segmentLength: 6, rng: &rng
                )
                ctx.stroke(rope, with: .color(.inkBlue), style: ropeStyle)
            }
            // Stage 5: head (2 overlapping circles)
            if stage >= 5 {
                multiCircle(in: CGRect(x: beamX - 16, y: topY + 30, width: 32, height: 32))
            }
            // Stage 6: body
            if stage >= 6 {
                multiLine(
                    from: CGPoint(x: beamX, y: topY + 62),
                    to:   CGPoint(x: beamX, y: topY + 118)
                )
            }
            // Stage 7: left arm
            if stage >= 7 {
                multiLine(
                    from: CGPoint(x: beamX, y: topY + 74),
                    to:   CGPoint(x: beamX - 24, y: topY + 96)
                )
            }
            // Stage 8: right arm
            if stage >= 8 {
                multiLine(
                    from: CGPoint(x: beamX, y: topY + 74),
                    to:   CGPoint(x: beamX + 24, y: topY + 96)
                )
            }
            // Stage 9: left leg
            if stage >= 9 {
                multiLine(
                    from: CGPoint(x: beamX, y: topY + 118),
                    to:   CGPoint(x: beamX - 18, y: topY + 150)
                )
            }
            // Stage 10: right leg
            if stage >= 10 {
                multiLine(
                    from: CGPoint(x: beamX, y: topY + 118),
                    to:   CGPoint(x: beamX + 18, y: topY + 150)
                )
            }
        }
    }
}

struct NotebookLines: View {
    var body: some View {
        Canvas { ctx, size in
            let lineCount = 6
            for i in 1...lineCount {
                let y = size.height * CGFloat(i) / CGFloat(lineCount + 1)
                var p = Path()
                p.move(to: CGPoint(x: 16, y: y))
                p.addLine(to: CGPoint(x: size.width - 16, y: y))
                ctx.stroke(p, with: .color(Color.inkBlue.opacity(0.12)), style: StrokeStyle(lineWidth: 0.6))
            }
        }
    }
}

struct StrikeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - 2, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX + 2, y: rect.minY))
        return p
    }
}

struct KeyboardKey: View {
    enum State { case available, correct, wrong }
    let letter: Character
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticEngine.light()
            action()
        }) {
            ZStack {
                // Hand-drawn pencil circle outline — matches the
                // reference Hangman keyboard (mockup §4). State only
                // changes the outline color; no background fill, no
                // clipped-to-perfect-Circle container.
                SketchCircle(seed: UInt64(letter.asciiValue ?? 0) &* 13, wobbleScale: 1.3)
                    .stroke(strokeColor,
                            style: SwiftUI.StrokeStyle(
                                lineWidth: state == .correct ? 2.4 : 1.6,
                                lineCap: .round,
                                lineJoin: .round))
                Text(String(letter))
                    .font(.dmSans(15, weight: .semibold))
                    .foregroundStyle(textColor)
            }
            .frame(width: 34, height: 34)
            .contentShape(Circle())
        }
        .disabled(state != .available)
        // Faint background tint for guessed letters so the user can
        // see "you tried this" at a glance — but no solid fill that
        // hides the pencil-circle line.
        .opacity(state == .wrong ? 0.45 : 1.0)
    }

    private var strokeColor: Color {
        switch state {
        case .available: return Color.inkBlue.opacity(0.9)
        case .correct:   return Color.inkGreen
        case .wrong:     return Color.softGray.opacity(0.7)
        }
    }
    private var textColor: Color {
        switch state {
        case .available: return Color.inkBlue
        case .correct:   return Color.inkGreen
        case .wrong:     return Color.softGray
        }
    }
}

#Preview {
    NavigationStack {
        HangmanView()
            .environmentObject(AppState())
            .environmentObject(StoreManager())
    }
}
