import SwiftUI
import UIKit

struct PostGameView: View {
    let result: GameResult
    var restart: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var heroVisible = false
    @State private var showShare = false
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }
    private var es: Bool { lang == .spanish }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView().ignoresSafeArea()
            backgroundWash

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    topBar
                    hero
                    stats
                    streakRow
                    ctaButtons
                    BannerAdView(adUnitID: AdConfig.Banner.postGame)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .navigationBarLeading) { backButton } }
        .task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                heroVisible = true
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [shareText])
        }
    }

    private var backgroundWash: some View {
        ZStack {
            WatercolorFill(color: .inkBlue, intensity: 0.22, blobs: 4, seed: 41)
                .frame(width: 340, height: 240)
                .offset(x: -70, y: -260)
            WatercolorFill(color: .redPen, intensity: 0.22, blobs: 4, seed: 73)
                .frame(width: 340, height: 240)
                .offset(x: 100, y: -120)
        }
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            ScribbldWordmark(size: 20)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "pencil.tip")
                    .foregroundStyle(Color.inkBlue)
                VStack(alignment: .leading, spacing: 0) {
                    Text(appState.displayName)
                        .font(.dmSans(13, weight: .semibold))
                        .foregroundStyle(Color.inkBlue)
                    Text("\(appState.totalPoints) pts")
                        .font(.dmSans(11))
                        .foregroundStyle(Color.softGray)
                }
            }
        }
    }

    private var hero: some View {
        // These two lines used to be pulled together by a fixed -8 spacing
        // plus a -4 top padding (-12pt total). Caveat's line box is 1.26×
        // the font size and its descenders reach ~0.21× below the baseline,
        // which left only ~2pt of clearance at the default text size — and
        // *negative* clearance whenever the boxes shrink but the fixed -12pt
        // doesn't: small Dynamic Type sizes, and long/Spanish headlines where
        // minimumScaleFactor kicks in. That's the overlapping characters on
        // the game-over screen. Caveat is tight enough on its own.
        VStack(spacing: 0) {
            FlourishedHeadline(text: headline.0)
            FlourishedHeadline(text: headline.1, size: 36)
        }
        .scaleEffect(heroVisible ? 1 : 0.85)
        .opacity(heroVisible ? 1 : 0)
        .padding(.top, 24)
    }

    private var stats: some View {
        VStack(alignment: .center, spacing: 16) {
            StatRow(label: es ? "Puntaje final" : "Final Score",
                    value: "\(result.score) pts")
            if let correct = result.correctAnswers, let total = result.totalAnswers {
                StatRow(label: es ? "Respuestas correctas" : "Correct Answers",
                        value: "\(correct)/\(total)")
            }
            HStack(spacing: 6) {
                Text("\u{1F525}")
                StatRow(label: es ? "Tiempo" : "Game Time", value: result.formattedDuration)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var streakRow: some View {
        HStack(spacing: 12) {
            Text("STREAK:")
                .font(.dmSans(12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Color.inkBlue)
            Text("\u{1F525} \(appState.streak.currentStreak) Games")
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(Color.redPen)
                .lineLimit(1)
                // Caveat's "G" and the digit tails overrun their advance
                // width; without this the trailing glyph clips against the
                // Spacer.
                .padding(.trailing, 4)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            TallyMarksView(count: appState.streak.currentStreak, color: .redPen)
                .frame(height: 22)
        }
    }

    private var ctaButtons: some View {
        HStack(spacing: 10) {
            ctaButton(title: es ? "Volver" : "Back", color: .inkBlue, icon: "chevron.left") {
                dismiss()
            }
            // Was labelled "New Challenge", which read as "invite someone"
            // rather than "run it back". Only shown when the presenting game
            // actually wired a restart handler.
            if restart != nil {
                ctaButton(title: es ? "Jugar otra vez" : "Play Again",
                          color: .inkBlue, icon: "arrow.counterclockwise") {
                    restart?()
                }
            }
            ctaButton(title: es ? "Compartir" : "Share",
                      color: .redPen, icon: "square.and.arrow.up") {
                showShare = true
            }
        }
        .padding(.bottom, 30)
    }

    private func ctaButton(title: String, color: Color, icon: String? = nil, action: @escaping () -> Void) -> some View {
        let seed = UInt64(title.hashValue & 0xFFFF)
        return Button(action: {
            HapticEngine.light()
            action()
        }) {
            VStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(.caveat(18, weight: .bold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, minHeight: 70)
            .padding(.horizontal, 8)
            // Light wash + sketch border — no crosshatch, matches the
            // restyled PencilButtonStyle in the rest of the app.
            .background(
                WatercolorFill(color: color, intensity: 0.12, blobs: 3, seed: seed)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
            .sketchBorder(color: color, lineWidth: 1.8, cornerRadius: 10, jitter: 1.4, seed: seed &+ 31)
        }
        .buttonStyle(.plain)
    }

    private var backButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
        }
    }

    private var headline: (String, String) {
        switch (result.outcome, es) {
        case (.win, true):   return ("Impecable.", "Les ganaste.")
        case (.loss, true):  return ("Casi.", "¿Revancha?")
        case (.draw, true):  return ("Muy parejo.", "¿Otra vez?")
        case (.win, false):  return ("Sharp.", "You got them.")
        case (.loss, false): return ("So close.", "Rematch?")
        case (.draw, false): return ("Evenly matched.", "Play again?")
        }
    }

    private var shareText: String {
        es
        ? "¡Hice \(result.score) pts en SCRIBBLD! \u{1F58A} ¿Puedes ganarme?"
        : "I scored \(result.score) pts in SCRIBBLD! \u{1F58A} Can you beat me?"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("\(label):")
                    .font(.dmSans(15, weight: .medium))
                    .foregroundStyle(Color.inkBlue)
                Text(value)
                    .font(.dmSans(15, weight: .semibold))
                    .foregroundStyle(Color.inkBlue)
            }
            PencilLineView(color: .redPen, lineWidth: 2, amplitude: 1.2, wavelength: 18, seed: UInt64(label.hashValue & 0xFFFF))
                .frame(width: 200, height: 6)
                .offset(y: -2)
        }
    }
}

struct FlourishedHeadline: View {
    let text: String
    var size: CGFloat = 50

    // Previously this was a ZStack that positioned each flourish at
    // `±min(text.count * size * 0.18, 130)` — an *estimate* of half the text
    // width from the character count. Caveat is proportional (an "i" and a
    // "W" are nowhere near the same width) and the estimate was capped at
    // 130pt, so any headline wider than ~260pt had its flourishes land on
    // top of the glyphs. That's the "overlapping characters" on the
    // game-over screen, and it got worse in Spanish, where the strings are
    // longer. An HStack puts the flourishes beside the text by
    // construction, so no width estimate is involved at all.
    var body: some View {
        HStack(spacing: 10) {
            flourish
                .offset(y: -2)
            // Must be InkBoundsLabel, not Text. "Play again?" and "Rematch?"
            // end in "?", whose ink overruns its advance width by 0.161 of
            // the font size — and trailing padding cannot fix that, because
            // it widens the parent while Text still clips inside its own
            // rendering rect. Measuring by ink bounds is the only fix.
            InkBoundsLabel.caveat(
                text,
                size: size,
                color: .inkBlue,
                minimumScaleFactor: 0.5
            )
            .layoutPriority(1)
            flourish
                .rotationEffect(.degrees(180))
                .offset(y: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var flourish: some View {
        FlourishShape()
            .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 24, height: 18)
            // Never let the decoration squeeze the headline.
            .layoutPriority(0)
    }
}

struct FlourishShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY - rect.height * 0.4),
            control2: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.maxY + rect.height * 0.4)
        )
        return p
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        PostGameView(result: GameResult(
            game: .ticTacToe, outcome: .win, score: 4850, correctAnswers: 24,
            totalAnswers: 25, durationSeconds: 758, date: Date()
        ))
        .environmentObject(AppState())
        .environmentObject(StoreManager())
    }
}
