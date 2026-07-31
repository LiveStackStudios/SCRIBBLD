import Foundation
import SwiftUI

/// Global user-facing language for the app. Sources of truth, in order:
///   1. User's explicit choice in Settings (`@AppStorage` value).
///   2. iOS device locale (Spanish locales → `.spanish`, else `.english`).
///
/// Reading from a view: use the `@AppStorage("scribbld.appLanguage")`
/// wrapper so SwiftUI automatically re-renders when the preference
/// changes. Outside of a view, call `AppLanguage.current`.
enum AppLanguage {
    /// UserDefaults key for the explicit user choice. Same key is
    /// referenced by `@AppStorage` in views.
    static let storageKey = "scribbld.appLanguage"

    /// Resolved language at this instant. Reads the explicit choice
    /// first, falls back to the device locale if unset or invalid.
    static var current: GameLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let lang = GameLanguage(rawValue: raw) {
            return lang
        }
        return systemDefault()
    }

    /// Persist a new explicit choice. SwiftUI views observing
    /// `@AppStorage(storageKey)` re-render automatically.
    static func set(_ language: GameLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }

    /// Treats any Spanish-language locale (es, es-MX, es-AR, etc.) as
    /// Spanish; everything else as English. Used as the fallback when
    /// the user hasn't explicitly picked a language yet.
    static func systemDefault() -> GameLanguage {
        if let code = Locale.current.language.languageCode?.identifier,
           code.lowercased() == "es" {
            return .spanish
        }
        return .english
    }
}

extension GameLanguage {
    /// Convenience SwiftUI-friendly view helper. Read from any view via
    /// `@AppStorage(AppLanguage.storageKey) private var langRaw: String = ""`
    /// + `GameLanguage.resolve(from: langRaw)` to get the active one.
    static func resolve(from rawValue: String) -> GameLanguage {
        GameLanguage(rawValue: rawValue) ?? AppLanguage.current
    }
}
