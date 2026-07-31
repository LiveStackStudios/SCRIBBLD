import SwiftUI

struct LiveTicTacToeView: View {
    @StateObject private var vm: LiveTicTacToeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var gridSeed: UInt64 = UInt64.random(in: 1...9999)

    init(gameId: String, me: AuthAccount) {
        _vm = StateObject(wrappedValue: LiveTicTacToeViewModel(gameId: gameId, me: me))
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                topBar
                statusBanner
                board
                Spacer()
                playersFooter
                BannerAdView(adUnitID: AdConfig.Banner.home)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(Color.inkBlue)
                }
            }
        }
        .onAppear { vm.observe() }
        .onDisappear { vm.stop() }
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            Text("LIVE")
                .font(.dmSans(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.redPen)
        }
        .padding(.top, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.inkBlue.opacity(0.4)).frame(height: 0.6).offset(y: 8)
        }
        .padding(.bottom, 8)
    }

    private var statusBanner: some View {
        // "You win!" ends in "!", whose ink overruns its advance width by
        // 0.185 of the font size — 4pt here. The solo TicTacToeView has the
        // trailing-ink modifiers; this multiplayer twin never got them, so
        // the exclamation tail was being clipped off the win message.
        Text(vm.statusMessage)
            .font(.caveat(22, weight: .bold))
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.trailing, 5)
            .fixedSize(horizontal: false, vertical: true)
            .zIndex(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: vm.statusMessage)
    }

    private var statusColor: Color {
        if vm.status == .completed {
            return vm.winner?.player == vm.mySymbol ? .inkGreen : .redPen
        }
        return vm.isMyTurn ? .inkBlue : .softGray
    }

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 3
            ZStack {
                TTTGridShape(seed: gridSeed)
                    .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))
                    .frame(width: side, height: side)

                ForEach(0..<9, id: \.self) { idx in
                    let mark = vm.board.cells[idx]
                    let progress = vm.animationProgress[idx] ?? 0
                    let col = idx % 3
                    let row = idx / 3
                    ZStack {
                        Color.clear
                        if mark == .x {
                            // Same multi-stroke treatment as solo — 3
                            // parallel passes per diagonal — so the
                            // multiplayer board doesn't look like a
                            // simpler game. Per-cell seed so each X
                            // wobbles independently.
                            MultiStrokeX(
                                seed: UInt64(idx + 1) * 17,
                                color: .inkBlue,
                                lineWidth: 3.4,
                                progress: progress
                            )
                            .padding(cell * 0.18)
                        } else if mark == .o {
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
                    .onTapGesture { vm.tap(at: idx) }
                    .position(x: (CGFloat(col) + 0.5) * cell, y: (CGFloat(row) + 0.5) * cell)
                }

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
    }

    private var playersFooter: some View {
        HStack {
            playerCell(uid: vm.me.uid, isMe: true)
            Spacer()
            playerCell(uid: vm.symbolForPlayer.first(where: { $0.key != vm.me.uid })?.key ?? "", isMe: false)
        }
    }

    private func playerCell(uid: String, isMe: Bool) -> some View {
        let name = isMe ? vm.me.displayName : vm.opponentName
        let symbol = vm.symbolForPlayer[uid]
        let isTurn = vm.currentTurn == uid && vm.status == .active
        return HStack(spacing: 6) {
            Circle()
                .fill(isTurn ? (symbol == .x ? Color.inkBlue : Color.redPen) : Color.gridGray)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(isTurn ? (symbol == .x ? Color.inkBlue : Color.redPen).opacity(0.35) : .clear, lineWidth: 4))
            Text(name)
                .font(.dmSans(13, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
            if let s = symbol {
                Text("(\(s == .x ? "X" : "O"))")
                    .font(.dmSans(12))
                    .foregroundStyle(Color.softGray)
            }
        }
    }
}
