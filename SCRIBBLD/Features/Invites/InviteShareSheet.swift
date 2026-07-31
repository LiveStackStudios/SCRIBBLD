import SwiftUI
import UIKit

/// Hosting domain that backs our universal links. AASA file lives at
/// `https://<host>/.well-known/apple-app-site-association` and the
/// landing page handles `/i/<gameId>`.
enum InviteLink {
    static let host: String = "scribbld-prod.firebaseapp.com"

    /// Build the share URL for an outgoing invite. URL query params are
    /// non-authoritative hints used by the landing page + (if the app is
    /// installed) the pre-join blurb in `IncomingInviteView`.
    static func url(gameId: String, kind: LiveGameKind, inviterName: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = host
        comps.path = "/i/\(gameId)"
        comps.queryItems = [
            URLQueryItem(name: "k", value: kind.rawValue),
            URLQueryItem(name: "n", value: String(inviterName.prefix(24)))
        ]
        return comps.url ?? URL(string: "https://\(host)")!
    }
}

extension LiveGameKind {
    /// Absolute ceiling on participants, ignoring entitlement. TTT / D&B /
    /// Hangman are strictly 1-vs-1 turn-based games. Stop! is a simultaneous
    /// race that fits up to 5 players on one screen — beyond that the input
    /// UI gets unreadable. Mirrored by the `players.size() <= 5` backstop in
    /// firestore.rules.
    var maxPlayers: Int {
        switch self {
        case .ticTacToe, .dotsAndBoxes, .hangman: return 2
        case .stop:                                return 5
        }
    }

    /// Seats the *host* may open, given their subscription. Big-table Stop!
    /// is the headline Ink Pro perk: a subscriber hosts up to 5, everyone
    /// else hosts a straight 1-vs-1. Guests are never gated — joining a
    /// subscriber's 5-player lobby doesn't require the joiner to subscribe.
    static let freeStopPlayers = 2
    func maxPlayers(hostIsPro: Bool) -> Int {
        switch self {
        case .ticTacToe, .dotsAndBoxes, .hangman: return 2
        case .stop: return hostIsPro ? maxPlayers : LiveGameKind.freeStopPlayers
        }
    }

    /// Build the per-game initial Firestore `state` blob for an open
    /// invite. Mirrors the per-friend invite builder in
    /// `ChallengeFriendSheet` so both entry points seed identical games.
    @MainActor
    static func openInviteInitialState(kind: LiveGameKind, inviter: AuthAccount) -> [String: Any] {
        switch kind {
        case .ticTacToe:
            return ["cells": Array(repeating: "", count: 9)]
        case .dotsAndBoxes:
            return LiveDotsAndBoxesViewModel.initialState()
        case .hangman:
            let language = AppLanguage.current
            let pick = HangmanCategory.random(in: language)
            return LiveHangmanViewModel.initialState(
                word: pick.1,
                pickerUID: inviter.uid,
                category: pick.0.rawValue,
                language: language
            )
        case .stop:
            return LiveStopViewModel.initialState()
        }
    }

    /// Map a public `GameType` to a multiplayer `LiveGameKind`. Returns
    /// nil for `sketching` (solo only) — invite-friend mode shouldn't be
    /// reachable for that case.
    static func from(gameType: GameType) -> LiveGameKind? {
        switch gameType {
        case .ticTacToe:    return .ticTacToe
        case .dotsAndBoxes: return .dotsAndBoxes
        case .hangman:      return .hangman
        case .stop:         return .stop
        // Solo-only — no multiplayer counterpart to invite anyone into.
        case .sandSnake:    return nil
        case .sketching:    return nil
        }
    }
}

/// Identifiable wrapper so `.sheet(item:)` can present the share UI
/// keyed by gameId without re-firing on identical re-renders.
struct InviteShareTarget: Identifiable, Equatable {
    let url: URL
    let message: String
    var id: String { url.absoluteString }
}

/// Wraps `UIActivityViewController` so we can observe whether the user
/// actually completed a share (`completed = true`) vs cancelled out of
/// the sheet (`completed = false`). SwiftUI's `ShareLink` doesn't expose
/// that signal, and we need it to fire the "abandon on dismiss" cleanup.
struct InviteShareSheet: UIViewControllerRepresentable {
    let url: URL
    let message: String
    let onCompletion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any] = [InviteActivitySource(url: url, message: message)]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            // Callback fires on every dismissal — both successful share
            // (completed=true) and explicit cancel (completed=false).
            onCompletion(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Custom activity item source so SMS/Mail/etc. see a friendly subject
/// line + a clean URL attachment instead of one giant blob of text.
private final class InviteActivitySource: NSObject, UIActivityItemSource {
    let url: URL
    let message: String

    init(url: URL, message: String) {
        self.url = url
        self.message = message
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Mail bodies look nicer with the full message; everything else
        // (SMS, WhatsApp, Slack) gets the message followed by the URL,
        // which most clients auto-link.
        switch activityType {
        case .some(.mail), .some(.message):
            return message
        case .some(.copyToPasteboard):
            return url.absoluteString
        default:
            return message
        }
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        "Play SCRIBBLD with me"
    }
}
