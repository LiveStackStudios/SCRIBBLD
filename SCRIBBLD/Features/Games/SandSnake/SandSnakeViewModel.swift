import Foundation
import SwiftUI

/// A cell on the sand grid. Origin is top-left, y grows downward to match
/// the drawing coordinate space.
struct SandGridPoint: Hashable {
    var x: Int
    var y: Int
}

enum SandDirection: Hashable {
    case up, down, left, right

    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up:    return (0, -1)
        case .down:  return (0, 1)
        case .left:  return (-1, 0)
        case .right: return (1, 0)
        }
    }

    /// Reversing straight into your own neck is an instant loss, and players
    /// read it as a bug rather than a mistake, so we reject it outright.
    var opposite: SandDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

/// A patch of sand still settling after the snake passed under it. Drives the
/// fading tremor trail — the only way the player can see where it has been.
struct SandDisturbance: Hashable {
    var cell: SandGridPoint
    /// Tick on which the snake vacated this cell.
    var bornAt: Int
    /// Stable per-patch seed so the scattered grains don't re-randomise on
    /// every frame — a crawling texture at 30fps is very distracting.
    var seed: UInt64
}

/// The three things that crawl on the sand. All are bugs; the colour is the
/// only tell, so they're kept far apart on the wheel.
enum SandBugKind: CaseIterable {
    /// Standard prey: one segment, one point.
    case grub
    /// Feast: grows you by twice the usual, worth double.
    case beetle
    /// Molt: sheds a quarter of your length. Still scores — the trade is
    /// board safety now against a shorter body to build back up.
    case molt

    var growth: Int {
        switch self {
        case .grub:   return 1
        case .beetle: return 2
        case .molt:   return 0
        }
    }

    var points: Int {
        switch self {
        case .grub:   return 1
        case .beetle: return 2
        case .molt:   return 1
        }
    }

    /// SF Symbol drawn on the sand — the same `ant.fill` used in the
    /// how-to-play card, so the instructions and the board agree.
    var symbol: String {
        switch self {
        case .grub:   return "ant.fill"
        case .beetle: return "ant.fill"
        case .molt:   return "ant.fill"
        }
    }
}

/// Sand Snake — the snake burrows *under* the sand, so you never see the
/// creature itself, only the ridge it pushes up and the tremor trail settling
/// behind it.
///
/// Rules are deliberately our own rather than a clone: walls are fatal, the
/// grub count drives speed, and eating leaves a lingering crater. The
/// mechanic family (grow-on-eat, die-on-self-collision) is not copyrightable
/// — the name, art, and theme here are all original to SCRIBBLD.
@MainActor
final class SandSnakeViewModel: ObservableObject {
    // Board. Portrait-friendly aspect; tuned so cells stay chunky enough for
    // the hand-drawn ridge to read on a phone.
    let cols = 13
    let rows = 17

    @Published private(set) var snake: [SandGridPoint] = []
    @Published private(set) var grub: SandGridPoint = .init(x: 0, y: 0)
    @Published private(set) var grubKind: SandBugKind = .grub
    @Published private(set) var direction: SandDirection = .up
    @Published private(set) var score = 0
    @Published private(set) var isGameOver = false
    @Published private(set) var isRunning = false
    @Published private(set) var hasStarted = false
    /// Fading trail of cells the snake has left, newest last.
    @Published private(set) var disturbances: [SandDisturbance] = []
    /// Bumped every tick; drives the tremor fade and the ridge shimmer.
    @Published private(set) var tick = 0
    /// Set briefly when a grub is eaten so the view can pop a crater.
    @Published private(set) var lastMealCell: SandGridPoint?

    @AppStorage("scribbld.sandsnake.best") private(set) var best = 0

    /// How long a vacated cell keeps showing tremor, in ticks.
    static let disturbanceLifetime = 6

    private var queuedDirection: SandDirection?
    private var loop: Task<Void, Never>?
    private var startedAt = Date()
    private var rngSeed: UInt64 = 1

    // Speed ramp: brisk to start, faster per grub, with a floor so it stays
    // playable rather than becoming a reflex lottery.
    private var interval: Double {
        max(0.09, 0.26 - Double(score) * 0.006)
    }

    init() { reset() }

    deinit { loop?.cancel() }

    // MARK: - Lifecycle

    func reset() {
        loop?.cancel()
        loop = nil
        let midX = cols / 2
        let midY = rows / 2
        // Head first. Starts pointing up with a short tail below it.
        snake = [
            SandGridPoint(x: midX, y: midY),
            SandGridPoint(x: midX, y: midY + 1),
            SandGridPoint(x: midX, y: midY + 2)
        ]
        direction = .up
        queuedDirection = nil
        score = 0
        tick = 0
        disturbances = []
        lastMealCell = nil
        isGameOver = false
        isRunning = false
        hasStarted = false
        placeGrub()
    }

    func start() {
        guard !isGameOver, !isRunning else { return }
        if !hasStarted {
            hasStarted = true
            startedAt = Date()
        }
        isRunning = true
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = await self.interval
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
                await self.step()
                if await !self.isRunning { return }
            }
        }
    }

    func pause() {
        isRunning = false
        loop?.cancel()
        loop = nil
    }

    func stop() { pause() }

    // MARK: - Input

    func steer(_ new: SandDirection) {
        // Compare against the direction the *next* step will use, not the
        // current one — otherwise two fast swipes in one tick (right then
        // down then left) can double back through the neck.
        let reference = queuedDirection ?? direction
        guard new != reference.opposite, new != reference else { return }
        queuedDirection = new
        if !isRunning && !isGameOver { start() }
    }

    // MARK: - Simulation

    private func step() {
        guard isRunning, !isGameOver else { return }
        if let queued = queuedDirection {
            direction = queued
            queuedDirection = nil
        }
        tick += 1

        let d = direction.delta
        guard let head = snake.first else { return }
        let next = SandGridPoint(x: head.x + d.dx, y: head.y + d.dy)

        // Wall.
        guard next.x >= 0, next.x < cols, next.y >= 0, next.y < rows else {
            endGame()
            return
        }
        // Self. The tail cell is about to move out from under us, so it's
        // only a collision when we're also growing this step.
        let willEat = (next == grub)
        let body = willEat ? snake : snake.dropLast()
        guard !body.contains(next) else {
            endGame()
            return
        }

        snake.insert(next, at: 0)
        if willEat {
            let kind = grubKind
            score += kind.points
            lastMealCell = next
            // `growth` counts EXTRA segments beyond the head we just added,
            // so growth 0 still means "stay the same length" — pop the tail.
            if kind.growth == 0 {
                shed()
            } else {
                for _ in 0..<(kind.growth - 1) {
                    if let tail = snake.last { snake.append(tail) }
                }
            }
            kind == .molt ? HapticEngine.medium() : HapticEngine.light()
            placeGrub()
        } else {
            if let vacated = snake.popLast() {
                disturbances.append(SandDisturbance(cell: vacated, bornAt: tick, seed: seedFor(vacated)))
            }
        }

        // Drop tremor that has fully settled.
        let cutoff = tick - Self.disturbanceLifetime
        if let firstLive = disturbances.firstIndex(where: { $0.bornAt > cutoff }) {
            if firstLive > 0 { disturbances.removeFirst(firstLive) }
        } else {
            disturbances.removeAll()
        }
    }

    /// Molt: drop a quarter of the body off the tail, never below the
    /// starting length. Every shed cell leaves tremor behind, so the molt
    /// reads as a burst of settling sand rather than segments vanishing.
    private func shed() {
        let target = max(3, Int((Double(snake.count) * 0.75).rounded()))
        while snake.count > target, let vacated = snake.popLast() {
            disturbances.append(SandDisturbance(cell: vacated, bornAt: tick, seed: seedFor(vacated)))
        }
    }

    private func seedFor(_ p: SandGridPoint) -> UInt64 {
        UInt64(abs(p.x &* 73856093 ^ p.y &* 19349663) % 100_000) &+ 1
    }

    private func nextRandom() -> UInt64 {
        rngSeed = rngSeed &* 6364136223846793005 &+ 1442695040888963407
        return rngSeed >> 33
    }

    private func placeGrub() {
        let occupied = Set(snake)
        var free: [SandGridPoint] = []
        free.reserveCapacity(cols * rows)
        for y in 0..<rows {
            for x in 0..<cols {
                let p = SandGridPoint(x: x, y: y)
                if !occupied.contains(p) { free.append(p) }
            }
        }
        guard !free.isEmpty else {
            // Board full — the player has genuinely won.
            endGame()
            return
        }
        grub = free[Int(nextRandom() % UInt64(free.count))]

        // Mostly ordinary grubs, so the specials stay events rather than
        // noise. The molt is only offered once you're long enough for
        // shedding a quarter to be a meaningful choice.
        let roll = nextRandom() % 100
        if roll < 15 {
            grubKind = .beetle
        } else if roll < 30 && snake.count >= 8 {
            grubKind = .molt
        } else {
            grubKind = .grub
        }
    }

    private func endGame() {
        isRunning = false
        isGameOver = true
        loop?.cancel()
        loop = nil
        if score > best { best = score }
        HapticEngine.error()
    }

    // MARK: - Result

    var elapsedSeconds: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }

    /// Score is grubs × 100 so it sits on the same order of magnitude as the
    /// other games' scores on the post-game screen.
    func makeResult() -> GameResult {
        GameResult(
            game: .sandSnake,
            // There's no opponent — a run "wins" if it beat the player's best.
            outcome: score > 0 && score >= best ? .win : .loss,
            score: score * 100,
            correctAnswers: score,
            totalAnswers: nil,
            durationSeconds: elapsedSeconds,
            date: Date()
        )
    }
}
