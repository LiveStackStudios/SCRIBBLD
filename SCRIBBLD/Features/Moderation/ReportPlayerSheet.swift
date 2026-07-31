import SwiftUI

/// Report and/or block a player. Presented from the Friends tab and from a
/// live game, so a player is always one tap from acting on someone abusive —
/// App Store Guideline 1.2 requires both mechanisms, and requires them to be
/// reachable where the objectionable content actually appears.
struct ReportPlayerSheet: View {
    let peerUID: String
    let displayName: String
    /// Where the report came from ("friends", "liveGame:stop", …) — recorded
    /// with the report so it can be triaged without asking the reporter.
    let context: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var moderation = ModerationService.shared
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }
    private var es: Bool { lang == .spanish }

    @State private var reason: ReportReason = .offensiveContent
    @State private var note: String = ""
    @State private var alsoBlock = true
    @State private var working = false
    @State private var done = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cream.ignoresSafeArea()
                GraphPaperView(lineOpacity: 0.14).ignoresSafeArea()

                if done {
                    confirmation
                } else {
                    form
                }
            }
            .navigationTitle(es ? "Reportar jugador" : "Report Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(es ? "Cancelar" : "Cancel") { dismiss() }
                        .foregroundStyle(Color.inkBlue)
                }
            }
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(es ? "Reportando a \(displayName)" : "Reporting \(displayName)")
                    .font(.caveat(26, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 6)
                    .fixedSize(horizontal: false, vertical: true)

                Text(es
                     ? "Revisamos cada reporte. Cuéntanos qué pasó."
                     : "We review every report. Tell us what happened.")
                    .font(.dmSans(13))
                    .foregroundStyle(Color.softGray)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ReportReason.allCases) { r in
                        Button {
                            HapticEngine.light()
                            reason = r
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: reason == r ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(reason == r ? Color.redPen : Color.softGray)
                                Text(r.title(in: lang))
                                    .font(.dmSans(14))
                                    .foregroundStyle(Color.inkBlue)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(es ? "Detalles (opcional)" : "Details (optional)")
                        .font(.dmSans(12, weight: .semibold))
                        .foregroundStyle(Color.softGray)
                    TextEditor(text: $note)
                        .font(.dmSans(14))
                        .frame(height: 90)
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lightLine, lineWidth: 1))
                }

                Toggle(isOn: $alsoBlock) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(es ? "Bloquear también" : "Also block this player")
                            .font(.dmSans(14, weight: .semibold))
                            .foregroundStyle(Color.inkBlue)
                        Text(es
                             ? "No podrán invitarte ni enviarte solicitudes."
                             : "They won't be able to invite you or send requests.")
                            .font(.dmSans(11))
                            .foregroundStyle(Color.softGray)
                    }
                }
                .tint(Color.redPen)

                if failed {
                    Text(es ? "No se pudo enviar. Inténtalo de nuevo."
                            : "Couldn't send that. Please try again.")
                        .font(.dmSans(12))
                        .foregroundStyle(Color.redPen)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if working {
                        ProgressView().tint(Color.cream)
                    } else {
                        Text(es ? "Enviar reporte" : "Submit Report")
                    }
                }
                .buttonStyle(PencilButtonFilledStyle(color: .redPen, height: 50, seed: 17))
                .disabled(working)
            }
            .padding(Spacing.lg)
        }
    }

    private var confirmation: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.inkGreen)
            Text(es ? "Reporte enviado" : "Report sent")
                .font(.caveat(28, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .padding(.trailing, 6)
                .fixedSize(horizontal: false, vertical: true)
            Text(alsoBlock
                 ? (es ? "Bloqueamos a \(displayName) y revisaremos el reporte."
                       : "\(displayName) is blocked and we'll review the report.")
                 : (es ? "Gracias — revisaremos el reporte."
                       : "Thanks — we'll review the report."))
                .font(.dmSans(13))
                .foregroundStyle(Color.softGray)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(es ? "Listo" : "Done") { dismiss() }
                .buttonStyle(PencilButtonStyle(color: .inkBlue, height: 46, seed: 5))
                .padding(.top, 6)
        }
        .padding(28)
    }

    private func submit() async {
        working = true
        failed = false
        defer { working = false }
        let ok = await moderation.report(
            peerUID: peerUID,
            displayName: displayName,
            reason: reason,
            note: note,
            context: context
        )
        guard ok else { failed = true; return }
        if alsoBlock {
            await moderation.block(peerUID, displayName: displayName)
        }
        HapticEngine.success()
        done = true
    }
}
