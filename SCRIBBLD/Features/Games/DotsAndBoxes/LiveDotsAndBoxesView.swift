import SwiftUI

struct LiveDotsAndBoxesView: View {
    @StateObject private var vm: LiveDotsAndBoxesViewModel
    @Environment(\.dismiss) private var dismiss

    init(gameId: String, me: AuthAccount) {
        _vm = StateObject(wrappedValue: LiveDotsAndBoxesViewModel(gameId: gameId, me: me))
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
                Spacer()
                BannerAdView(adUnitID: AdConfig.Banner.home)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue) }
            }
        }
        .onAppear { vm.observe() }
        .onDisappear { vm.stop() }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            Text("LIVE · Dots & Boxes")
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.redPen)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.4)).frame(height: 0.6).offset(y: 8)
        }
        .padding(.vertical, 6)
    }

    private var scoreBar: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOU: \(vm.myScore)")
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                TallyMarksView(count: vm.myScore, color: .inkBlue).frame(height: 22)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(vm.opponentName.uppercased()): \(vm.theirScore)")
                    .font(.caveat(22, weight: .bold))
                    .foregroundStyle(Color.redPen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                TallyMarksView(count: vm.theirScore, color: .redPen).frame(height: 22)
            }
        }
    }

    private var turnLabel: some View {
        Text(statusText)
            .font(.dmSans(12, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(Color.inkBlue)
            .lineLimit(1)
            // 2.5pt tracking on an uppercased display name overruns the row
            // and hard-truncates the "<NAME> WINS" game-over text.
            .minimumScaleFactor(0.7)
    }

    private var statusText: String {
        if vm.isGameOver {
            if vm.winner == vm.me.uid { return "YOU WIN" }
            if vm.winner == "draw" { return "DRAW" }
            return "\(vm.opponentName.uppercased()) WINS"
        }
        return vm.isMyTurn ? "TURN: YOURS" : "TURN: \(vm.opponentName.uppercased())"
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            LiveDBBoard(vm: vm, side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct LiveDBBoard: View {
    @ObservedObject var vm: LiveDotsAndBoxesViewModel
    let side: CGFloat
    /// One line per stroke — see the solo board.
    @State private var playedThisStroke = false

    private var pad: CGFloat { 18 }
    private var inner: CGFloat { side - pad * 2 }
    private var stepX: CGFloat { inner / CGFloat(vm.size - 1) }

    var body: some View {
        ZStack {
            boxesLayer
            dotsLayer
            edgesLayer
            hitTargets
        }
    }

    private var dotsLayer: some View {
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
        Canvas { ctx, _ in
            var rng = SeededRandom(seed: 99)
            for (edge, owner) in vm.edges {
                let progress = vm.edgeAnimation[edge] ?? 1
                let color = (owner == vm.me.uid) ? Color.inkBlue : Color.redPen
                let (a, b) = edgePoints(edge)
                let cur = CGPoint(x: a.x + (b.x - a.x) * progress,
                                   y: a.y + (b.y - a.y) * progress)
                let path = HandDrawn.wobblyPath(
                    from: a, to: cur,
                    wobble: 1.6, segmentLength: 8, rng: &rng
                )
                ctx.stroke(path, with: .color(color.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 6.0, lineCap: .round, lineJoin: .round))
                let grain = path.applying(CGAffineTransform(translationX: 0.4, y: -0.3))
                ctx.stroke(grain, with: .color(color.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                ctx.stroke(path, with: .color(color.opacity(0.95)),
                           style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
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
                    let label: String = {
                        let useLong = ((r &+ c) % 3 == 0)
                        if owner == .me { return useLong ? "ME" : "P" }
                        else            { return useLong ? "THEM" : "T" }
                    }()
                    ZStack {
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

    /// Same tap-or-draw input as the solo board — see the long note on
    /// `DotsAndBoxesBoard.hitTargetsLayer` for why this is one gesture on one
    /// surface rather than per-edge tap targets plus a drag layer.
    private var hitTargets: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
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
                        if travel < 12, let edge = nearestEdge(to: value.location) {
                            vm.play(edge: edge)
                        }
                    }
            )
    }

    private func nearestDot(to p: CGPoint) -> DBDot? {
        let c = Int(((p.x - pad) / stepX).rounded())
        let r = Int(((p.y - pad) / stepX).rounded())
        guard r >= 0, r < vm.size, c >= 0, c < vm.size else { return nil }
        let dot = dotPoint(r: r, c: c)
        guard hypot(p.x - dot.x, p.y - dot.y) <= stepX * 0.75 else { return nil }
        return DBDot(row: r, col: c)
    }

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
        case .horizontal: b = dotPoint(r: edge.row, c: edge.col + 1)
        case .vertical:   b = dotPoint(r: edge.row + 1, c: edge.col)
        }
        return (a, b)
    }
}
