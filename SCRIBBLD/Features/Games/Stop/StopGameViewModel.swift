import Foundation
import SwiftUI

@MainActor
final class StopGameViewModel: ObservableObject {
    enum Phase: Equatable {
        case categorySetup
        case letterReveal
        case playing
        case scoring(roundIndex: Int)
        case roundComplete(roundIndex: Int)
        case gameComplete
    }

    @Published var phase: Phase = .categorySetup
    @Published var game: StopGame
    @Published var currentAnswers: [StopCategoryKey: String] = [:]
    @Published var activeCategory: StopCategoryKey?
    @Published var timeRemaining: TimeInterval
    @Published var displayedLetter: Character = "A"
    @Published var letterRevealing: Bool = false
    @Published var stopFlashVisible: Bool = false
    @Published var validations: [UUID: [StopCategoryKey: Bool]] = [:]

    private var tickTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?

    /// Seconds the player gets to finish writing after SOMEONE ELSE calls
    /// STOP. Live multiplayer already had this; solo did not, so a Hard AI
    /// calling STOP a few seconds into a round ended it instantly and most of
    /// the player's answers were never entered at all. That is what "my
    /// answers aren't all showing up" was.
    static let graceDuration: TimeInterval = 10

    /// Non-nil while the grace countdown is running. Input stays live.
    /// Pass & Play: true while the handoff screen is up, so the next player
    /// can't see what the previous one wrote.
    @Published private(set) var awaitingHandoff: Bool = false
    @Published private(set) var graceRemaining: TimeInterval?
    /// Who shouted STOP, for the countdown overlay.
    @Published private(set) var graceCallerName: String?

    /// Pass & Play: two people share the phone and take turns filling the
    /// same letter, instead of racing AI opponents.
    let isPassAndPlay: Bool
    /// Index into `game.players` of whoever is currently holding the phone.
    /// Only meaningful in Pass & Play.
    @Published private(set) var entrantIndex: Int = 0
    /// Answers already banked this round, keyed by player.
    private var roundEntries: [UUID: [StopCategoryKey: String]] = [:]

    var currentEntrant: StopPlayer { game.players[min(entrantIndex, game.players.count - 1)] }
    var isLastEntrant: Bool { entrantIndex >= game.players.count - 1 }

    init(language: GameLanguage = AppLanguage.current,
         categories: [StopCategoryKey] = StopPreset.classic.keys,
         totalRounds: Int = 8,
         roundDuration: TimeInterval = 180,
         opponents: [AIDifficulty] = [.medium, .medium],
         passAndPlay: Bool = false) {
        self.isPassAndPlay = passAndPlay
        // Localized "You" label so the score sheet doesn't show
        // "Tú" on an English device.
        let youLabel: String = (language == .spanish ? "Tú" : "You")
        let you = StopPlayer(name: passAndPlay ? (language == .spanish ? "Jugador 1" : "Player 1") : youLabel,
                             isYou: true)
        let bots: [StopPlayer]
        if passAndPlay {
            // Second human, no AI. `isYou` is true for both so neither gets
            // auto-filled answers or calls STOP on its own.
            bots = [StopPlayer(name: language == .spanish ? "Jugador 2" : "Player 2", isYou: true)]
        } else {
            bots = opponents.enumerated().map { idx, diff in
                StopPlayer(name: ["Lulu", "Tito", "Inés"][idx % 3], isYou: false, aiDifficulty: diff)
            }
        }
        self.game = StopGame(
            players: [you] + bots,
            categories: categories,
            language: language,
            roundDuration: roundDuration,
            totalRounds: totalRounds
        )
        self.timeRemaining = roundDuration
    }

    // MARK: - Public actions

    func startGame() {
        phase = .letterReveal
        Task { await runLetterReveal() }
    }

    func tapRow(_ category: StopCategoryKey) {
        guard phase == .playing else { return }
        activeCategory = category
        HapticEngine.light()
    }

    func updateAnswer(_ category: StopCategoryKey, _ text: String) {
        guard phase == .playing else { return }
        currentAnswers[category] = text
    }

    /// Pass & Play only: bank the current player's answers and either hand
    /// the phone over or, if everyone has written, go to scoring.
    func finishEntrantTurn() {
        guard isPassAndPlay, phase == .playing else { return }
        roundEntries[currentEntrant.id] = currentAnswers
        HapticEngine.medium()
        if isLastEntrant {
            endRound(reason: .stopCalled, calledBy: currentEntrant.id)
        } else {
            entrantIndex += 1
            currentAnswers = Dictionary(uniqueKeysWithValues: game.categories.map { ($0, "") })
            activeCategory = game.categories.first
            timeRemaining = game.roundDuration
            awaitingHandoff = true
            cancelTasks()
        }
    }

    /// The next player has confirmed they're holding the phone.
    func beginEntrantTurn() {
        guard isPassAndPlay else { return }
        awaitingHandoff = false
        startTicker()
    }

    func callStop() {
        guard phase == .playing else { return }
        // The player chose to stop, so there's nothing to protect them from —
        // end immediately. Grace exists for the person who *didn't* call it.
        HapticEngine.heavy()
        stopFlashVisible = true
        graceTask?.cancel(); graceTask = nil
        graceRemaining = nil
        endRound(reason: .stopCalled, calledBy: game.human.id)
    }

    /// Someone else called STOP: freeze the main clock, show a countdown, and
    /// keep input live so the player can finish the word they're on.
    private func beginGrace(calledBy caller: StopPlayer) {
        guard phase == .playing, graceRemaining == nil else { return }
        tickTask?.cancel(); tickTask = nil
        aiTask?.cancel(); aiTask = nil
        graceCallerName = caller.name
        graceRemaining = Self.graceDuration
        stopFlashVisible = true
        HapticEngine.heavy()

        graceTask = Task { [weak self] in
            guard let self else { return }
            while true {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
                let done: Bool = await MainActor.run {
                    guard let left = self.graceRemaining else { return true }
                    let next = left - 0.1
                    if next <= 0 {
                        self.graceRemaining = 0
                        return true
                    }
                    self.graceRemaining = next
                    if Int(ceil(next)) <= 3, abs(next - Double(Int(ceil(next)))) < 0.06 {
                        HapticEngine.light()
                    }
                    return false
                }
                if done { break }
            }
            await MainActor.run {
                guard self.phase == .playing else { return }
                self.graceRemaining = nil
                self.graceCallerName = nil
                self.endRound(reason: .stopCalled, calledBy: nil)
            }
        }
    }

    func continueAfterScoring() {
        guard case .scoring(let idx) = phase else { return }
        applyScoresAndCheckCompletion(roundIndex: idx)
    }

    func reset() {
        cancelTasks()
        game.rounds.removeAll()
        game.currentRoundIndex = 0
        game.usedLetters.removeAll()
        for i in game.players.indices { game.players[i].totalScore = 0 }
        currentAnswers.removeAll()
        validations.removeAll()
        timeRemaining = game.roundDuration
        phase = .categorySetup
    }

    // MARK: - Helpers

    var human: StopPlayer { game.human }
    var letter: Character { displayedLetter }
    var roundNumber: Int { game.currentRoundIndex + 1 }
    var languageHint: String {
        let templ = (game.language == .english) ? "Starts with %@!" : "¡Empieza con %@!"
        return String(format: templ, String(displayedLetter))
    }

    var stopPhrase: String {
        if game.language == .english { return "Stop!" }
        let options = ["¡Basta para mí, basta para todos!", "¡Tutti frutti!", "¡Alto el lápiz!"]
        return options.randomElement() ?? "¡Stop!"
    }

    var timeUpPhrase: String {
        game.language == .english ? "Time's up!" : "¡Se acabó el tiempo!"
    }

    var letterRevealPhrase: String {
        game.language == .english ? "The letter is…" : "La letra es…"
    }

    var leaderboard: [StopPlayer] {
        game.players.sorted { $0.totalScore > $1.totalScore }
    }

    var filledCount: Int {
        currentAnswers.values.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // MARK: - Round lifecycle

    private func runLetterReveal() async {
        letterRevealing = true
        let pool = StopLetterPool.letters(for: game.language).filter { !game.usedLetters.contains($0) }
        guard let final = pool.randomElement() else {
            phase = .gameComplete
            return
        }
        // Slot-machine: 12 quick swaps with ease-out.
        let ticks = 14
        for i in 0..<ticks {
            displayedLetter = pool.randomElement() ?? "A"
            HapticEngine.light()
            let delayMs = 60 + UInt64(Double(i) * 22) // accelerate-then-decelerate feel
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
        }
        displayedLetter = final
        game.usedLetters.insert(final)
        HapticEngine.heavy()
        try? await Task.sleep(nanoseconds: 350_000_000)
        beginPlaying()
    }

    private func beginPlaying() {
        currentAnswers = Dictionary(uniqueKeysWithValues: game.categories.map { ($0, "") })
        timeRemaining = game.roundDuration
        activeCategory = game.categories.first
        letterRevealing = false
        // Every round starts back at the first player with an empty bank.
        entrantIndex = 0
        roundEntries.removeAll()
        awaitingHandoff = false
        phase = .playing
        startTicker()
        scheduleAIStop()
    }

    private func startTicker() {
        cancelTasks()
        tickTask = Task { [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    self.tick(delta: 0.1)
                }
                if await self.phase != .playing { break }
            }
        }
    }

    private func tick(delta: TimeInterval) {
        guard phase == .playing else { return }
        // Don't drain the next player's clock while the handoff screen is up.
        guard !awaitingHandoff else { return }
        timeRemaining = max(0, timeRemaining - delta)
        // Threshold haptics
        if timeRemaining > 0 {
            let secondsLeft = Int(ceil(timeRemaining))
            if secondsLeft == 10 && abs(timeRemaining - 10) < delta { HapticEngine.medium() }
            if secondsLeft <= 3 && abs(timeRemaining - Double(secondsLeft)) < delta { HapticEngine.light() }
        } else {
            HapticEngine.heavy()
            endRound(reason: .timeExpired, calledBy: nil)
        }
    }

    private func scheduleAIStop() {
        guard !isPassAndPlay else { return }
        // Allow AI to STOP only after round 5 globally, and only if it has filled enough.
        aiTask = Task { [weak self] in
            guard let self = self else { return }
            let roundNumber = await self.roundNumber
            guard roundNumber >= 5 else { return }
            let opponents = await self.game.players.filter { $0.aiDifficulty == .hard }
            guard let aggressive = opponents.first else { return }
            let delay = Double.random(in: (aggressive.aiDifficulty?.thinkingDelay ?? 1.5...4.0))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if await self.phase == .playing, await self.graceRemaining == nil {
                await self.beginGrace(calledBy: aggressive)
            }
        }
    }

    private func endRound(reason: EndReason, calledBy: UUID?) {
        guard phase == .playing else { return }
        cancelTasks()
        graceRemaining = nil
        graceCallerName = nil

        let snapshot = currentAnswers
        var round = StopRound(roundNumber: roundNumber, letter: displayedLetter)
        round.endReason = reason
        round.stopCalledBy = calledBy

        if isPassAndPlay {
            // Every player is human and wrote their own answers; the current
            // entrant's are still in the live buffer.
            roundEntries[currentEntrant.id] = snapshot
            for player in game.players {
                round.answers[player.id] = roundEntries[player.id]
                    ?? Dictionary(uniqueKeysWithValues: game.categories.map { ($0, "") })
            }
            roundEntries.removeAll()
        } else {

        // Human answers
        round.answers[human.id] = snapshot

        // AI answers
        for player in game.players where !player.isYou {
            guard let diff = player.aiDifficulty else { continue }
            var aiAnswers: [StopCategoryKey: String] = [:]
            for cat in game.categories {
                if Double.random(in: 0...1) <= diff.fillProbability,
                   let word = StopAIWordBank.answer(for: cat, letter: displayedLetter, language: game.language) {
                    aiAnswers[cat] = word
                } else {
                    aiAnswers[cat] = ""
                }
            }
            round.answers[player.id] = aiAnswers
        }
        }

        game.rounds.append(round)
        // Default-valid grid: cells with text marked true, blanks false.
        var initial: [UUID: [StopCategoryKey: Bool]] = [:]
        for (pid, answers) in round.answers {
            initial[pid] = Dictionary(uniqueKeysWithValues: game.categories.map { cat in
                let text = (answers[cat] ?? "").trimmingCharacters(in: .whitespaces)
                let startsRight = text.first.map { Character($0.uppercased()) == Character(displayedLetter.uppercased()) } ?? false
                return (cat, !text.isEmpty && startsRight)
            })
        }
        validations = initial
        phase = .scoring(roundIndex: game.currentRoundIndex)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            stopFlashVisible = false
        }
    }

    private func applyScoresAndCheckCompletion(roundIndex: Int) {
        var round = game.rounds[roundIndex]
        // Build per-category map of valid normalized answers across players.
        var perCategoryAnswers: [StopCategoryKey: [(player: UUID, normalized: String)]] = [:]
        for (pid, answers) in round.answers {
            for cat in game.categories {
                let raw = (answers[cat] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                let validForPlayer = (validations[pid]?[cat] ?? false)
                guard validForPlayer, !raw.isEmpty else { continue }
                perCategoryAnswers[cat, default: []].append((player: pid, normalized: raw))
            }
        }

        // Score 100 unique / 50 shared, 0 otherwise.
        for cat in game.categories {
            let entries = perCategoryAnswers[cat] ?? []
            let counts = Dictionary(grouping: entries, by: \.normalized).mapValues(\.count)
            for entry in entries {
                let score = (counts[entry.normalized] ?? 0) == 1 ? 100 : 50
                round.scores[entry.player, default: [:]][cat] = score
            }
            for player in game.players {
                if round.scores[player.id]?[cat] == nil {
                    round.scores[player.id, default: [:]][cat] = 0
                }
            }
        }

        // Stop bonus / penalty.
        if let caller = round.stopCalledBy {
            let fillCounts: [(UUID, Int)] = game.players.map { p in
                let answers = round.answers[p.id] ?? [:]
                let count = game.categories.reduce(0) { acc, cat in
                    let text = (answers[cat] ?? "").trimmingCharacters(in: .whitespaces)
                    return acc + (text.isEmpty ? 0 : 1)
                }
                return (p.id, count)
            }
            let topFill = fillCounts.map(\.1).max() ?? 0
            let callerFill = fillCounts.first(where: { $0.0 == caller })?.1 ?? 0
            round.stopBonus = (callerFill == topFill && topFill > 0) ? 50 : -25
            round.scores[caller, default: [:]][game.categories[0]] = (round.scores[caller]?[game.categories[0]] ?? 0) + round.stopBonus
        }

        game.rounds[roundIndex] = round

        // Apply totals.
        for player in game.players {
            let roundScore = (round.scores[player.id] ?? [:]).values.reduce(0, +)
            if let idx = game.players.firstIndex(where: { $0.id == player.id }) {
                game.players[idx].totalScore += roundScore
            }
        }

        if game.currentRoundIndex + 1 >= game.totalRounds {
            phase = .gameComplete
            HapticEngine.success()
        } else {
            phase = .roundComplete(roundIndex: roundIndex)
            HapticEngine.medium()
        }
    }

    func startNextRoundFromComplete() {
        game.currentRoundIndex += 1
        currentAnswers.removeAll()
        validations.removeAll()
        phase = .letterReveal
        Task { await runLetterReveal() }
    }

    private func cancelTasks() {
        tickTask?.cancel(); tickTask = nil
        aiTask?.cancel(); aiTask = nil
        graceTask?.cancel(); graceTask = nil
    }
}
