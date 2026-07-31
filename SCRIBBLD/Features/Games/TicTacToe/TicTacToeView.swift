import SwiftUI

struct TicTacToeView: View {
    @StateObject private var vm: TicTacToeViewModel
    @State private var showSplash = false
    @State private var splashOrigin: CGPoint = .zero
    @State private var presentPostGame = false
    @State private var gridSeed: UInt64 = UInt64.random(in: 1...9999)
    @EnvironmentObject private var appState: AppState

    init(mode: GameMode = .vsAI, difficulty: AIDifficulty = .medium) {
        _vm = StateObject(wrappedValue: TicTacToeViewModel(mode: mode, difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                topBar
                statusBanner
                board
                scoreboard
                Spacer()
                bottomControls
                BannerAdView(adUnitID: AdConfig.Banner.home)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)

            if showSplash {
                InkSplashEffect(origin: splashOrigin)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $presentPostGame) {
            PostGameView(result: makeResult(), restart: {
                presentPostGame = false
                vm.reset()
                gridSeed = UInt64.random(in: 1...9999)
                showSplash = false
            })
        }
        .onChange(of: vm.winner?.player) { _, _ in
            guard vm.winner != nil else { return }
            splashOrigin = CGPoint(x: 200, y: 200)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { showSplash = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                appState.record(makeResult())
                presentPostGame = true
            }
        }
        .onChange(of: vm.isDraw) { _, draw in
            if draw {
                Task {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    presentPostGame = true
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            Text("TURN")
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.softGray)
        }
        .padding(.top, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.5)).frame(height: 0.5).offset(y: 8)
        }
        .padding(.bottom, 12)
    }

    private var statusBanner: some View {
        Text(vm.statusText)
            .font(.caveat(22, weight: .bold))
            .foregroundStyle(vm.winner?.player == .o ? Color.redPen : Color.inkBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .fixedSize(horizontal: false, vertical: true)
            .zIndex(1)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.statusText)
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 3
            ZStack {
                TTTGridShape(seed: gridSeed)
                    .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
                    .frame(width: side, height: side)

                // Marks + tap targets. Color.clear gives every cell a non-empty
                // hit area (empty Group + .frame yields no hit region in SwiftUI).
                ForEach(0..<9, id: \.self) { idx in
                    let mark = vm.board.cells[idx]
                    let progress = vm.animationProgress[idx] ?? 0
                    let col = idx % 3
                    let row = idx / 3
                    ZStack {
                        Color.clear
                        if mark == .x {
                            // 3-layer "drawn forcefully and re-traced"
                            // X — center stroke at full opacity, outer
                            // two parallel strokes at lower opacity.
                            // All three share the same trim progress so
                            // the draw-in animation stays unified.
                            MultiStrokeX(
                                seed: UInt64(idx + 1) * 17,
                                color: .inkBlue,
                                lineWidth: 3.4,
                                progress: progress
                            )
                            .padding(cell * 0.18)
                        } else if mark == .o {
                            // 3-layer concentric loop O — same idea.
                            MultiStrokeO(
                                seed: UInt64(idx + 1) * 23,
                                color: .redPen,
                                lineWidth: 3.4,
                                progress: progress
                            )
                            .padding(cell * 0.18)
                        }
                    }
                    .frame(width: cell, height: cell)
                    .contentShape(Rectangle())
                    .onTapGesture { vm.handleTap(at: idx) }
                    .position(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
                }

                // Win line + wash. Wash sits BEHIND the strike so it
                // reads as ink bleed under the line. Strike itself is
                // a 2-pass stroke (soft red halo + crisper main line)
                // matching the home/detail illustration win marker.
                if let w = vm.winner {
                    WatercolorFill(
                        color: w.player == .x ? .inkBlue : .redPen,
                        intensity: 0.28,
                        seed: 88
                    )
                    .opacity(vm.winLineProgress)
                    .allowsHitTesting(false)
                    WinLine(line: w.line, cellSize: cell, progress: vm.winLineProgress)
                        .stroke(Color.redPen.opacity(0.35),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    WinLine(line: w.line, cellSize: cell, progress: vm.winLineProgress)
                        .stroke(Color.redPen,
                                style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
                }
            }
            .frame(width: side, height: side, alignment: .center)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.vertical, 4)
    }

    private var scoreboard: some View {
        HStack(spacing: Spacing.xl) {
            ScoreLine(label: "P1", value: vm.p1Score, color: .inkBlue)
            ScoreLine(label: "P2", value: vm.p2Score, color: .redPen)
        }
        .padding(.horizontal, 4)
    }

    private var bottomControls: some View {
        HStack {
            Button {
                HapticEngine.light()
                vm.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.inkBlue)
            }
            Spacer()
            Button {
                HapticEngine.light()
                vm.reset()
                gridSeed = UInt64.random(in: 1...9999)
            } label: {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.inkBlue)
            }
        }
        .padding(.bottom, 6)
    }

    private func makeResult() -> GameResult {
        let outcome: GameOutcome
        if vm.isDraw { outcome = .draw }
        else if vm.winner?.player == vm.humanPlayer { outcome = .win }
        else if vm.winner != nil { outcome = .loss }
        else { outcome = .draw }
        return GameResult(
            game: .ticTacToe,
            outcome: outcome,
            score: outcome == .win ? 1_200 : (outcome == .draw ? 400 : 0),
            correctAnswers: nil,
            totalAnswers: nil,
            durationSeconds: 90,
            date: Date()
        )
    }
}

// MARK: - Grid Shape

struct TTTGridShape: Shape {
    var seed: UInt64

    func path(in rect: CGRect) -> Path {
        var combined = Path()
        var rng = SeededRandom(seed: seed)
        let cell = rect.width / 3
        // Each grid line is drawn with a chunky wobble + slight
        // overshoot at the ends so it reads as a pencil stroke rather
        // than a vector segment. Endpoints jitter by up to 4pt past
        // the grid intersection — the way a real sketcher overshoots.
        for i in 1...2 {
            let x = rect.minX + CGFloat(i) * cell
            let overY1 = rng.next(2, 6)
            let overY2 = rng.next(2, 6)
            let vertical = HandDrawn.wobblyPath(
                from: CGPoint(x: x + rng.next(-1.5, 1.5), y: rect.minY - overY1),
                to: CGPoint(x: x + rng.next(-1.5, 1.5), y: rect.maxY + overY2),
                wobble: 3.0, segmentLength: 9, rng: &rng
            )
            combined.addPath(vertical)
            let y = rect.minY + CGFloat(i) * cell
            let overX1 = rng.next(2, 6)
            let overX2 = rng.next(2, 6)
            let horizontal = HandDrawn.wobblyPath(
                from: CGPoint(x: rect.minX - overX1, y: y + rng.next(-1.5, 1.5)),
                to: CGPoint(x: rect.maxX + overX2, y: y + rng.next(-1.5, 1.5)),
                wobble: 3.0, segmentLength: 9, rng: &rng
            )
            combined.addPath(horizontal)
        }
        return combined
    }
}

// MARK: - Win Line

struct WinLine: Shape {
    var line: [Int]
    var cellSize: CGFloat
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = line.first, let last = line.last else { return path }
        let firstCenter = CGPoint(x: (CGFloat(first % 3) + 0.5) * cellSize,
                                  y: (CGFloat(first / 3) + 0.5) * cellSize)
        let lastCenter = CGPoint(x: (CGFloat(last % 3) + 0.5) * cellSize,
                                 y: (CGFloat(last / 3) + 0.5) * cellSize)
        let dx = lastCenter.x - firstCenter.x
        let dy = lastCenter.y - firstCenter.y
        let endX = firstCenter.x + dx * progress
        let endY = firstCenter.y + dy * progress
        path.move(to: firstCenter)
        path.addLine(to: CGPoint(x: endX, y: endY))
        return path
    }
}

// MARK: - Score Line with tally marks

struct ScoreLine: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text("\(label):")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(color)
            TallyMarksView(count: value, color: color)
                .frame(height: 22)
        }
    }
}

/// Backward-compat tally renderer — now delegates to HandDrawnTally.
struct TallyMarksView: View {
    let count: Int
    let color: Color
    var lineWidth: CGFloat = 1.6

    var body: some View {
        HandDrawnTally(count: count, color: color, lineWidth: lineWidth, seed: UInt64(count) * 51 + 7)
    }
}

// MARK: - Ink Splash

struct InkSplashEffect: View {
    let origin: CGPoint
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { context in
            Canvas { ctx, size in
                let elapsed = max(0, context.date.timeIntervalSince(startDate))
                let progress = min(1, elapsed / 0.9)
                let droplets = 14
                for i in 0..<droplets {
                    let angle = Double(i) / Double(droplets) * 2 * .pi + Double(i) * 0.13
                    let distance = 60 + Double(i % 4) * 16 + progress * 90
                    let cx = size.width / 2 + cos(angle) * distance * progress
                    let cy = size.height / 2 + sin(angle) * distance * progress
                    let radius = 4 + Double(i % 3) * 2
                    let alpha = max(0, 0.85 * (1 - progress))
                    let drop = Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2))
                    ctx.fill(drop, with: .color(Color.inkBlue.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { startDate = Date() }
    }
}

#Preview {
    NavigationStack {
        TicTacToeView()
            .environmentObject(AppState())
            .environmentObject(StoreManager())
    }
}
