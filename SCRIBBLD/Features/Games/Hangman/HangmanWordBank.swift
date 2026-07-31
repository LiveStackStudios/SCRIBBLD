import Foundation

/// Hangman category + word bank. `rawValue` is the English uppercase
/// label and is stable for Firestore compatibility — it's used as the
/// `state.category` key in live games. Display + word pools are
/// keyed by `GameLanguage` so the same category surface works in
/// either locale without changing the persisted doc shape.
enum HangmanCategory: String, CaseIterable {
    case animals = "ANIMALS"
    case fruits  = "FRUITS"
    case cities  = "CITIES"
    case sports  = "SPORTS"

    /// User-facing category label in the requested language. Bilingual
    /// mode shows both ("Animals / Animales") for shared screens.
    func displayName(in language: GameLanguage) -> String {
        switch (self, language) {
        case (.animals, .english):   return "Animals"
        case (.animals, .spanish):   return "Animales"
        case (.animals, .bilingual): return "Animals / Animales"
        case (.fruits, .english):    return "Fruits"
        case (.fruits, .spanish):    return "Frutas"
        case (.fruits, .bilingual):  return "Fruits / Frutas"
        case (.cities, .english):    return "Cities"
        case (.cities, .spanish):    return "Ciudades"
        case (.cities, .bilingual):  return "Cities / Ciudades"
        case (.sports, .english):    return "Sports"
        case (.sports, .spanish):    return "Deportes"
        case (.sports, .bilingual):  return "Sports / Deportes"
        }
    }

    /// Word pool for the given language. Spanish words include ñ-free
    /// variants only — the rendered word display is keyboard-tappable
    /// (A–Z) and the keyboard doesn't carry Ñ as a separate key.
    func words(in language: GameLanguage) -> [String] {
        switch (self, language) {
        case (.animals, .english):
            return ["DOLPHIN", "ELEPHANT", "PENGUIN", "GIRAFFE", "TIGER",
                    "FALCON", "OCTOPUS", "PANDA", "JAGUAR", "ZEBRA"]
        case (.animals, .spanish):
            return ["DELFIN", "ELEFANTE", "PINGUINO", "JIRAFA", "TIGRE",
                    "HALCON", "PULPO", "PANDA", "JAGUAR", "CEBRA"]
        case (.fruits, .english):
            return ["MANGO", "PAPAYA", "BANANA", "PEACH", "GUAVA",
                    "LYCHEE", "ORANGE", "APPLE", "CHERRY", "MELON"]
        case (.fruits, .spanish):
            return ["MANGO", "PAPAYA", "BANANA", "DURAZNO", "GUAYABA",
                    "PINA", "NARANJA", "MANZANA", "CEREZA", "MELON"]
        case (.cities, .english):
            return ["TOKYO", "LISBON", "BERLIN", "MUMBAI", "DENVER",
                    "OSAKA", "PARIS", "MIAMI", "BOSTON", "SEATTLE"]
        case (.cities, .spanish):
            return ["TOKIO", "LISBOA", "BERLIN", "BOMBAY", "BUENOS AIRES",
                    "MADRID", "PARIS", "QUITO", "BOGOTA", "LIMA"]
        case (.sports, .english):
            return ["TENNIS", "HOCKEY", "RUGBY", "CRICKET", "BASEBALL",
                    "ARCHERY", "ROWING", "BOXING", "GOLF", "SOCCER"]
        case (.sports, .spanish):
            return ["TENIS", "HOCKEY", "RUGBY", "CRICKET", "BEISBOL",
                    "ARQUERIA", "REMO", "BOXEO", "GOLF", "FUTBOL"]
        case (_, .bilingual):
            // Bilingual mode samples from both pools so a single round
            // can land on either language. The picker should ideally
            // be aware that "MANZANA" is Spanish vs "APPLE" is English
            // but for V1 we just merge both lists.
            return words(in: .english) + words(in: .spanish)
        }
    }

    /// Pick a random category + word in the requested language.
    static func random(in language: GameLanguage = .english) -> (HangmanCategory, String) {
        let cat = HangmanCategory.allCases.randomElement()!
        let word = cat.words(in: language).randomElement() ?? "WORD"
        return (cat, word)
    }
}
