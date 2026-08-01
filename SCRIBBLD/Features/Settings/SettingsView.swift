import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var auth: AuthService
    @StateObject private var moderation = ModerationService.shared
    @AppStorage("scribbld.notifications.enabled") private var notificationsOn = true
    @AppStorage("scribbld.notifications.hour") private var reminderHour = 19
    @AppStorage("scribbld.sound") private var soundOn = true
    @AppStorage("scribbld.haptics") private var hapticsOn = true
    @AppStorage("scribbld.hangmanFriendly") private var friendlyHangman = false
    /// Global language preference (`scribbld.appLanguage` raw key).
    /// `""` = follow device locale; `"english"` / `"spanish"` = explicit.
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = ""

    @State private var showPaywall = false
    @State private var showShare = false

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var deleteError: String?

    /// Active language resolved from the stored preference. Drives all
    /// localized strings in this view.
    private var lang: GameLanguage { GameLanguage.resolve(from: languageRaw) }

    var body: some View {
        Form {
            Section(t("Language", "Idioma")) {
                Picker(t("App language", "Idioma de la app"), selection: $languageRaw) {
                    Text(t("Follow system", "Seguir sistema")).tag("")
                    Text("English").tag(GameLanguage.english.rawValue)
                    Text("Español").tag(GameLanguage.spanish.rawValue)
                }
                .pickerStyle(.menu)
            }
            Section(t("Notifications", "Notificaciones")) {
                Toggle(t("Daily reminder", "Recordatorio diario"), isOn: $notificationsOn)
                Stepper(
                    "\(t("Reminder hour", "Hora del recordatorio")): \(reminderHour):00",
                    value: $reminderHour, in: 6...22
                )
            }
            Section(t("Sound & Haptics", "Sonido y vibración")) {
                Toggle(t("Sound effects", "Efectos de sonido"), isOn: $soundOn)
                Toggle(t("Haptic feedback", "Vibración"), isOn: $hapticsOn)
                    .onChange(of: hapticsOn) { _, on in HapticEngine.enabled = on }
            }
            Section(t("Hangman Style", "Estilo Ahorcado")) {
                Picker("", selection: $friendlyHangman) {
                    Text(t("Classic", "Clásico")).tag(false)
                    Text(t("Friendly", "Amigable")).tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section(t("About", "Acerca de")) {
                // Read from the bundle — this used to be hardcoded "Version
                // 0.1 (1)", which was wrong in every shipped build.
                Text(t("Version", "Versión") + " \(Self.appVersion) (\(Self.buildNumber))")
                    .foregroundStyle(.secondary)
                // These pointed at livestackstudios.com/privacy, which 404s.
                Link(t("Privacy Policy", "Política de privacidad"),
                     destination: URL(string: "https://livestackstudios.github.io/SCRIBBLD/privacy-policy.html")!)
                Link(t("Terms of Use", "Términos de uso"),
                     destination: URL(string: "https://livestackstudios.github.io/SCRIBBLD/terms-of-use.html")!)
                Link(t("Support", "Soporte"),
                     destination: URL(string: "https://livestackstudios.github.io/SCRIBBLD/support.html")!)
                Button(t("Tell a Friend", "Cuéntale a un amigo")) {
                    HapticEngine.light()
                    showShare = true
                }
                // Developer-only visual test bench — must not ship.
                #if DEBUG
                NavigationLink(t("Hand-drawn preview", "Vista previa dibujada")) {
                    HandDrawnPreviewView()
                }
                #endif
            }
            if auth.isSignedIn {
                Section(t("Privacy & Safety", "Privacidad y seguridad")) {
                    NavigationLink(t("Blocked players", "Jugadores bloqueados")) {
                        BlockedPlayersView()
                    }
                }

                // App Store Guideline 5.1.1(v): an app offering account
                // creation must offer account deletion IN-APP. A support
                // email is explicitly not sufficient.
                Section {
                    Button(role: .destructive) {
                        HapticEngine.medium()
                        confirmDelete = true
                    } label: {
                        HStack {
                            if deleting { ProgressView().padding(.trailing, 6) }
                            Text(t("Delete Account", "Eliminar cuenta"))
                        }
                    }
                    .disabled(deleting)
                    if let deleteError {
                        Text(deleteError)
                            .font(.dmSans(12))
                            .foregroundStyle(Color.redPen)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } footer: {
                    Text(t(
                        "Permanently deletes your profile, friends, and games. This cannot be undone.",
                        "Elimina permanentemente tu perfil, amigos y partidas. No se puede deshacer."
                    ))
                }
            }

            Section {
                BannerAdView(adUnitID: AdConfig.Banner.home)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(t("Settings", "Ajustes"))
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [t(
                "SCRIBBLD - six hand-drawn paper games. Tic Tac Toe, Dots and Boxes, Hangman, Stop!, Sand Snake and a sketching canvas.",
                "SCRIBBLD - seis juegos de papel dibujados a mano. Tres en raya, Timbiriche, Ahorcado, ¡Stop!, Serpiente de Arena y un lienzo para dibujar."
            )])
        }
        .alert(t("Delete your account?", "¿Eliminar tu cuenta?"), isPresented: $confirmDelete) {
            Button(t("Cancel", "Cancelar"), role: .cancel) {}
            Button(t("Delete", "Eliminar"), role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text(t(
                "This removes your profile, your friends list, and your games for good. It cannot be undone.",
                "Esto elimina tu perfil, tu lista de amigos y tus partidas para siempre. No se puede deshacer."
            ))
        }
    }

    private func performDelete() async {
        deleting = true
        deleteError = nil
        defer { deleting = false }
        do {
            try await moderation.deleteAccount()
            // The Cloud Function deleted the Auth record and signed us out;
            // clear the published account so the UI leaves the signed-in state.
            await auth.forgetLocalSession()
            HapticEngine.success()
        } catch {
            deleteError = error.localizedDescription
            HapticEngine.error()
        }
    }

    /// Tiny EN/ES picker — keeps the localized strings inline next to
    /// the chrome they belong to, no Localizable.strings indirection
    /// for V1. If/when we add more languages we'll migrate to the
    /// standard iOS localization bundle.
    private func t(_ english: String, _ spanish: String) -> String {
        switch lang {
        case .spanish:   return spanish
        case .english:   return english
        case .bilingual: return english
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(StoreManager())
            .environmentObject(AuthService())
    }
}
