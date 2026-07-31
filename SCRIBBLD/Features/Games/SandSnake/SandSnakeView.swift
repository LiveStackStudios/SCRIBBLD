import SwiftUI

/// Sand Snake — you never see the snake. You see the ridge it pushes up as it
/// burrows, and the tremor settling behind it.
///
/// The whole board is drawn with the app's hand-drawn primitives so it reads
/// as pencil on graph paper like every other SCRIBBLD game.
struct SandSnakeView: View {
    @StateObject private var vm = SandSnakeViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""
    private var language: GameLanguage { GameLanguage.resolve(from: languageRaw) }
    private var es: Bool { language == .spanish }

    @State private var presentPostGame = false
    @State private var boardSeed: UInt64 = 7
    @State private var showHowTo = false
    /// Only auto-present the instructions on a player's very first run.
    @AppStorage("scribbld.sandsnake.seenHowTo") private var seenHowTo = false

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.14).ignoresSafeArea()

            VStack(spacing: Spacing.md) {
                topBar
                scoreRow
                board
                hint
                BannerAdView(adUnitID: AdConfig.Banner.postGame)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)

            if showHowTo {
                Color.inkBlue.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { showHowTo = false }
                howToPlayCard
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showHowTo)
        .onAppear {
            if !seenHowTo {
                seenHowTo = true
                showHowTo = true
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { vm.pause(); dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue)
                }
            }
        }
        .navigationDestination(isPresented: $presentPostGame) {
            PostGameView(result: vm.makeResult(), restart: {
                presentPostGame = false
                boardSeed = UInt64.random(in: 1...9999)
                vm.reset()
            })
        }
        .onChange(of: vm.isGameOver) { _, over in
            guard over else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                appState.record(vm.makeResult())
                presentPostGame = true
            }
        }
        // Never leave the run loop spinning behind a pushed screen or a
        // backgrounded app — it would keep ticking and kill the player.
        .onDisappear { vm.pause() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 4) {
            ScribbldWordmark(size: 24)
            Image(systemName: "pencil.tip").foregroundStyle(Color.inkBlue)
            Spacer()
            Button {
                HapticEngine.light()
                vm.pause()
                showHowTo = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.inkBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(es ? "Cómo jugar" : "How to play")
        }
    }

    /// Shown automatically before the first run and re-openable from the "?"
    /// button. The snake is invisible by design, so without this nobody can
    /// tell what the ridge on screen actually is.
    private var howToPlayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(es ? "Cómo jugar" : "How to Play")
                .font(.caveat(30, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.trailing, 7)
                .fixedSize(horizontal: false, vertical: true)

            howToRow("hand.draw", es
                     ? "La serpiente vive **bajo la arena**. Solo ves el montículo que levanta."
                     : "The snake moves **under the sand**. You only see the ridge it pushes up.")
            howToRow("arrow.up.arrow.down", es
                     ? "**Desliza** en cualquier dirección para girar."
                     : "**Swipe** anywhere to steer.")
            bugRow(.grub, es ? "**Roja** — crece 1. Cada una te acelera."
                             : "**Red** — grow by 1. Each one speeds you up.")
            bugRow(.beetle, es ? "**Dorada** — crece el doble y vale doble."
                               : "**Gold** — grows you double, scores double.")
            bugRow(.molt, es ? "**Verde** — mudas: pierdes un cuarto de tu largo."
                             : "**Green** — molt: sheds a quarter of your length.")
            howToRow("xmark.octagon", es
                     ? "Chocar con el **borde** o con tu **propio rastro** termina la partida."
                     : "Hitting the **edge** or your **own trail** ends the run.")
            howToRow("pause.circle", es
                     ? "**Toca** el tablero para pausar o continuar."
                     : "**Tap** the board to pause or resume.")

            Button {
                HapticEngine.medium()
                showHowTo = false
                vm.start()
            } label: {
                Text(es ? "¡A excavar!" : "Start burrowing")
            }
            .buttonStyle(PencilButtonFilledStyle(color: .inkBlue, height: 46, seed: 63))
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.cream.opacity(0.97))
        .sketchBorder(color: .inkBlue, lineWidth: 1.6, cornerRadius: 12, jitter: 0.9, seed: 44)
        .padding(.horizontal, 10)
        .shadow(color: Color.inkBlue.opacity(0.12), radius: 12, y: 4)
    }

    /// Bug legend row — the icon is tinted with the same colour the board
    /// uses, so the card doubles as the key for telling them apart.
    private func bugRow(_ kind: SandBugKind, _ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Self.bugColor(kind))
                .frame(width: 20)
            Text(.init(markdown))
                .font(.dmSans(13))
                .foregroundStyle(Color.inkBlue)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func howToRow(_ icon: String, _ markdown: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Color.redPen)
                .frame(width: 20)
            Text(.init(markdown))
                .font(.dmSans(13))
                .foregroundStyle(Color.inkBlue)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var scoreRow: some View {
        HStack(alignment: .firstTextBaseline) {
            statBlock(
                label: es ? "LARVAS" : "GRUBS",
                value: "\(vm.score)",
                color: .inkBlue
            )
            Spacer()
            statBlock(
                label: es ? "RÉCORD" : "BEST",
                value: "\(vm.best)",
                color: .goldAccent
            )
        }
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.dmSans(10, weight: .semibold))
                .foregroundStyle(Color.softGray)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // InkBoundsLabel so the digits aren't clipped by Caveat's
            // advance-width sizing at this size.
            InkBoundsLabel.caveat(value, size: 30, weight: .bold, color: color)
                .fixedSize()
        }
    }

    private var hint: some View {
        Text(hintText)
            .font(.dmSans(12))
            .foregroundStyle(Color.softGray)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private var hintText: String {
        if vm.isGameOver {
            return es ? "La serpiente chocó. Toca para excavar de nuevo."
                      : "The snake hit something. Tap to burrow again."
        }
        if !vm.hasStarted {
            return es ? "Desliza para guiar la serpiente bajo la arena."
                      : "Swipe to steer the snake under the sand."
        }
        if !vm.isRunning {
            return es ? "En pausa — toca para continuar." : "Paused — tap to continue."
        }
        return es ? "Busca las larvas. No choques contigo mismo."
                  : "Hunt the grubs. Don't cross your own trail."
    }

    // MARK: - Board

    private var board: some View {
        GeometryReader { geo in
            let cell = min(
                geo.size.width / CGFloat(vm.cols),
                geo.size.height / CGFloat(vm.rows)
            )
            let boardW = cell * CGFloat(vm.cols)
            let boardH = cell * CGFloat(vm.rows)

            ZStack {
                // Sand bed — warmer than the page so the play area reads as
                // a tray of sand sitting on the notebook.
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gridGray.opacity(0.22))
                SandGrainOverlay(seed: boardSeed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Continuous animation clock for the ridge shimmer, so the
                // buried snake looks alive between simulation ticks.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Canvas { ctx, _ in
                            drawTremor(ctx, cell: cell)
                            drawBugShadow(ctx, cell: cell, time: t)
                        }
                        // The bug is a real SF Symbol view rather than
                        // something drawn into the Canvas, so it's the exact
                        // glyph the how-to-play card shows.
                        bugView(cell: cell, time: t)
                        // Ridge last: the snake is under the sand, so the
                        // mound passes over the bug as it reaches it.
                        Canvas { ctx, _ in
                            drawRidge(ctx, cell: cell, time: t)
                        }
                    }
                }
            }
            .frame(width: boardW, height: boardH)
            .sketchBorder(color: .inkBlue.opacity(0.45), lineWidth: 1.4,
                          cornerRadius: 10, jitter: 0.7, seed: boardSeed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(steerGesture)
            .onTapGesture { toggleRun() }
        }
        .aspectRatio(CGFloat(vm.cols) / CGFloat(vm.rows), contentMode: .fit)
    }

    private func toggleRun() {
        if vm.isGameOver { return }
        vm.isRunning ? vm.pause() : vm.start()
    }

    /// Minimum travel before a drag counts, so a tap-to-pause isn't read as a
    /// micro-swipe in a random direction.
    private var steerGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy) {
                    vm.steer(dx > 0 ? .right : .left)
                } else {
                    vm.steer(dy > 0 ? .down : .up)
                }
            }
    }

    // MARK: - Drawing

    private func center(_ p: SandGridPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.x) + 0.5) * cell, y: (CGFloat(p.y) + 0.5) * cell)
    }

    /// Settling sand. Rings alone read as drawn-on circles, so the trail is
    /// mostly *grains*: loose particles that drift outward and fade as the
    /// patch ages, with one faint collapsing ring underneath to suggest the
    /// tunnel roof falling in. Each patch has a fixed seed so the grains stay
    /// put between frames instead of boiling.
    private func drawTremor(_ ctx: GraphicsContext, cell: CGFloat) {
        for d in vm.disturbances {
            let age = CGFloat(vm.tick - d.bornAt)
            let life = CGFloat(SandSnakeViewModel.disturbanceLifetime)
            let remaining = max(0, 1 - age / life)
            guard remaining > 0.02 else { continue }
            let c = center(d.cell, cell: cell)
            var rng = SeededRandom(seed: d.seed)
            let spread = 1 - remaining      // grains drift out as they settle

            // Collapsing ring — starts near the tunnel width, sinks inward.
            let ringR = cell * (0.34 - 0.10 * spread)
            let ring = HandDrawn.wobblyArc(
                center: c, radius: ringR,
                startDeg: 0, endDeg: 360, wobble: 1.3, rng: &rng
            )
            ctx.stroke(ring, with: .color(Color.gridGray.opacity(Double(remaining) * 0.35)), lineWidth: 1)

            // Grains.
            let grains = 14
            for _ in 0..<grains {
                let angle = rng.next(0, .pi * 2)
                let base = rng.next(0.10, 0.42)
                let radius = cell * (base + spread * rng.next(0.10, 0.26))
                let p = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
                let size = rng.next(0.8, 2.0) * (0.5 + remaining * 0.5)
                let dot = Path(ellipseIn: CGRect(x: p.x, y: p.y, width: size, height: size))
                // Mixed light and dark grains so the scatter has depth
                // instead of looking like a single flat stipple.
                let dark = rng.next(0, 1) > 0.45
                let color = dark ? Color.gridGray : Color.cream
                ctx.fill(dot, with: .color(color.opacity(Double(remaining) * rng.next(0.35, 0.8))))
            }
        }
    }

    /// Colour is the only thing distinguishing the three bugs, so they're kept
    /// far apart on the wheel and each is echoed in the how-to-play card.
    static func bugColor(_ kind: SandBugKind) -> Color {
        switch kind {
        case .grub:   return .redPen
        case .beetle: return .goldAccent
        case .molt:   return .inkGreen
        }
    }

    /// Beetles are the prize, so they're bigger and pulse.
    private func bugSide(_ cell: CGFloat, _ time: TimeInterval) -> CGFloat {
        let base: CGFloat = vm.grubKind == .beetle ? 0.60 : 0.50
        let pulse: CGFloat = vm.grubKind == .beetle ? 1 + 0.08 * CGFloat(sin(time * 5)) : 1
        return cell * base * pulse
    }

    private func bugPoint(_ cell: CGFloat, _ time: TimeInterval) -> CGPoint {
        let c = center(vm.grub, cell: cell)
        return CGPoint(x: c.x + CGFloat(sin(time * 7)) * cell * 0.035,
                       y: c.y + CGFloat(cos(time * 5)) * cell * 0.02)
    }

    /// Contact shadow, so the bug reads as sitting *on* the sand — the
    /// opposite of the snake, which is under it.
    private func drawBugShadow(_ ctx: GraphicsContext, cell: CGFloat, time: TimeInterval) {
        let at = bugPoint(cell, time)
        let side = bugSide(cell, time)
        let shadow = Path(ellipseIn: CGRect(
            x: at.x - side * 0.36, y: at.y + side * 0.22,
            width: side * 0.72, height: side * 0.24
        ))
        ctx.fill(shadow, with: .color(Color.inkBlue.opacity(0.16)))

        // Molt bugs get a dashed shed-skin ring, so "this shortens you"
        // doesn't rest on colour alone.
        if vm.grubKind == .molt {
            var rng = SeededRandom(seed: 21)
            let c = center(vm.grub, cell: cell)
            let ring = HandDrawn.wobblyArc(center: c, radius: cell * 0.42,
                                           startDeg: 0, endDeg: 360, wobble: 1.4, rng: &rng)
            ctx.stroke(ring, with: .color(Self.bugColor(.molt).opacity(0.6)),
                       style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
        }
    }

    private func bugView(cell: CGFloat, time: TimeInterval) -> some View {
        let side = bugSide(cell, time)
        return Image(systemName: vm.grubKind.symbol)
            .font(.system(size: side, weight: .semibold))
            .foregroundStyle(Self.bugColor(vm.grubKind))
            .rotationEffect(.degrees(Double(sin(time * 3)) * 8))
            .position(bugPoint(cell, time))
            .allowsHitTesting(false)
    }

    /// The raised ridge of sand over the buried snake: a shadow pass, a body
    /// pass, and an offset highlight so it reads as pushed-up rather than
    /// drawn-on. The head gets radiating cracks.
    private func drawRidge(_ ctx: GraphicsContext, cell: CGFloat, time: TimeInterval) {
        guard vm.snake.count > 1 else { return }
        let pts = vm.snake.map { center($0, cell: cell) }

        // Shimmer travels head→tail so the ridge looks like it's moving even
        // when the simulation is between ticks.
        var spine = Path()
        spine.move(to: pts[0])
        for i in 1..<pts.count {
            let prev = pts[i - 1]
            let cur = pts[i]
            let phase = time * 6 - Double(i) * 0.55
            let amp = cell * 0.055 * CGFloat(sin(phase))
            // Displace perpendicular to travel so the wobble reads as a
            // sideways sand push, not a length change.
            let dx = cur.x - prev.x
            let dy = cur.y - prev.y
            let len = max(sqrt(dx * dx + dy * dy), 0.001)
            let px = -dy / len, py = dx / len
            let mid = CGPoint(x: (prev.x + cur.x) / 2 + px * amp,
                              y: (prev.y + cur.y) / 2 + py * amp)
            spine.addQuadCurve(to: cur, control: mid)
        }

        // Built up in passes from dark to light, all offset along a single
        // light direction (up-left), which is what sells the mound as raised
        // rather than painted on: cast shadow → dark flank → body → lit
        // flank → specular crest.
        let ridgeWidth = cell * 0.78
        let lightDX = -cell * 0.075
        let lightDY = -cell * 0.085

        // Cast shadow on the sand, down-right and slightly wider.
        ctx.stroke(spine.offsetBy(dx: -lightDX * 0.9, dy: -lightDY * 0.9),
                   with: .color(Color.inkBlue.opacity(0.13)),
                   style: StrokeStyle(lineWidth: ridgeWidth * 1.05, lineCap: .round, lineJoin: .round))
        // Dark flank.
        ctx.stroke(spine.offsetBy(dx: -lightDX * 0.5, dy: -lightDY * 0.5),
                   with: .color(Color.gridGray.opacity(0.95)),
                   style: StrokeStyle(lineWidth: ridgeWidth, lineCap: .round, lineJoin: .round))
        // Body of the mound.
        ctx.stroke(spine, with: .color(Color.gridGray.opacity(0.6)),
                   style: StrokeStyle(lineWidth: ridgeWidth * 0.80, lineCap: .round, lineJoin: .round))
        // Lit flank.
        ctx.stroke(spine.offsetBy(dx: lightDX * 0.6, dy: lightDY * 0.6),
                   with: .color(Color.cream.opacity(0.55)),
                   style: StrokeStyle(lineWidth: ridgeWidth * 0.42, lineCap: .round, lineJoin: .round))
        // Specular crest — the thin bright line along the very top.
        ctx.stroke(spine.offsetBy(dx: lightDX, dy: lightDY),
                   with: .color(Color.white.opacity(0.5)),
                   style: StrokeStyle(lineWidth: ridgeWidth * 0.16, lineCap: .round, lineJoin: .round))
        // Pencil outline so it belongs with the rest of the app.
        ctx.stroke(spine, with: .color(Color.inkBlue.opacity(0.28)),
                   style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))

        drawRidgeGrain(ctx, pts: pts, cell: cell)
        drawHead(ctx, at: pts[0], cell: cell, time: time)
    }

    /// Loose grains sitting on the mound. Seeded per body-cell so they stay
    /// with their segment instead of shimmering, and biased to the lit side
    /// so they reinforce the same light direction as the strokes.
    private func drawRidgeGrain(_ ctx: GraphicsContext, pts: [CGPoint], cell: CGFloat) {
        for (i, p) in pts.enumerated() {
            guard let seg = vm.snake.indices.contains(i) ? vm.snake[i] : nil else { continue }
            var rng = SeededRandom(seed: UInt64(abs(seg.x &* 7919 ^ seg.y &* 104729) % 50_000) &+ 5)
            for _ in 0..<5 {
                let angle = rng.next(0, .pi * 2)
                let radius = rng.next(0, cell * 0.30)
                let g = CGPoint(x: p.x + cos(angle) * radius,
                                y: p.y + sin(angle) * radius - cell * 0.04)
                let size = rng.next(0.7, 1.7)
                let dot = Path(ellipseIn: CGRect(x: g.x, y: g.y, width: size, height: size))
                let lit = rng.next(0, 1) > 0.5
                ctx.fill(
                    dot,
                    with: .color((lit ? Color.white : Color.inkBlue).opacity(rng.next(0.10, 0.30)))
                )
            }
        }
    }

    private func drawHead(_ ctx: GraphicsContext, at c: CGPoint, cell: CGFloat, time: TimeInterval) {
        var rng = SeededRandom(seed: UInt64(vm.tick % 97) &+ 11)
        let pulse = 1 + 0.06 * CGFloat(sin(time * 7))

        let mound = HandDrawn.wobblyArc(
            center: c, radius: cell * 0.42 * pulse,
            startDeg: 0, endDeg: 360, wobble: 1.6, rng: &rng
        )
        ctx.fill(mound, with: .color(Color.gridGray.opacity(0.9)))
        ctx.stroke(mound, with: .color(Color.inkBlue.opacity(0.45)), lineWidth: 1.4)

        // Cracks radiating off the leading edge — the sand breaking ahead of
        // the burrowing head, and the only cue for which way it's pointing.
        let d = vm.direction.delta
        let heading = atan2(CGFloat(d.dy), CGFloat(d.dx))
        for i in -1...1 {
            let a = heading + CGFloat(i) * 0.5
            let from = CGPoint(x: c.x + cos(a) * cell * 0.30, y: c.y + sin(a) * cell * 0.30)
            let to = CGPoint(x: c.x + cos(a) * cell * 0.62, y: c.y + sin(a) * cell * 0.62)
            let crack = HandDrawn.wobblyPath(from: from, to: to, wobble: 0.9, segmentLength: 4, rng: &rng)
            ctx.stroke(crack, with: .color(Color.inkBlue.opacity(0.35)), lineWidth: 1)
        }
    }
}

/// Static stipple of sand grain. Seeded so it's stable across redraws —
/// a re-randomising texture under a 30fps canvas would crawl distractingly.
private struct SandGrainOverlay: View {
    let seed: UInt64

    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: seed)
            let count = Int((size.width * size.height) / 900)
            for _ in 0..<count {
                let x = rng.next(0, size.width)
                let y = rng.next(0, size.height)
                let r = rng.next(0.5, 1.4)
                let dot = Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r))
                ctx.fill(dot, with: .color(Color.gridGray.opacity(Double(rng.next(0.15, 0.45)))))
            }
        }
        .allowsHitTesting(false)
    }
}
