import SwiftUI

struct StopScoringView: View {
    @ObservedObject var vm: StopGameViewModel

    var body: some View {
        guard case .scoring(let idx) = vm.phase else {
            return AnyView(EmptyView())
        }
        let round = vm.game.rounds[idx]
        return AnyView(
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView().ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        header(round: round)
                        ForEach(vm.game.categories) { cat in
                            categorySection(round: round, cat: cat)
                        }
                        cta
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                }
            }
        )
    }

    private func header(round: StopRound) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.game.language == .english ? "Round \(round.roundNumber) — letter \(String(round.letter))" : "Ronda \(round.roundNumber) — letra \(String(round.letter))")
                .font(.caveat(26, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                // Ends in the round's randomly-chosen capital, so on a good
                // share of rounds the last glyph is one of Caveat's worst
                // overshooters (I/F/T/S/Y/K) and clips without this.
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.trailing, 6)
                .fixedSize(horizontal: false, vertical: true)
                .zIndex(1)
            Text(vm.game.language == .english ? "Tap ✓ if the answer counts, ✗ to reject." : "Marca ✓ si vale, ✗ si no.")
                .font(.dmSans(12))
                .foregroundStyle(Color.softGray)
        }
    }

    private func categorySection(round: StopRound, cat: StopCategoryKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cat.displayName(in: vm.game.language))
                .font(.dmSans(11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.inkBlue)
            ForEach(vm.game.players) { player in
                AnswerRow(
                    name: player.name,
                    answer: round.answers[player.id]?[cat] ?? "",
                    isValid: vm.validations[player.id]?[cat] ?? false,
                    onToggle: { newValue in
                        vm.validations[player.id, default: [:]][cat] = newValue
                    }
                )
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.65))
        .sketchBorder(color: .lightLine, lineWidth: 1, cornerRadius: 8, jitter: 0.6, seed: UInt64(cat.rawValue.hashValue & 0xFFFF))
    }

    private var cta: some View {
        Button {
            HapticEngine.medium()
            vm.continueAfterScoring()
        } label: {
            HStack(spacing: 6) {
                Text(vm.game.language == .english ? "Apply scores" : "Aplicar puntaje")
                Image(systemName: "arrow.right")
            }
                .font(.caveat(22, weight: .bold))
                .foregroundStyle(Color.cream)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.inkBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

private struct AnswerRow: View {
    let name: String
    let answer: String
    let isValid: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.dmSans(13, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 56, alignment: .leading)
            // Answers are free text and routinely longer than one line at
            // caveat 20. lineLimit(1) in a flexible HStack truncated them
            // with an ellipsis — that's the "some of them are cut" report.
            Text(answer.isEmpty ? "—" : answer)
                .font(.caveat(20, weight: .bold))
                .foregroundStyle(answer.isEmpty ? Color.softGray : Color.inkBlue)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .multilineTextAlignment(.leading)
                .padding(.trailing, 5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Button { onToggle(true) } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isValid ? Color.inkGreen : Color.lightLine)
                }
                .buttonStyle(.plain)
                .disabled(answer.isEmpty)
                Button { onToggle(false) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(!isValid ? Color.redPen : Color.lightLine)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
