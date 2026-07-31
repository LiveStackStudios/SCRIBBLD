import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// The block list, with unblock. Apple expects a blocking mechanism to be
/// reversible and visible — a block you can't review or undo reads as a bug.
struct BlockedPlayersView: View {
    @StateObject private var moderation = ModerationService.shared
    @AppStorage(AppLanguage.storageKey) private var langRaw: String = ""
    private var lang: GameLanguage { GameLanguage.resolve(from: langRaw) }
    private var es: Bool { lang == .spanish }

    @State private var rows: [(uid: String, name: String)] = []

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.14).ignoresSafeArea()

            if rows.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.softGray)
                    Text(es ? "No has bloqueado a nadie." : "You haven't blocked anyone.")
                        .font(.dmSans(14))
                        .foregroundStyle(Color.softGray)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(rows, id: \.uid) { row in
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.xmark")
                                    .foregroundStyle(Color.redPen)
                                Text(row.name)
                                    .font(.dmSans(14, weight: .medium))
                                    .foregroundStyle(Color.inkBlue)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Button(es ? "Desbloquear" : "Unblock") {
                                    HapticEngine.light()
                                    Task {
                                        await moderation.unblock(row.uid)
                                        await load()
                                    }
                                }
                                .font(.dmSans(13, weight: .semibold))
                                .foregroundStyle(Color.inkBlue)
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lightLine, lineWidth: 1))
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
        }
        .navigationTitle(es ? "Bloqueados" : "Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: moderation.blockedUIDs) { _, _ in Task { await load() } }
    }

    private func load() async {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        guard RemoteBootstrap.isFirebaseConfigured,
              let me = Auth.auth().currentUser?.uid else { rows = []; return }
        let snap = try? await Firestore.firestore()
            .collection("users").document(me).collection("blocked")
            .getDocuments()
        rows = (snap?.documents ?? []).map {
            ($0.documentID, ($0.data()["displayName"] as? String) ?? (es ? "Jugador" : "Player"))
        }
        #endif
    }
}
