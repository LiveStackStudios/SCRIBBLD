import SwiftUI

struct DotsAndBoxesView: View {
    @StateObject private var vm: DotsAndBoxesViewModel
    @EnvironmentObject private var appState: AppState
    @State private var presentPostGame = false
    @Environment(\.dismiss) private var dismiss

    init(mode: GameMode = .vsAI, difficulty: AIDifficulty = .medium, size: Int = 5) {
        _vm = StateObject(wrappedValue: DotsAndBoxesViewModel(size: size, mode: mode, difficulty: difficulty))
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                topBar
                scoreBar
                turnLabel
                board
                endGameButton
                BannerAdView(adUnitID: AdConfig.Banner.home)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.inkBlue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "gearshape")
                    .foregroundStyle(Color.inkBlue)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $presentPostGame) {
            PostGameView(result: makeResult(), restart: {
                presentPostGame = false
                vm.reset()
            })
        }
        .onChange(of: vm.isGameOver) { _, over in
            if over {
                appState.record(makeResult())
                Task {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    presentPostGame = true
                }
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Spacer()
                ScribbldWordmark(size: 28)
                Spacer()
            }
            Text("Dots & Boxes")
                .font(.caveat(18, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.4)).frame(height: 0.6).offset(y: 6)
        }
        .padding(.bottom, 8)
    }

    private var scoreBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOU (Blue): \(vm.myScore)")
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                TallyMarksView(count: vm.myScore, color: .inkBlue).frame(height: 22)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text("THEM (Red): \(vm.theirScore)")
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.redPen)
                TallyMarksView(count: vm.theirScore, color: .redPen).frame(height: 22)
            }
        }
        .scaleEffect(vm.pulseScore ? 1.06 : 1)
    }

    private var turnLabel: some View {
        Text(vm.current == .me ? "TURN: YOURS" : "TURN: THEM")
            .font(.dmSans(12, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(Color.inkBlue)
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            DotsAndBoxesBoard(vm: vm, side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var endGameButton: some View {
        Button {
            HapticEngine.light()
            presentPostGame = true
        } label: {
            Text("END GAME")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.7))
                .sketchBorder(color: .inkBlue, lineWidth: 1.6, cornerRadius: 10, jitter: 1.2, seed: 92)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.bottom, 10)
    }

    private func makeResult() -> GameResult {
        let outcome: GameOutcome
        if vm.myScore > vm.theirScore { outcome = .win }
        else if vm.myScore < vm.theirScore { outcome = .loss }
        else { outcome = .draw }
        return GameResult(
            game: .dotsAndBoxes,
            outcome: outcome,
            score: vm.myScore * 100,
            correctAnswers: vm.myScore,
            totalAnswers: vm.totalBoxes,
            durationSeconds: 120,
            date: Date()
        )
    }
}

/// A grid intersection, used to resolve a finger-drawn stroke to an edge.
struct DBDot: Hashable {
    var row: Int
    var col: Int
}

struct DotsAndBoxesBoard: View {
    @ObservedObject var vm: DotsAndBoxesViewModel
    let side: CGFloat
    /// Guards against drawing several edges in one continuous stroke — a turn
    /// is one line, and without this a fast swipe across the board would
    /// consume several moves at once.
    @State private var playedThisStroke = false

    private var step: CGFloat { side / CGFloat(vm.size - 1) - 4 } // visual padding
    private var pad: CGFloat { 18 }
    private var inner: CGFloat { side - pad * 2 }
    private var stepX: CGFloat { inner / CGFloat(vm.size - 1) }

    var body: some View {
        ZStack {
            boxesLayer
            dotsLayer
            edgesLayer
            pencilCursor.allowsHitTesting(false)
            // Hit targets MUST be on top so they aren't blocked by the pencil
            // cursor or any other decorative layer.
            hitTargetsLayer
        }
    }

    private var dotsLayer: some View {
        // Each grid intersection is a PencilDot — a small filled
        // scribble-circle drawn in soft graphite, per the SCRIBBLD
        // Dots & Boxes reference mockup. Per-dot seed so each one
        // wobbles independently and the grid doesn't look stamped.
        ZStack {
            ForEach(0..<vm.size, id: \.self) { r in
                ForEach(0..<vm.size, id: \.self) { c in
                    let center = dotPoint(r: r, c: c)
                    PencilDot(
                        size: max(10, stepX * 0.18),
                        seed: UInt64(r * 100 + c + 1)
                    )
                    .position(center)
                }
            }
        }
    }

    private var edgesLayer: some View {
        // Edges drawn as multi-pass colored-pencil strokes: a wider
        // soft halo under a crisper main stroke + small offset grain
        // pass. Same trick as ColoredPencilStroke, drawn via Canvas
        // here so we can clip a draw-in animation on `progress`.
        Canvas { ctx, _ in
            var rng = SeededRandom(seed: 99)
            for (edge, owner) in vm.edges {
                let progress = vm.edgeAnimation[edge] ?? 1
                let color = owner == .me ? Color.inkBlue : Color.redPen
                let (a, b) = edgePoints(edge)
                let cur = CGPoint(
                    x: a.x + (b.x - a.x) * progress,
                    y: a.y + (b.y - a.y) * progress
                )
                let path = HandDrawn.wobblyPath(
                    from: a, to: cur,
                    wobble: 1.6, segmentLength: 8, rng: &rng
                )
                // Halo
                ctx.stroke(
                    path,
                    with: .color(color.opacity(0.30)),
                    style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round)
                )
                // Grain (offset)
                let grain = path.applying(
                    CGAffineTransform(translationX: 0.4, y: -0.3)
                )
                ctx.stroke(
                    grain,
                    with: .color(color.opacity(0.55)),
                    style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                )
                // Main
                ctx.stroke(
                    path,
                    with: .color(color.opacity(0.95)),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    private var boxesLayer: some View {
        ZStack {
            ForEach(vm.boxes.indices, id: \.self) { i in
                if let owner = vm.boxes[i].owner {
                    let r = vm.boxes[i].row, c = vm.boxes[i].col
                    let topLeft = dotPoint(r: r, c: c)
                    let progress = vm.boxAnimation[i] ?? 1
                    let color: Color = (owner == .me) ? .inkBlue : .redPen
                    // Mix P/ME (or T/THEM) labels for visual variety
                    // matching the reference mockup. Deterministic per
                    // cell so the label doesn't change every redraw.
                    let label: String = {
                        let useLong = ((r &+ c) % 3 == 0)
                        if owner == .me { return useLong ? "ME" : "P" }
                        else            { return useLong ? "THEM" : "T" }
                    }()
                    ZStack {
                        // Bumped watercolor intensity 0.22 → 0.35 so the
                        // wash reads more like a colored-pencil shade
                        // than a faint hint.
                        WatercolorFill(color: color, intensity: 0.35, blobs: 3,
                                       seed: UInt64(r * 10 + c + 1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(label)
                            .font(.caveat(16, weight: .bold))
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.trailing, 2)
                    }
                    .frame(width: stepX, height: stepX)
                    .position(x: topLeft.x + stepX / 2, y: topLeft.y + stepX / 2)
                    .scaleEffect(progress)
                    .opacity(progress)
                }
            }
        }
    }

    /// Tapping an edge and *drawing* it with a finger are handled by one
    /// gesture on one full-board surface. Two separate layers (per-edge tap
    /// targets on top, a drag surface beneath) don't work: a drag beginning
    /// inside a tap target isn't reliably forwarded to the layer below, so
    /// drags that started near an edge — the common case — would be lost.
    ///
    /// A single `DragGesture(minimumDistance: 0)` receives both; we classify
    /// on end by how far the finger travelled.
    private var hitTargetsLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Draw as soon as the stroke spans two adjacent dots,
                        // so the line appears under the finger rather than
                        // waiting for lift-off.
                        guard !playedThisStroke else { return }
                        guard let from = nearestDot(to: value.startLocation),
                              let to = nearestDot(to: value.location),
                              from != to,
                              let edge = edgeBetween(from, to) else { return }
                        playedThisStroke = true
                        vm.play(edge: edge)
                    }
                    .onEnded { value in
                        defer { playedThisStroke = false }
                        guard !playedThisStroke else { return }
                        let travel = hypot(value.translation.width, value.translation.height)
                        // Short travel = a tap: use the edge nearest the
                        // finger rather than requiring dot-to-dot precision.
                        if travel < 12, let edge = nearestEdge(to: value.location) {
                            vm.play(edge: edge)
                        }
                    }
            )
    }

    /// Grid dot nearest `p`, or nil if the point is well outside the grid.
    private func nearestDot(to p: CGPoint) -> DBDot? {
        let c = Int(((p.x - pad) / stepX).rounded())
        let r = Int(((p.y - pad) / stepX).rounded())
        guard r >= 0, r < vm.size, c >= 0, c < vm.size else { return nil }
        // Require the finger to actually be near the dot, so a sloppy
        // diagonal swipe across a box doesn't snap to an arbitrary edge.
        let dot = dotPoint(r: r, c: c)
        guard hypot(p.x - dot.x, p.y - dot.y) <= stepX * 0.75 else { return nil }
        return DBDot(row: r, col: c)
    }

    /// The edge joining two dots, or nil if they aren't orthogonally adjacent.
    private func edgeBetween(_ a: DBDot, _ b: DBDot) -> DBEdge? {
        if a.row == b.row, abs(a.col - b.col) == 1 {
            return DBEdge(orientation: .horizontal, row: a.row, col: min(a.col, b.col))
        }
        if a.col == b.col, abs(a.row - b.row) == 1 {
            return DBEdge(orientation: .vertical, row: min(a.row, b.row), col: a.col)
        }
        return nil
    }

    private func nearestEdge(to p: CGPoint) -> DBEdge? {
        var best: (edge: DBEdge, dist: CGFloat)?
        for edge in allEdges() {
            let (a, b) = edgePoints(edge)
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            let d = hypot(p.x - mid.x, p.y - mid.y)
            if best == nil || d < best!.dist { best = (edge, d) }
        }
        guard let best, best.dist <= stepX * 0.6 else { return nil }
        return best.edge
    }

    private var pencilCursor: some View {
        // Visual cue near the last edge played by ME — looks like a small pencil tip.
        Group {
            if let lastMine = vm.edges.first(where: { $0.value == .me })?.key {
                let (a, b) = edgePoints(lastMine)
                let mid = CGPoint(x: (a.x + b.x) / 2 + 18, y: (a.y + b.y) / 2 + 8)
                Image(systemName: "pencil.tip")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.goldAccent)
                    .rotationEffect(.degrees(-25))
                    .position(mid)
                    .transition(.opacity)
            }
        }
    }

    private func allEdges() -> [DBEdge] {
        var result: [DBEdge] = []
        for r in 0..<vm.size {
            for c in 0..<(vm.size - 1) {
                result.append(DBEdge(orientation: .horizontal, row: r, col: c))
            }
        }
        for r in 0..<(vm.size - 1) {
            for c in 0..<vm.size {
                result.append(DBEdge(orientation: .vertical, row: r, col: c))
            }
        }
        return result
    }

    private func dotPoint(r: Int, c: Int) -> CGPoint {
        CGPoint(x: pad + CGFloat(c) * stepX, y: pad + CGFloat(r) * stepX)
    }

    private func edgePoints(_ edge: DBEdge) -> (CGPoint, CGPoint) {
        let a = dotPoint(r: edge.row, c: edge.col)
        let b: CGPoint
        switch edge.orientation {
        case .horizontal:
            b = dotPoint(r: edge.row, c: edge.col + 1)
        case .vertical:
            b = dotPoint(r: edge.row + 1, c: edge.col)
        }
        return (a, b)
    }
}

#Preview {
    NavigationStack {
        DotsAndBoxesView()
            .environmentObject(AppState())
            .environmentObject(StoreManager())
    }
}
