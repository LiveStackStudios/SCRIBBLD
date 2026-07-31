import SwiftUI

/// Canonical category keys for the Stop! / Tutti Frutti game.
/// Spanish names are the primary identifiers because this is a Latin American
/// game; English names are surfaced via `displayName(in:)`.
enum StopCategoryKey: String, CaseIterable, Identifiable, Codable, Hashable {
    // Classic 8
    case nombre, apellido, animal, paisCiudad, frutaVerdura, color, cosaObjeto, profesion
    // Extended free
    case comida, bebida, deporte, marca
    // Premium
    case famoso, pelicula, cancion, verbo, adjetivo, partesDelCuerpo
    case instrumento, ropa, flor, mueble, medioDeTransporte
    case rio, capital, planeta, caricatura, mitologia

    var id: String { rawValue }

    var tier: StopCategoryTier {
        switch self {
        case .nombre, .apellido, .animal, .paisCiudad, .frutaVerdura, .color,
             .cosaObjeto, .profesion, .comida, .bebida, .deporte, .marca:
            return .free
        default:
            return .premium
        }
    }

    func displayName(in language: GameLanguage) -> String {
        switch language {
        case .spanish:   return spanishName
        case .english:   return englishName
        case .bilingual: return "\(spanishName) / \(englishName)"
        }
    }

    var spanishName: String {
        switch self {
        case .nombre:           return "Nombre"
        case .apellido:         return "Apellido"
        case .animal:           return "Animal"
        case .paisCiudad:       return "País / Ciudad"
        case .frutaVerdura:     return "Fruta / Verdura"
        case .color:            return "Color"
        case .cosaObjeto:       return "Cosa / Objeto"
        case .profesion:        return "Profesión"
        case .comida:           return "Comida"
        case .bebida:           return "Bebida"
        case .deporte:          return "Deporte"
        case .marca:            return "Marca"
        case .famoso:           return "Famoso/a"
        case .pelicula:         return "Película"
        case .cancion:          return "Canción"
        case .verbo:            return "Verbo"
        case .adjetivo:         return "Adjetivo"
        case .partesDelCuerpo:  return "Parte del cuerpo"
        case .instrumento:      return "Instrumento"
        case .ropa:             return "Ropa"
        case .flor:             return "Flor"
        case .mueble:           return "Mueble"
        case .medioDeTransporte:return "Transporte"
        case .rio:              return "Río"
        case .capital:          return "Capital"
        case .planeta:          return "Planeta"
        case .caricatura:       return "Caricatura"
        case .mitologia:        return "Mitología"
        }
    }

    var englishName: String {
        switch self {
        case .nombre:           return "Name"
        case .apellido:         return "Surname"
        case .animal:           return "Animal"
        case .paisCiudad:       return "Country / City"
        case .frutaVerdura:     return "Fruit / Vegetable"
        case .color:            return "Color"
        case .cosaObjeto:       return "Thing / Object"
        case .profesion:        return "Profession"
        case .comida:           return "Food"
        case .bebida:           return "Drink"
        case .deporte:          return "Sport"
        case .marca:            return "Brand"
        case .famoso:           return "Celebrity"
        case .pelicula:         return "Movie"
        case .cancion:          return "Song"
        case .verbo:            return "Verb"
        case .adjetivo:         return "Adjective"
        case .partesDelCuerpo:  return "Body Part"
        case .instrumento:      return "Instrument"
        case .ropa:             return "Clothing"
        case .flor:             return "Flower"
        case .mueble:           return "Furniture"
        case .medioDeTransporte:return "Vehicle"
        case .rio:              return "River"
        case .capital:          return "Capital"
        case .planeta:          return "Planet"
        case .caricatura:       return "Cartoon"
        case .mitologia:        return "Mythology"
        }
    }

    var iconSystemName: String {
        switch self {
        case .nombre, .apellido:        return "person.crop.circle"
        case .animal:                   return "pawprint"
        case .paisCiudad:               return "globe.americas"
        case .frutaVerdura:             return "leaf"
        case .color:                    return "paintpalette"
        case .cosaObjeto:               return "shippingbox"
        case .profesion:                return "briefcase"
        case .comida:                   return "fork.knife"
        case .bebida:                   return "cup.and.saucer"
        case .deporte:                  return "figure.run"
        case .marca:                    return "tag"
        case .famoso:                   return "star"
        case .pelicula:                 return "film"
        case .cancion:                  return "music.note"
        case .verbo:                    return "arrow.up.forward"
        case .adjetivo:                 return "text.alignleft"
        case .partesDelCuerpo:          return "hand.raised"
        case .instrumento:              return "guitars"
        case .ropa:                     return "tshirt"
        case .flor:                     return "camera.macro"
        case .mueble:                   return "sofa"
        case .medioDeTransporte:        return "car"
        case .rio:                      return "water.waves"
        case .capital:                  return "building.columns"
        case .planeta:                  return "globe"
        case .caricatura:               return "face.smiling"
        case .mitologia:                return "bolt.shield"
        }
    }
}

enum StopCategoryTier: String, Codable { case free, premium }

enum StopPreset: String, CaseIterable, Identifiable {
    case classic, express, hard, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: return "Clásico"
        case .express: return "Express"
        case .hard:    return "Difícil"
        case .custom:  return "Mi mazo"
        }
    }

    var keys: [StopCategoryKey] {
        switch self {
        case .classic:
            return [.nombre, .apellido, .animal, .paisCiudad, .frutaVerdura, .color, .cosaObjeto, .profesion]
        case .express:
            return [.nombre, .animal, .paisCiudad, .frutaVerdura, .color, .cosaObjeto]
        case .hard:
            return [.nombre, .apellido, .paisCiudad, .verbo, .adjetivo, .rio, .capital, .mitologia, .planeta, .caricatura]
        case .custom:
            return [] // resolved at runtime from UserDefaults
        }
    }
}

// MARK: - Letter pool per language

enum StopLetterPool {
    static func letters(for language: GameLanguage, includeRare: Bool = false) -> [Character] {
        switch language {
        case .spanish:
            let base = "ABCDEFGHIJLMNOPQRSTUVYZ"
            return Array(includeRare ? "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ" : base)
        case .english:
            let base = "ABCDEFGHIJKLMNOPRSTUVWY"
            return Array(includeRare ? "ABCDEFGHIJKLMNOPQRSTUVWXYZ" : base)
        case .bilingual:
            return Array("ABCDEFGHIJLMNOPRSTUVY")
        }
    }
}

// MARK: - AI word bank

/// Small curated word bank so AI opponents have something to submit per letter.
/// Not exhaustive — meant to feel populated for the player without claiming to
/// be a real dictionary validator.
enum StopAIWordBank {
    typealias Bank = [StopCategoryKey: [Character: [String]]]

    static let spanish: Bank = [
        .nombre: [
            "A": ["Ana", "Andrés", "Alicia"], "B": ["Bruno", "Beatriz"],
            "C": ["Carlos", "Camila"], "D": ["Daniel", "Diana"],
            "E": ["Elena", "Esteban"], "F": ["Fabián", "Felicia"],
            "G": ["Gabriela", "Gustavo"], "H": ["Hugo", "Helena"],
            "I": ["Iván", "Isabel"], "J": ["Javier", "Julia"],
            "L": ["Lucía", "Luis"], "M": ["María", "Miguel"],
            "N": ["Natalia", "Nicolás"], "O": ["Óscar", "Olivia"],
            "P": ["Paula", "Pedro"], "R": ["Rosa", "Ricardo"],
            "S": ["Sofía", "Santiago"], "T": ["Teresa", "Tomás"],
            "V": ["Verónica", "Víctor"]
        ],
        .apellido: [
            "A": ["Álvarez", "Acosta"], "B": ["Bermúdez"], "C": ["Castro"],
            "D": ["Díaz"], "E": ["Espinoza"], "F": ["Fernández"], "G": ["García"],
            "H": ["Herrera"], "I": ["Iglesias"], "J": ["Jiménez"], "L": ["López"],
            "M": ["Martínez"], "N": ["Núñez"], "O": ["Ortega"], "P": ["Pérez"],
            "R": ["Ramírez"], "S": ["Sánchez"], "T": ["Torres"], "V": ["Vargas"]
        ],
        .animal: [
            "A": ["Ardilla"], "B": ["Búho"], "C": ["Caballo"], "D": ["Delfín"],
            "E": ["Elefante"], "F": ["Foca"], "G": ["Gato"], "H": ["Hipopótamo"],
            "I": ["Iguana"], "J": ["Jaguar"], "L": ["León"], "M": ["Mono"],
            "N": ["Nutria"], "O": ["Oso"], "P": ["Perro"], "R": ["Rana"],
            "S": ["Serpiente"], "T": ["Tigre"], "V": ["Venado"]
        ],
        .paisCiudad: [
            "A": ["Argentina"], "B": ["Brasil"], "C": ["Chile"], "D": ["Dinamarca"],
            "E": ["España"], "F": ["Francia"], "G": ["Guatemala"], "H": ["Honduras"],
            "I": ["Italia"], "J": ["Japón"], "L": ["Lima"], "M": ["México"],
            "N": ["Nicaragua"], "O": ["Oslo"], "P": ["Perú"], "R": ["Roma"],
            "S": ["Salvador"], "T": ["Turquía"], "V": ["Venezuela"]
        ],
        .frutaVerdura: [
            "A": ["Aguacate"], "B": ["Banana"], "C": ["Cebolla"], "D": ["Durazno"],
            "E": ["Espinaca"], "F": ["Frambuesa"], "G": ["Granada"], "H": ["Higo"],
            "L": ["Limón"], "M": ["Mango"], "N": ["Naranja"], "P": ["Pera"],
            "R": ["Remolacha"], "S": ["Sandía"], "T": ["Tomate"], "U": ["Uva"],
            "Z": ["Zanahoria"]
        ],
        .color: [
            "A": ["Azul"], "B": ["Blanco"], "C": ["Celeste"], "D": ["Dorado"],
            "F": ["Fucsia"], "G": ["Gris"], "L": ["Lila"], "M": ["Morado"],
            "N": ["Negro"], "P": ["Plateado"], "R": ["Rojo"], "T": ["Turquesa"],
            "V": ["Verde"]
        ],
        .cosaObjeto: [
            "A": ["Anillo"], "B": ["Botella"], "C": ["Cuaderno"], "D": ["Disco"],
            "E": ["Espejo"], "F": ["Foco"], "G": ["Guante"], "H": ["Hilo"],
            "L": ["Lápiz"], "M": ["Mesa"], "N": ["Nevera"], "P": ["Papel"],
            "R": ["Reloj"], "S": ["Silla"], "T": ["Tijera"], "V": ["Vaso"]
        ],
        .profesion: [
            "A": ["Abogado"], "B": ["Bombero"], "C": ["Cocinero"], "D": ["Doctor"],
            "E": ["Electricista"], "F": ["Futbolista"], "G": ["Guía"], "I": ["Ingeniero"],
            "J": ["Jardinero"], "M": ["Maestro"], "P": ["Periodista"], "S": ["Sastre"],
            "V": ["Veterinario"]
        ]
    ]

    static let english: Bank = [
        .nombre: [
            "A": ["Adam"], "B": ["Beth"], "C": ["Carlos"], "D": ["Diana"],
            "E": ["Emma"], "F": ["Frank"], "G": ["Grace"], "H": ["Henry"],
            "I": ["Ivy"], "J": ["Jack"], "K": ["Kate"], "L": ["Liam"],
            "M": ["Mia"], "N": ["Noah"], "O": ["Olivia"], "P": ["Paul"],
            "R": ["Rachel"], "S": ["Sam"], "T": ["Theo"], "V": ["Violet"]
        ],
        .animal: [
            "A": ["Antelope"], "B": ["Bear"], "C": ["Cat"], "D": ["Deer"],
            "E": ["Elephant"], "F": ["Fox"], "G": ["Giraffe"], "H": ["Horse"],
            "K": ["Kangaroo"], "L": ["Lion"], "M": ["Monkey"], "O": ["Owl"],
            "P": ["Penguin"], "R": ["Rabbit"], "S": ["Snake"], "T": ["Tiger"],
            "W": ["Wolf"]
        ],
        .paisCiudad: [
            "A": ["Australia"], "B": ["Brazil"], "C": ["Canada"], "D": ["Denmark"],
            "E": ["Ecuador"], "F": ["France"], "G": ["Greece"], "H": ["Hungary"],
            "I": ["Italy"], "J": ["Japan"], "K": ["Kenya"], "L": ["Lima"],
            "M": ["Mexico"], "N": ["Norway"], "P": ["Peru"], "S": ["Spain"],
            "T": ["Turkey"], "U": ["Uruguay"]
        ],
        .frutaVerdura: [
            "A": ["Apple"], "B": ["Banana"], "C": ["Carrot"], "D": ["Date"],
            "E": ["Eggplant"], "F": ["Fig"], "G": ["Grape"], "K": ["Kiwi"],
            "L": ["Lemon"], "M": ["Mango"], "O": ["Orange"], "P": ["Pear"],
            "R": ["Raspberry"], "S": ["Strawberry"], "T": ["Tomato"]
        ],
        .color: [
            "A": ["Amber"], "B": ["Blue"], "C": ["Crimson"], "G": ["Green"],
            "I": ["Indigo"], "L": ["Lavender"], "M": ["Magenta"], "O": ["Olive"],
            "P": ["Pink"], "R": ["Red"], "T": ["Teal"], "V": ["Violet"], "Y": ["Yellow"]
        ],
        .cosaObjeto: [
            "B": ["Book"], "C": ["Clock"], "D": ["Door"], "E": ["Envelope"],
            "F": ["Fork"], "K": ["Key"], "L": ["Lamp"], "M": ["Mirror"],
            "P": ["Pencil"], "S": ["Spoon"], "T": ["Table"], "W": ["Window"]
        ],
        .profesion: [
            "A": ["Artist"], "B": ["Baker"], "C": ["Chef"], "D": ["Doctor"],
            "E": ["Engineer"], "F": ["Farmer"], "L": ["Lawyer"], "N": ["Nurse"],
            "P": ["Pilot"], "T": ["Teacher"], "W": ["Writer"]
        ]
    ]

    static func answer(for category: StopCategoryKey, letter: Character, language: GameLanguage) -> String? {
        let bank: Bank = (language == .english) ? english : spanish
        let key = Character(letter.uppercased())
        return bank[category]?[key]?.randomElement()
    }
}
