import SwiftUI

/// Hand-drawn-style illustrations for the home / game-detail cards.
/// All drawn with `Canvas` + `Path` (no SF Symbols / emoji) so they share the
/// brand's sketched aesthetic.
struct GameIllustration: View {
    let game: GameType
    var stroke: Color = .inkBlue
    var accent: Color = .redPen

    var body: some View {
        Group {
            switch game {
            case .dotsAndBoxes:
                dotsAndBoxesBoard
            case .ticTacToe:
                // TTT also uses ZStack so the WatercolorFill behind
                // the winning strike can render with real blur, the
                // way ink bleeds on paper.
                ticTacToeBoard
            default:
                Canvas { ctx, size in
                    switch game {
                    case .hangman:      drawHangman(ctx, size: size)
                    case .stop:         drawStopSign(ctx, size: size)
                    case .sandSnake:    drawSandSnake(ctx, size: size)
                    case .sketching:    drawSketching(ctx, size: size)
                    case .ticTacToe, .dotsAndBoxes: break // handled above
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Tic Tac Toe

    /// Won-board Tic Tac Toe illustration. Mirrors the reference
    /// mockup's "Player 1 (X) wins!" state:
    ///   * 9-cell wobbly grid
    ///   * Each X is a bundle of 3 parallel wobbly pencil strokes
    ///     per diagonal (6 strokes per X total) — reads as "drawn
    ///     forcefully," not a single thin line.
    ///   * Each O is 3 overlapping wobbly circles slightly offset
    ///     and at slightly different radii — looks like the player
    ///     went around the circle a few times with a red pen.
    ///   * Red strike line crosses the anti-diagonal winning cells.
    ///   * A blurred red watercolor splash sits BEHIND the strike.
    private var ticTacToeBoard: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) * 0.86
            let origin = CGPoint(
                x: (geo.size.width - s) / 2,
                y: (geo.size.height - s) / 2
            )
            let cell = s / 3

            // X-wins-on-the-anti-diagonal layout:
            //   (0,0) X | (0,1) O | (0,2) X*
            //   (1,0) O | (1,1) X*| (1,2) O
            //   (2,0) X*| (2,1) O | (2,2) X
            // * = winning cell (anti-diagonal top-right → bottom-left)
            let isWinningCell: (Int, Int) -> Bool = { r, c in
                (r == 0 && c == 2) || (r == 1 && c == 1) || (r == 2 && c == 0)
            }
            let isX: (Int, Int) -> Bool = { r, c in (r + c) % 2 == 0 }

            ZStack {
                // 1. Watercolor splash BEHIND the winning strike.
                //    Two blurred blobs centered along the anti-diagonal.
                ZStack {
                    WatercolorFill(color: accent, intensity: 0.30, blobs: 4, seed: 71)
                        .frame(width: s * 0.7, height: s * 0.35)
                        .rotationEffect(.degrees(-45))
                        .offset(x: 0, y: 0)
                }
                .frame(width: s, height: s)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .opacity(0.95)

                // 2. Grid + marks + strike, all in one Canvas.
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed: 5151)
                    // ---- Grid ----
                    for i in 1...2 {
                        let x = origin.x + CGFloat(i) * cell
                        let v = HandDrawn.wobblyPath(
                            from: CGPoint(x: x + rng.next(-1.4, 1.4), y: origin.y - 4),
                            to:   CGPoint(x: x + rng.next(-1.4, 1.4), y: origin.y + s + 4),
                            wobble: 1.8, segmentLength: 9, rng: &rng
                        )
                        ctx.stroke(v, with: .color(stroke.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        let y = origin.y + CGFloat(i) * cell
                        let h = HandDrawn.wobblyPath(
                            from: CGPoint(x: origin.x - 4, y: y + rng.next(-1.4, 1.4)),
                            to:   CGPoint(x: origin.x + s + 4, y: y + rng.next(-1.4, 1.4)),
                            wobble: 1.8, segmentLength: 9, rng: &rng
                        )
                        ctx.stroke(h, with: .color(stroke.opacity(0.85)),
                                   style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    }

                    // ---- X / O marks ----
                    let inset = cell * 0.22
                    for r in 0..<3 {
                        for c in 0..<3 {
                            let cellRect = CGRect(
                                x: origin.x + CGFloat(c) * cell + inset,
                                y: origin.y + CGFloat(r) * cell + inset,
                                width: cell - inset * 2,
                                height: cell - inset * 2
                            )
                            if isX(r, c) {
                                drawMultiX(ctx: ctx, in: cellRect, color: stroke, rng: &rng)
                            } else {
                                drawMultiO(ctx: ctx, in: cellRect, color: accent,
                                           seed: UInt64((r * 3 + c) * 19 + 1), rng: &rng)
                            }
                            // Mark the winning cells in the seed comment.
                            _ = isWinningCell(r, c)
                        }
                    }

                    // ---- Winning red strike (anti-diagonal) ----
                    let strikeStart = CGPoint(
                        x: origin.x + s - cell * 0.20,
                        y: origin.y + cell * 0.20
                    )
                    let strikeEnd = CGPoint(
                        x: origin.x + cell * 0.20,
                        y: origin.y + s - cell * 0.20
                    )
                    // 2-pass strike: thick wobbly halo + crisper top stroke
                    let halo = HandDrawn.wobblyPath(
                        from: strikeStart, to: strikeEnd,
                        wobble: 1.5, segmentLength: 12, rng: &rng
                    )
                    ctx.stroke(halo, with: .color(accent.opacity(0.40)),
                               style: StrokeStyle(lineWidth: max(5, cell * 0.10), lineCap: .round))
                    let strike = HandDrawn.wobblyPath(
                        from: strikeStart, to: strikeEnd,
                        wobble: 1.8, segmentLength: 10, rng: &rng
                    )
                    ctx.stroke(strike, with: .color(accent),
                               style: StrokeStyle(lineWidth: max(2.8, cell * 0.055), lineCap: .round))
                }
            }
        }
    }

    /// Multi-stroke X: each diagonal is 3 parallel wobbly strokes
    /// — total 6 strokes per X. Looks like the player went over
    /// the X with the pencil a couple of times.
    private func drawMultiX(
        ctx: GraphicsContext,
        in rect: CGRect,
        color: Color,
        rng: inout SeededRandom
    ) {
        let inset = rect.width * 0.12
        let tl = CGPoint(x: rect.minX + inset, y: rect.minY + inset)
        let br = CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        let tr = CGPoint(x: rect.maxX - inset, y: rect.minY + inset)
        let bl = CGPoint(x: rect.minX + inset, y: rect.maxY - inset)
        drawMultiLine(ctx: ctx, from: tl, to: br, color: color, rng: &rng)
        drawMultiLine(ctx: ctx, from: tr, to: bl, color: color, rng: &rng)
    }

    /// Multi-circle O: 3 wobbly concentric-ish circles, slightly
    /// offset / different radii, layered to read as a thick re-drawn
    /// loop.
    private func drawMultiO(
        ctx: GraphicsContext,
        in rect: CGRect,
        color: Color,
        seed: UInt64,
        rng: inout SeededRandom
    ) {
        let base = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
        for i in 0..<3 {
            // Slightly different radius per pass.
            let dx = rng.next(-1.4, 1.4)
            let dy = rng.next(-1.4, 1.4)
            let inset = CGFloat(i) * 0.7 - 0.7
            let r = base.insetBy(dx: inset, dy: inset).offsetBy(dx: dx, dy: dy)
            let path = SketchCircle(seed: seed &+ UInt64(i * 7), wobbleScale: 1.2)
                .path(in: r)
            // Middle pass is the darkest/widest; the other two are
            // accent passes layered behind for the "redrawn" feel.
            let isMain = (i == 1)
            ctx.stroke(
                path,
                with: .color(color.opacity(isMain ? 0.95 : 0.65)),
                style: StrokeStyle(
                    lineWidth: isMain ? max(2.0, rect.width * 0.08) : max(1.3, rect.width * 0.05),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
    }

    /// 3-stroke parallel bundle — used by drawMultiX and reusable
    /// for any "drawn forcefully" line. Center stroke at full
    /// opacity/width; outer two at low opacity, slightly offset
    /// perpendicular to the line direction.
    private func drawMultiLine(
        ctx: GraphicsContext,
        from a: CGPoint,
        to b: CGPoint,
        color: Color,
        rng: inout SeededRandom
    ) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, sqrt(dx * dx + dy * dy))
        let nx = -dy / len, ny = dx / len
        let passes = 3
        for i in 0..<passes {
            let t = (CGFloat(i) - CGFloat(passes - 1) / 2) * 1.4
            let offA = CGPoint(x: a.x + nx * t, y: a.y + ny * t)
            let offB = CGPoint(x: b.x + nx * t, y: b.y + ny * t)
            let path = HandDrawn.wobblyPath(
                from: offA, to: offB,
                wobble: 1.0, segmentLength: 8, rng: &rng
            )
            let isMain = (i == passes / 2)
            ctx.stroke(
                path,
                with: .color(color.opacity(isMain ? 0.95 : 0.55)),
                style: StrokeStyle(
                    lineWidth: isMain ? 2.6 : 1.6,
                    lineCap: .round
                )
            )
        }
    }

    // MARK: - Dots & Boxes

    /// Live-board-style Dots & Boxes illustration. Layout matches the
    /// in-game board: a 4×4 grid of pencil-shaded dots, colored-pencil
    /// edges, and watercolor-filled cells where a box has been closed.
    ///
    /// Pre-populated game state for the illustration:
    ///   - (0,0) closed by ME (blue)
    ///   - (0,2) closed by THEM (red)
    ///   - (1,1) closed by ME (blue)
    ///   - (2,2) closed by THEM (red)
    /// All 16 edges that bound those 4 cells are drawn in their
    /// owner's color; a few stray edges add the "mid-game" feel.
    private var dotsAndBoxesBoard: some View {
        GeometryReader { geo in
            // Always 5 rows (matches live board), but the column count
            // is derived from the container's aspect ratio so the dot
            // field fills the entire rectangle horizontally — no empty
            // bands on the left/right of a wide hero illustration.
            //
            // The 5×5 "playable" sub-grid stays centered; extra columns
            // on each side carry dots only (no boxes / no edges) so the
            // visual reads as a bigger board the player has scrolled in.
            let rowCount = 5
            let pad = min(geo.size.width, geo.size.height) * 0.05
            let usableH = max(1, geo.size.height - pad * 2)
            let stepY = usableH / CGFloat(rowCount - 1)
            // Use the same step on the X axis so dots are uniformly
            // spaced — square cells, just more of them.
            let stepX = stepY
            let totalDotsAcross = max(rowCount, min(15, Int(round((geo.size.width - pad * 2) / stepX)) + 1))
            let gridWidth = stepX * CGFloat(totalDotsAcross - 1)
            let originX = (geo.size.width - gridWidth) / 2
            let originY = pad
            // Where the playable 5-column "game area" sits inside the
            // wider dot field. Boxes are offset by this when drawn.
            let gameStartCol = (totalDotsAcross - rowCount) / 2
            let dotSize = max(6, stepY * 0.30)

            ZStack {
                // 1. Watercolor wash inside the 4 closed boxes.
                ForEach(boxes, id: \.id) { box in
                    let c = box.c + gameStartCol
                    let topLeft = CGPoint(
                        x: originX + CGFloat(c) * stepX,
                        y: originY + CGFloat(box.r) * stepY
                    )
                    WatercolorFill(
                        color: box.isMe ? stroke : accent,
                        intensity: 0.40,
                        blobs: 3,
                        seed: UInt64(box.r * 10 + c + 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .frame(width: stepX - 2, height: stepY - 2)
                    .position(x: topLeft.x + stepX / 2,
                              y: topLeft.y + stepY / 2)
                }

                // 2. Colored-pencil edges (3-pass: halo + crisp main).
                Canvas { ctx, _ in
                    var rng = SeededRandom(seed: 411)
                    for (edge, isMe) in edges {
                        let c1 = edge.c1 + gameStartCol
                        let c2 = edge.c2 + gameStartCol
                        let a = CGPoint(x: originX + CGFloat(c1) * stepX,
                                         y: originY + CGFloat(edge.r1) * stepY)
                        let b = CGPoint(x: originX + CGFloat(c2) * stepX,
                                         y: originY + CGFloat(edge.r2) * stepY)
                        let color = isMe ? stroke : accent
                        let path = HandDrawn.wobblyPath(
                            from: a, to: b,
                            wobble: 1.4, segmentLength: 7, rng: &rng
                        )
                        ctx.stroke(path, with: .color(color.opacity(0.28)),
                                   style: StrokeStyle(lineWidth: max(3, dotSize * 0.55),
                                                       lineCap: .round))
                        ctx.stroke(path, with: .color(color.opacity(0.95)),
                                   style: StrokeStyle(lineWidth: max(1.8, dotSize * 0.30),
                                                       lineCap: .round))
                    }
                }

                // 3. Pencil-scribbled dots — drawn across ALL columns
                //    so the left/right sides of a wide rectangle are
                //    filled with the same dot grid.
                ForEach(0..<rowCount, id: \.self) { r in
                    ForEach(0..<totalDotsAcross, id: \.self) { c in
                        let center = CGPoint(
                            x: originX + CGFloat(c) * stepX,
                            y: originY + CGFloat(r) * stepY
                        )
                        PencilDot(size: dotSize, seed: UInt64(r * 100 + c + 1))
                            .position(center)
                    }
                }
            }
        }
    }

    /// Cells claimed in the illustration. Two for each player so the
    /// mini-board teaches the rules at a glance.
    private struct DBIllustBox: Identifiable {
        let r: Int
        let c: Int
        let isMe: Bool
        var id: String { "\(r)-\(c)" }
    }

    private struct DBIllustEdge: Hashable {
        let r1: Int; let c1: Int
        let r2: Int; let c2: Int
    }

    /// Cells claimed in the illustration. On the 5×5 dot grid the
    /// playable cells are (0,0)…(3,3). Two for each player, spread
    /// across the board so the illustration reads as mid-game.
    private var boxes: [DBIllustBox] {
        [
            .init(r: 0, c: 0, isMe: true),    // top-left, blue
            .init(r: 0, c: 3, isMe: false),   // top-right, red
            .init(r: 2, c: 1, isMe: true),    // middle, blue
            .init(r: 3, c: 3, isMe: false)    // bottom-right, red
        ]
    }

    /// (edge, isMe). Each edge is drawn once in its owner's color.
    /// Computed from the four claimed boxes — each box contributes
    /// its 4 surrounding edges.
    private var edges: [(DBIllustEdge, Bool)] {
        var out: [(DBIllustEdge, Bool)] = []
        var seen: Set<DBIllustEdge> = []
        for box in boxes {
            let topLeft     = DBIllustEdge(r1: box.r,     c1: box.c,     r2: box.r,     c2: box.c + 1)
            let bottomLeft  = DBIllustEdge(r1: box.r + 1, c1: box.c,     r2: box.r + 1, c2: box.c + 1)
            let leftTop     = DBIllustEdge(r1: box.r,     c1: box.c,     r2: box.r + 1, c2: box.c)
            let rightTop    = DBIllustEdge(r1: box.r,     c1: box.c + 1, r2: box.r + 1, c2: box.c + 1)
            for e in [topLeft, bottomLeft, leftTop, rightTop] where !seen.contains(e) {
                seen.insert(e)
                out.append((e, box.isMe))
            }
        }
        return out
    }

    // MARK: - Hangman

    private func drawHangman(_ ctx: GraphicsContext, size: CGSize) {
        var rng = SeededRandom(seed: 8881)
        let pad: CGFloat = 8
        let postX = pad + size.width * 0.18
        let baseY = size.height - pad - 4
        let topY  = pad + 2
        let beamX = postX + size.width * 0.48
        let strokeColor = stroke

        // ---- 2D gallows (filled beams + hatch) ----
        // Scale beam thickness to icon size so it reads at both
        // home-card (~80pt) and game-detail (~160pt) sizes.
        let beamWidth = max(5, min(size.width, size.height) * 0.06)

        // Local helper: filled wobbly beam with diagonal hatch fill.
        func filledBeam(from a: CGPoint, to b: CGPoint, width: CGFloat) {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, sqrt(dx * dx + dy * dy))
            let ux = dx / len, uy = dy / len
            let px = -uy, py = ux
            let h = width / 2
            let p1 = CGPoint(x: a.x + px * h, y: a.y + py * h)
            let p2 = CGPoint(x: b.x + px * h, y: b.y + py * h)
            let p3 = CGPoint(x: b.x - px * h, y: b.y - py * h)
            let p4 = CGPoint(x: a.x - px * h, y: a.y - py * h)
            let outlineStyle = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            for (sa, sb) in [(p1, p2), (p2, p3), (p3, p4), (p4, p1)] {
                let path = HandDrawn.wobblyPath(from: sa, to: sb,
                                                 wobble: 0.5, segmentLength: 6, rng: &rng)
                ctx.stroke(path, with: .color(strokeColor), style: outlineStyle)
            }
            var rectPath = Path()
            rectPath.move(to: p1); rectPath.addLine(to: p2)
            rectPath.addLine(to: p3); rectPath.addLine(to: p4)
            rectPath.closeSubpath()
            var clipCtx = ctx
            clipCtx.clip(to: rectPath)
            let extent = max(width, len) + 30
            let cx = (a.x + b.x) / 2
            let cy = (a.y + b.y) / 2
            let dAngle: CGFloat = 0.785398
            let hdx = cos(dAngle), hdy = sin(dAngle)
            var offset: CGFloat = -extent
            while offset < extent {
                let ox = cx + hdy * offset
                let oy = cy - hdx * offset
                let hatchPath = HandDrawn.wobblyPath(
                    from: CGPoint(x: ox - hdx * extent, y: oy - hdy * extent),
                    to:   CGPoint(x: ox + hdx * extent, y: oy + hdy * extent),
                    wobble: 0.3, segmentLength: 10, rng: &rng
                )
                clipCtx.stroke(
                    hatchPath,
                    with: .color(strokeColor.opacity(Double(rng.next(0.30, 0.65)))),
                    style: StrokeStyle(lineWidth: rng.next(0.5, 0.9), lineCap: .round)
                )
                offset += 3.2 + rng.next(-0.5, 0.5)
            }
        }

        func multiLine(from a: CGPoint, to b: CGPoint, passes: Int = 3, spread: CGFloat = 0.9) {
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(0.001, sqrt(dx * dx + dy * dy))
            let nx = -dy / len, ny = dx / len
            for i in 0..<passes {
                let t = (CGFloat(i) - CGFloat(passes - 1) / 2) * spread
                let path = HandDrawn.wobblyPath(
                    from: CGPoint(x: a.x + nx * t, y: a.y + ny * t),
                    to:   CGPoint(x: b.x + nx * t, y: b.y + ny * t),
                    wobble: 0.5, segmentLength: 5, rng: &rng
                )
                ctx.stroke(path,
                           with: .color(strokeColor.opacity(i == passes / 2 ? 0.95 : 0.55)),
                           style: StrokeStyle(lineWidth: i == passes / 2 ? 1.3 : 0.9, lineCap: .round))
            }
        }

        // Base + post + beam
        filledBeam(from: CGPoint(x: postX - size.width * 0.12, y: baseY),
                   to:   CGPoint(x: postX + size.width * 0.20, y: baseY),
                   width: beamWidth)
        filledBeam(from: CGPoint(x: postX, y: baseY),
                   to:   CGPoint(x: postX, y: topY + beamWidth / 2),
                   width: beamWidth)
        filledBeam(from: CGPoint(x: postX - beamWidth / 2, y: topY),
                   to:   CGPoint(x: beamX, y: topY),
                   width: beamWidth * 0.85)

        // L-bracket knee brace where post meets beam — matches the
        // in-game GallowsView so the home/detail illustration reads
        // as the same structure, not a simpler variant.
        let braceSize = beamWidth * 1.8
        let braceA = CGPoint(x: postX + beamWidth * 0.5, y: topY + beamWidth * 0.6)
        let braceB = CGPoint(x: postX + braceSize, y: topY + beamWidth * 0.6)
        let braceC = CGPoint(x: postX + beamWidth * 0.5, y: topY + braceSize)
        let braceStyle = StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        ctx.stroke(HandDrawn.wobblyPath(from: braceB, to: braceC,
                                         wobble: 0.4, segmentLength: 5, rng: &rng),
                   with: .color(strokeColor), style: braceStyle)
        ctx.stroke(HandDrawn.wobblyPath(from: braceA, to: braceB,
                                         wobble: 0.3, segmentLength: 5, rng: &rng),
                   with: .color(strokeColor.opacity(0.7)), style: braceStyle)
        ctx.stroke(HandDrawn.wobblyPath(from: braceA, to: braceC,
                                         wobble: 0.3, segmentLength: 5, rng: &rng),
                   with: .color(strokeColor.opacity(0.7)), style: braceStyle)

        // Rope
        let ropeStart = CGPoint(x: beamX, y: topY + beamWidth / 2)
        let ropeEnd = CGPoint(x: beamX, y: ropeStart.y + size.height * 0.10)
        let rope = HandDrawn.wobblyPath(
            from: ropeStart, to: ropeEnd,
            wobble: 0.3, segmentLength: 4, rng: &rng
        )
        ctx.stroke(rope, with: .color(strokeColor),
                   style: StrokeStyle(lineWidth: 1.0, lineCap: .round))

        // ---- Stick figure (multi-stroke head + bundle bodylines) ----
        let headR = size.height * 0.07
        let headRect = CGRect(
            x: ropeEnd.x - headR,
            y: ropeEnd.y,
            width: headR * 2, height: headR * 2
        )
        for i in 0..<2 {
            let dx = rng.next(-0.8, 0.8)
            let dy = rng.next(-0.8, 0.8)
            let r = headRect.offsetBy(dx: dx, dy: dy)
            let path = SketchCircle(seed: UInt64(5500 + i * 17),
                                     wobbleScale: 1.2).path(in: r)
            ctx.stroke(path,
                       with: .color(strokeColor.opacity(i == 0 ? 0.95 : 0.6)),
                       style: StrokeStyle(lineWidth: i == 0 ? 1.4 : 1.0, lineCap: .round, lineJoin: .round))
        }

        let bodyTop = CGPoint(x: ropeEnd.x, y: ropeEnd.y + headR * 2)
        let bodyBottom = CGPoint(x: ropeEnd.x, y: bodyTop.y + size.height * 0.15)
        multiLine(from: bodyTop, to: bodyBottom)

        let armY = bodyTop.y + size.height * 0.04
        multiLine(from: CGPoint(x: bodyTop.x, y: armY),
                  to:   CGPoint(x: bodyTop.x - size.width * 0.10, y: armY + size.height * 0.08))
        multiLine(from: CGPoint(x: bodyTop.x, y: armY),
                  to:   CGPoint(x: bodyTop.x + size.width * 0.10, y: armY + size.height * 0.08))
        multiLine(from: bodyBottom,
                  to:   CGPoint(x: bodyBottom.x - size.width * 0.08, y: bodyBottom.y + size.height * 0.07))
        multiLine(from: bodyBottom,
                  to:   CGPoint(x: bodyBottom.x + size.width * 0.08, y: bodyBottom.y + size.height * 0.07))

        // ---- Word blanks under the figure ----
        let blankY = size.height - pad - 1
        let totalW = size.width * 0.5
        let segs: CGFloat = 4
        let gap = totalW / segs
        let startX = (size.width - totalW) / 2
        for i in 0..<Int(segs) {
            let x1 = startX + CGFloat(i) * gap + 2
            let x2 = startX + CGFloat(i + 1) * gap - 4
            let blank = HandDrawn.wobblyPath(
                from: CGPoint(x: x1, y: blankY),
                to:   CGPoint(x: x2, y: blankY),
                wobble: 0.4, segmentLength: 6, rng: &rng
            )
            ctx.stroke(blank, with: .color(strokeColor),
                       style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    // MARK: - Stop sign + landscape paper

    /// Two-part Stop! illustration:
    ///   * Top — octagonal STOP sign, outlined in red with the
    ///     interior filled by dense diagonal pencil hatching so the
    ///     sign reads as "colored in," not an outlined badge.
    ///   * Bottom — landscape "game paper" card with a header bar
    ///     and 5 columns separated by vertical pencil lines. Mimics
    ///     the real Tutti Frutti / Stop! score sheet players fill
    ///     out in person.
    private func drawStopSign(_ ctx: GraphicsContext, size: CGSize) {
        var rng = SeededRandom(seed: 9112)

        // Sign sits in the upper ~45% of the canvas, paper card
        // fills the lower ~50%, small gap between them.
        let signRadius = min(size.width, size.height) * 0.20
        let signCenter = CGPoint(
            x: size.width / 2,
            y: signRadius + 4
        )

        // ---- STOP sign: octagon clipped + dense diagonal hatch ----

        var octagon = Path()
        for i in 0..<8 {
            let angle = (Double(i) / 8.0) * 2 * .pi - .pi / 8
            let x = signCenter.x + cos(angle) * signRadius
            let y = signCenter.y + sin(angle) * signRadius
            if i == 0 {
                octagon.move(to: CGPoint(x: x, y: y))
            } else {
                octagon.addLine(to: CGPoint(x: x, y: y))
            }
        }
        octagon.closeSubpath()

        // Clip-and-hatch fill in red pen color. Dense diagonals
        // (~2.6pt spacing) read as "colored in with a marker" the
        // way a real stop sign is painted.
        var hatchCtx = ctx
        hatchCtx.clip(to: octagon)
        let extent = signRadius * 2.4
        let dAngle: CGFloat = 0.785398    // 45°
        let hdx = cos(dAngle), hdy = sin(dAngle)
        var offset: CGFloat = -extent
        while offset < extent {
            let ox = signCenter.x + hdy * offset
            let oy = signCenter.y - hdx * offset
            let hatch = HandDrawn.wobblyPath(
                from: CGPoint(x: ox - hdx * extent, y: oy - hdy * extent),
                to:   CGPoint(x: ox + hdx * extent, y: oy + hdy * extent),
                wobble: 0.4, segmentLength: 10, rng: &rng
            )
            hatchCtx.stroke(
                hatch,
                with: .color(accent.opacity(Double(rng.next(0.45, 0.85)))),
                style: StrokeStyle(lineWidth: rng.next(0.7, 1.3), lineCap: .round)
            )
            offset += 2.6 + rng.next(-0.4, 0.4)
        }

        // Crisp octagon outline drawn on top of the hatch.
        ctx.stroke(
            octagon,
            with: .color(accent),
            style: StrokeStyle(lineWidth: max(1.4, signRadius * 0.08),
                               lineCap: .round, lineJoin: .round)
        )

        // "STOP" in the brand ink-blue. Sits on top of the red
        // hatched fill — high contrast and stays on-brand instead
        // of using the standard white road-sign text.
        let stopText = Text("STOP")
            .font(.caveat(signRadius * 0.85, weight: .bold))
            .foregroundColor(stroke)
        ctx.draw(stopText, at: signCenter)

        // ---- Landscape game-paper card ----

        let paperTop = signCenter.y + signRadius + 8
        let paperBottom = size.height - 4
        let paperHeight = max(0, paperBottom - paperTop)
        if paperHeight < 12 { return }

        let paperRect = CGRect(
            x: 4,
            y: paperTop,
            width: size.width - 8,
            height: paperHeight
        )

        // Paper outline — wobbly rounded rectangle.
        let paperPath = Path(roundedRect: paperRect, cornerRadius: 4)
        ctx.stroke(
            paperPath,
            with: .color(stroke.opacity(0.85)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round)
        )

        // Header bar at the top of the paper — separates "column
        // titles" from the row area.
        let headerY = paperRect.minY + max(4, paperRect.height * 0.18)
        let headerLine = HandDrawn.wobblyPath(
            from: CGPoint(x: paperRect.minX + 4, y: headerY),
            to:   CGPoint(x: paperRect.maxX - 4, y: headerY),
            wobble: 0.3, segmentLength: 6, rng: &rng
        )
        ctx.stroke(
            headerLine,
            with: .color(stroke),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
        )

        // 5 columns → 4 vertical dividers, evenly spaced.
        let columnCount = 5
        let columnWidth = paperRect.width / CGFloat(columnCount)
        for i in 1..<columnCount {
            let x = paperRect.minX + CGFloat(i) * columnWidth
            let divider = HandDrawn.wobblyPath(
                from: CGPoint(x: x, y: paperRect.minY + 4),
                to:   CGPoint(x: x, y: paperRect.maxY - 4),
                wobble: 0.3, segmentLength: 6, rng: &rng
            )
            ctx.stroke(
                divider,
                with: .color(stroke.opacity(0.85)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
            )
        }

        // Column header marks — short rectangles suggesting
        // category names in each header cell.
        for i in 0..<columnCount {
            let cx = paperRect.minX + CGFloat(i) * columnWidth + columnWidth / 2
            let cy = paperRect.minY + (headerY - paperRect.minY) / 2
            let titleWidth = columnWidth * 0.55
            let titleRect = CGRect(
                x: cx - titleWidth / 2,
                y: cy - 1.2,
                width: titleWidth,
                height: 2.4
            )
            ctx.fill(
                Path(roundedRect: titleRect, cornerRadius: 1),
                with: .color(stroke.opacity(0.8))
            )
        }

        // Empty answer lines in each column (only when paper is
        // tall enough that the lines visually separate).
        if paperHeight > 36 {
            let rowCount = 2
            let usableTop = headerY + 4
            let usableBottom = paperRect.maxY - 4
            let rowGap = (usableBottom - usableTop) / CGFloat(rowCount + 1)
            for ri in 1...rowCount {
                let y = usableTop + rowGap * CGFloat(ri)
                for ci in 0..<columnCount {
                    let cx = paperRect.minX + CGFloat(ci) * columnWidth + 4
                    let endX = paperRect.minX + CGFloat(ci + 1) * columnWidth - 4
                    let blank = HandDrawn.wobblyPath(
                        from: CGPoint(x: cx, y: y),
                        to:   CGPoint(x: endX, y: y),
                        wobble: 0.25, segmentLength: 5, rng: &rng
                    )
                    ctx.stroke(
                        blank,
                        with: .color(stroke.opacity(0.55)),
                        style: StrokeStyle(lineWidth: 0.7, lineCap: .round)
                    )
                }
            }
        }
    }

    // MARK: - Sketching

    /// Sand Snake card art: a meandering ridge of pushed-up sand with a
    /// grub ahead of it. Teaches the concept at a glance — you see the
    /// disturbance, never the snake.
    private func drawSandSnake(_ ctx: GraphicsContext, size: CGSize) {
        var rng = SeededRandom(seed: 512)
        let inset: CGFloat = 10
        let w = size.width - inset * 2
        let h = size.height - inset * 2

        // Sand bed.
        let bed = Path(roundedRect: CGRect(x: inset, y: inset, width: w, height: h), cornerRadius: 6)
        ctx.fill(bed, with: .color(Color.gridGray.opacity(0.20)))
        ctx.stroke(bed, with: .color(stroke.opacity(0.45)), lineWidth: 1)

        // A serpentine spine across the card.
        let steps = 7
        var pts: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = inset + w * (0.10 + t * 0.72)
            let y = inset + h * (0.62 + 0.26 * sin(t * .pi * 2.1))
            pts.append(CGPoint(x: x, y: y))
        }
        var spine = Path()
        spine.move(to: pts[0])
        for i in 1..<pts.count {
            let prev = pts[i - 1], cur = pts[i]
            spine.addQuadCurve(to: cur, control: CGPoint(x: (prev.x + cur.x) / 2, y: prev.y))
        }
        let ridge = min(w, h) * 0.17
        ctx.stroke(spine, with: .color(Color.gridGray.opacity(0.85)),
                   style: StrokeStyle(lineWidth: ridge, lineCap: .round, lineJoin: .round))
        ctx.stroke(spine.offsetBy(dx: -ridge * 0.10, dy: -ridge * 0.12),
                   with: .color(Color.cream.opacity(0.8)),
                   style: StrokeStyle(lineWidth: ridge * 0.32, lineCap: .round, lineJoin: .round))
        ctx.stroke(spine, with: .color(stroke.opacity(0.30)), lineWidth: 1)

        // Head mound at the leading end.
        if let head = pts.last {
            let mound = HandDrawn.wobblyArc(center: head, radius: ridge * 0.62,
                                            startDeg: 0, endDeg: 360, wobble: 1.4, rng: &rng)
            ctx.fill(mound, with: .color(Color.gridGray.opacity(0.9)))
            ctx.stroke(mound, with: .color(stroke.opacity(0.45)), lineWidth: 1.2)
        }

        // Grub it's heading for.
        let grub = CGPoint(x: inset + w * 0.90, y: inset + h * 0.34)
        let body = HandDrawn.wobblyArc(center: grub, radius: min(w, h) * 0.055,
                                       startDeg: 20, endDeg: 300, wobble: 1.0, rng: &rng)
        ctx.stroke(body, with: .color(Color.redPen.opacity(0.85)), lineWidth: 2)

        // Settled tremor behind the tail.
        if let tail = pts.first {
            for r in 0..<2 {
                let ring = HandDrawn.wobblyArc(
                    center: tail, radius: ridge * (0.45 + CGFloat(r) * 0.35),
                    startDeg: 0, endDeg: 360, wobble: 1.0, rng: &rng
                )
                ctx.stroke(ring, with: .color(Color.gridGray.opacity(0.45 - Double(r) * 0.15)), lineWidth: 1)
            }
        }
    }

    private func drawSketching(_ ctx: GraphicsContext, size: CGSize) {
        let rect = CGRect(x: 8, y: 8, width: size.width - 16, height: size.height - 16)
        var pad = Path(roundedRect: rect, cornerRadius: 4)
        ctx.stroke(pad, with: .color(stroke.opacity(0.5)))

        var scribble = Path()
        scribble.move(to: CGPoint(x: rect.minX + 12, y: rect.maxY - 14))
        scribble.addCurve(to: CGPoint(x: rect.maxX - 12, y: rect.minY + 16),
                          control1: CGPoint(x: rect.midX, y: rect.maxY - 30),
                          control2: CGPoint(x: rect.midX, y: rect.minY + 22))
        ctx.stroke(scribble, with: .color(accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        var pencilTip = Path()
        pencilTip.move(to: CGPoint(x: rect.maxX - 8, y: rect.minY + 8))
        pencilTip.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.minY + 22))
        ctx.stroke(pencilTip, with: .color(stroke), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }
}

#Preview {
    HStack {
        ForEach(GameType.allCases) { g in
            VStack {
                GameIllustration(game: g)
                    .frame(width: 90, height: 90)
                    .sketchBorder()
                Text(g.title).font(.caveat(14, weight: .bold)).foregroundStyle(Color.inkBlue)
            }
        }
    }
    .padding()
    .background(GraphPaperView())
}
