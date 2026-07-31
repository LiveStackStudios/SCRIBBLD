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
            Section(t("Appearance", "Apariencia")) {
                NavigationLink {
                    InkProView()
                } label: {
                    HStack {
                        Text(t("Midnight Ink (Ink Pro)", "Tinta nocturna (Ink Pro)"))
                        Spacer()
                        if !store.status.isPro {
                            Text(t("Locked", "Bloqueado")).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section(t("Hangman Style", "Estilo Ahorcado")) {
                Picker("", selection: $friendlyHangman) {
                    Text(t("Classic", "Clásico")).tag(false)
                    Text(t("Friendly", "Amigable")).tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section(t("Ink Pro", "Ink Pro")) {
                HStack {
                    Text(store.status.isPro
                         ? t("Subscribed", "Suscrito")
                         : t("Free Tier", "Versión gratuita"))
                    Spacer()
                    Button(store.status.isPro
                           ? t("Manage", "Administrar")
                           : t("Upgrade", "Mejorar")) {
                        showPaywall = true
                    }
                }
                Button(t("Restore Purchases", "Restaurar compras")) {
                    Task { await store.restore() }
                }
            }
            Section(t("About", "Acerca de")) {
                Text(t("Version 0.1 (1)", "Versión 0.1 (1)"))
                Link(t("Privacy Policy", "Política de privacidad"),
                     destination: URL(string: "https://livestackstudios.com/privacy")!)
                Button(t("Rate SCRIBBLD", "Calificar SCRIBBLD")) {
                    HapticEngine.light()
                }
                Button(t("Tell a Friend", "Cuéntale a un amigo")) {
                    HapticEngine.light()
                }
                NavigationLink(t("Hand-drawn preview", "Vista previa dibujada")) {
                    HandDrawnPreviewView()
                }
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
        .sheet(isPresented: $showPaywall) {
            InkProView().environmentObject(store)
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
