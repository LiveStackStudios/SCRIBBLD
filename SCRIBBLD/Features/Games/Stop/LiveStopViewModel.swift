import Foundation
import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Live Stop! / Tutti Frutti for two players. Each player writes only to
/// their own `answers.{uid}` subkey; whoever taps STOP first flips
/// `status = scoring`, which locks both clients' input.
@MainActor
final class LiveStopViewModel: ObservableObject {
    /// `lobby` — pre-game, waiting for joiners + host start (N>2 only).
    /// `playing` — round in progress, anyone can type freely.
    /// `grace` — STOP was called; 20 sec window for everyone to
    ///   finish typing what they have. Input stays enabled but a
    ///   big screen countdown is shown.
    /// `scoring` — N=2 cross-validation step; auto-skipped for N>2.
    /// `ended` — scores locked, winner known.
    enum Phase: String { case lobby, playing, grace, scoring, ended }

    /// How long the grace window lasts after a STOP call.
    static let gracePeriodSeconds: TimeInterval = 20

    @Published private(set) var phase: Phase = .lobby
    @Published private(set) var status: LiveGameStatus = .pending
    @Published private(set) var playerNames: [String: String] = [:]
    @Published private(set) var players: [String] = []        // ordered; first uid is host
    @Published private(set) var maxPlayers: Int = 2
    @Published private(set) var letter: Character = "A"
    @Published private(set) var categoryKeys: [StopCategoryKey] = []
    @Published private(set) var language: GameLanguage = AppLanguage.current
    @Published private(set) var startedAt: Date = Date()
    @Published private(set) var duration: TimeInterval = 180
    @Published private(set) var stoppedBy: String?
    /// Wall-clock end of the 20-second grace countdown after STOP.
    /// Nil while not in grace phase. Source of truth for the
    /// big screen countdown shown to all clients.
    @Published private(set) var graceEndsAt: Date?
    @Published private(set) var graceSecondsRemaining: Double = 0
    @Published private(set) var answers: [String: [String: String]] = [:]   // uid → cat → text
    @Published private(set) var validations: [String: [String: Bool]] = [:] // uid → cat → valid
    @Published private(set) var scores: [String: Int] = [:]
    @Published private(set) var winner: String?
    @Published private(set) var secondsRemaining: Double = 60
    @Published private(set) var lobbyError: String?
    @Published var pendingLocal: [StopCategoryKey: String] = [:]

    /// True when the local user is the host (first uid in `players`).
    var isHost: Bool { players.first == me.uid }

    /// True when this game uses lobby-based start + auto-scoring instead
    /// of the 2-player cross-validation UX.
    var isMultiPlayerLobby: Bool { maxPlayers > 2 }

    let gameId: String
    let me: AuthAccount
    private var tickTask: Task<Void, Never>?

    init(gameId: String, me: AuthAccount) {
        self.gameId = gameId
        self.me = me
    }

    var opponentUID: String? { playerNames.keys.first(where: { $0 != me.uid }) }
    var opponentName: String { (opponentUID.flatMap { playerNames[$0] }) ?? "Opponent" }

    func observe() {
        LiveGameService.shared.observe(gameId: gameId) { [weak self] doc in
            guard let self, let doc else { return }
            self.apply(doc: doc)
        }
        startTicker()
    }

    func stop() {
        LiveGameService.shared.stopObserving()
        tickTask?.cancel(); tickTask = nil
    }

    // MARK: - Player actions

    func updateAnswer(_ category: StopCategoryKey, _ text: String) {
        pendingLocal[category] = text
        // Debounce small writes — quickly typed letters all hit one push.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard pendingLocal[category] == text else { return }
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                guard doc.status == .active else { return nil }
                var answersMap = (doc.state["answers"] as? [String: [String: String]]) ?? [:]
                var mine = answersMap[self.me.uid] ?? [:]
                mine[category.rawValue] = text
                answersMap[self.me.uid] = mine
                var state = doc.state
                state["answers"] = answersMap
                return ["state": state]
            }
        }
    }

    func callStop() {
        guard phase == .playing else { return }
        HapticEngine.heavy()
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                guard doc.status == .active,
                      (doc.state["phase"] as? String) == "playing" else { return nil }
                var state = doc.state
                state["stoppedBy"] = self.me.uid
                state["phase"] = Phase.grace.rawValue
                // Grace window — wall-clock end time, so every client
                // counts down to the SAME moment regardless of clock
                // drift. Scoring runs when this point passes.
                let endsAt = Date().addingTimeInterval(Self.gracePeriodSeconds)
                state["graceEndsAt"] = Timestamp(date: endsAt)
                return ["state": state]
            }
        }
    }

    /// Transitions out of the grace window into scoring/ended.
    /// Triggered by any client's ticker when `Date() >= graceEndsAt`.
    /// Race-safe: each tx checks the phase is still `grace`, so the
    /// first writer wins and others no-op.
    private func finalizeAfterGrace() {
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                guard (doc.state["phase"] as? String) == "grace" else { return nil }
                var state = doc.state

                // N>2 games skip cross-validation — auto-score in one
                // transaction. Whoever ran this computes; calculation
                // is deterministic from the snapshot so clients agree.
                if doc.maxPlayers > 2 {
                    let computed = self.autoScore(doc)
                    let topScore = computed.values.max() ?? 0
                    let winners = computed.filter { $0.value == topScore }.keys
                    let winnerUID: Any = (winners.count == 1
                        ? (winners.first ?? "")
                        : "draw")
                    state["phase"] = Phase.ended.rawValue
                    state["scores"] = computed
                    return [
                        "state": state,
                        "status": LiveGameStatus.completed.rawValue,
                        "winner": winnerUID
                    ]
                }

                // 2-player path: enter the validation step.
                state["phase"] = Phase.scoring.rawValue
                return ["state": state]
            }
        }
    }

    func setValidation(player: String, category: StopCategoryKey, isValid: Bool) {
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                guard (doc.state["phase"] as? String) == "scoring" else { return nil }
                var state = doc.state
                var vals = (state["validations"] as? [String: [String: Bool]]) ?? [:]
                var byCat = vals[player] ?? [:]
                byCat[category.rawValue] = isValid
                vals[player] = byCat
                state["validations"] = vals
                return ["state": state]
            }
        }
    }

    func applyScores() {
        Task {
            try? await LiveGameService.shared.applyMove(gameId: gameId) { doc -> [String: Any]? in
                let cats = ((doc.state["categories"] as? [String]) ?? []).compactMap { StopCategoryKey(rawValue: $0) }
                let answersMap = (doc.state["answers"] as? [String: [String: String]]) ?? [:]
                let vals = (doc.state["validations"] as? [String: [String: Bool]]) ?? [:]
                let players = doc.players
                var scoreMap: [String: Int] = [:]
                for player in players { scoreMap[player] = 0 }

                for cat in cats {
                    var validByPlayer: [String: String] = [:]
                    for player in players {
                        let text = (answersMap[player]?[cat.rawValue] ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                        let valid = (vals[player]?[cat.rawValue] ?? false)
                        if valid && !text.isEmpty { validByPlayer[player] = text }
                    }
                    let counts = Dictionary(grouping: validByPlayer.values, by: { $0 }).mapValues(\.count)
                    for (player, text) in validByPlayer {
                        let pts = (counts[text] ?? 0) == 1 ? 100 : 50
                        scoreMap[player, default: 0] += pts
                    }
                }
                // STOP bonus / penalty
                if let stopper = doc.state["stoppedBy"] as? String {
                    let fills: [String: Int] = players.reduce(into: [:]) { acc, p in
                        let pAnswers = answersMap[p] ?? [:]
                        acc[p] = cats.reduce(0) { n, cat in
                            n + ((pAnswers[cat.rawValue] ?? "").trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
                        }
                    }
                    let topFill = fills.values.max() ?? 0
                    if let stopperFill = fills[stopper], stopperFill == topFill, topFill > 0 {
                        scoreMap[stopper, default: 0] += 50
                    } else {
                        scoreMap[stopper, default: 0] -= 25
                    }
                }
                let topScore = scoreMap.values.max() ?? 0
                let winners = scoreMap.filter { $0.value == topScore }.keys
                let winnerUID: Any = (winners.count == 1 ? (winners.first ?? "") : "draw")

                var state = doc.state
                state["phase"] = Phase.ended.rawValue
                state["scores"] = scoreMap
                return [
                    "state": state,
                    "status": LiveGameStatus.completed.rawValue,
                    "winner": winnerUID
                ]
            }
        }
    }

    // MARK: - Internal

    private func startTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while let self = self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    let currentPhase = self.phase
                    if currentPhase == .playing {
                        let elapsed = Date().timeIntervalSince(self.startedAt)
                        self.secondsRemaining = max(0, self.duration - elapsed)
                        if self.secondsRemaining == 0 {
                            // Round timer ran out — auto-trigger STOP
                            // on behalf of the time-out condition. Any
                            // client whose ticker hits 0 first wins the
                            // race; transaction guard makes it safe.
                            self.callStop()
                        }
                    } else if currentPhase == .grace, let endsAt = self.graceEndsAt {
                        let remaining = endsAt.timeIntervalSinceNow
                        self.graceSecondsRemaining = max(0, remaining)
                        if remaining <= 0 {
                            self.finalizeAfterGrace()
                        }
                    }
                }
                // Keep ticking while either round timer or grace
                // window is active. Stop when we hit scoring/ended.
                let p = await self.phase
                if p != .playing && p != .grace { break }
            }
        }
    }

    private func apply(doc: LiveGameDoc) {
        status = doc.status
        playerNames = doc.playerNames
        players = doc.players
        maxPlayers = doc.maxPlayers
        winner = doc.winner

        let letterRaw = (doc.state["letter"] as? String) ?? "A"
        letter = letterRaw.first ?? "A"
        categoryKeys = ((doc.state["categories"] as? [String]) ?? []).compactMap { StopCategoryKey(rawValue: $0) }
        if let langRaw = doc.state["language"] as? String, let lang = GameLanguage(rawValue: langRaw) {
            language = lang
        }
        if let ts = doc.state["startedAt"] as? Timestamp { startedAt = ts.dateValue() }
        if let dur = doc.state["duration"] as? Double { duration = dur }
        stoppedBy = doc.state["stoppedBy"] as? String
        // Grace window end-time (wall-clock). Nil unless we're in
        // the grace phase right now.
        if let ts = doc.state["graceEndsAt"] as? Timestamp {
            graceEndsAt = ts.dateValue()
        } else {
            graceEndsAt = nil
        }
        answers = (doc.state["answers"] as? [String: [String: String]]) ?? [:]
        validations = (doc.state["validations"] as? [String: [String: Bool]]) ?? [:]
        scores = (doc.state["scores"] as? [String: Int]) ?? [:]

        // Phase derivation: status=pending always means "in lobby"
        // (waiting for joiners or the host's Start tap). Once the doc
        // flips to active, the state.phase blob takes over.
        if status == .pending {
            phase = .lobby
        } else if let phaseRaw = doc.state["phase"] as? String, let p = Phase(rawValue: phaseRaw) {
            phase = p
        }
        // Keep ticking through both playing and grace phases —
        // ticker drives the grace countdown + scoring transition.
        if phase != .playing && phase != .grace {
            tickTask?.cancel()
            tickTask = nil
        } else if tickTask == nil {
            startTicker()
        }
    }

    // MARK: - Lobby actions (N>2 games)

    /// Host taps Start. Flips doc status to `active` and resets
    /// `startedAt` so the round-timer ticks from this moment.
    func startLobby() async {
        lobbyError = nil
        do {
            try await LiveGameService.shared.startLobbyGame(gameId: gameId, host: me)
            HapticEngine.success()
        } catch let nsError as NSError {
            lobbyError = nsError.localizedDescription
        } catch {
            lobbyError = "Couldn't start the game. Try again."
        }
    }

    /// Auto-scoring used by N>2 games — no cross-validation step.
    /// Standard Tutti Frutti rules: 10 for a unique non-empty answer,
    /// 5 if at least one other player gave the same word, 0 if blank.
    private func autoScore(_ doc: LiveGameDoc) -> [String: Int] {
        let cats = ((doc.state["categories"] as? [String]) ?? [])
            .compactMap { StopCategoryKey(rawValue: $0) }
        let answersMap = (doc.state["answers"] as? [String: [String: String]]) ?? [:]
        var scoreMap: [String: Int] = [:]
        for uid in doc.players { scoreMap[uid] = 0 }

        for cat in cats {
            var textByPlayer: [String: String] = [:]
            for uid in doc.players {
                let txt = (answersMap[uid]?[cat.rawValue] ?? "")
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                if !txt.isEmpty { textByPlayer[uid] = txt }
            }
            let counts = Dictionary(grouping: textByPlayer.values, by: { $0 })
                .mapValues(\.count)
            for (uid, txt) in textByPlayer {
                scoreMap[uid, default: 0] += ((counts[txt] ?? 0) == 1) ? 10 : 5
            }
        }
        return scoreMap
    }

    // MARK: - Init state generator

    static func initialState(language: GameLanguage = AppLanguage.current,
                             categories: [StopCategoryKey] = StopPreset.classic.keys,
                             duration: TimeInterval = 180) -> [String: Any] {
        let pool = StopLetterPool.letters(for: language)
        let letter = String(pool.randomElement() ?? "P")
        return [
            "phase": Phase.playing.rawValue,
            "letter": letter,
            "categories": categories.map(\.rawValue),
            "language": language.rawValue,
            "startedAt": Timestamp(date: Date()),
            "duration": duration,
            "answers": [String: [String: String]](),
            "validations": [String: [String: Bool]](),
            "scores": [String: Int]()
        ]
    }
}
