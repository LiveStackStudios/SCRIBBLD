import SwiftUI

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static let cream      = Color(hex: "#FEFCF3")
    static let inkBlue    = Color(hex: "#1A365D")
    static let redPen     = Color(hex: "#C53030")
    static let gridGray   = Color(hex: "#D4B896")
    static let softGray   = Color(hex: "#8C8C7A")
    static let lightLine  = Color(hex: "#EDE8D8")
    static let goldAccent = Color(hex: "#B7881A")
    static let inkGreen   = Color(hex: "#2E7D5A")
}

extension Font {
    /// Caveat-Regular ships as a variable font in `Resources/Fonts/Caveat-Regular.ttf`.
    /// The PostScript family name is `Caveat`; weight is applied via `.weight(_:)`,
    /// which iOS routes through the font's variation axes on iOS 16+.
    static func caveat(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Caveat", size: size).weight(weight)
    }

    static func dmSans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("DMSans", size: size).weight(weight)
    }

    static func scribbldTitle(size: CGFloat) -> Font { caveat(size, weight: .bold) }
    static func scribbldHeading(size: CGFloat) -> Font { caveat(size, weight: .bold) }
    static func scribbldBody(size: CGFloat) -> Font { dmSans(size, weight: .regular) }
    static func scribbldLabel(size: CGFloat) -> Font { dmSans(size, weight: .medium) }
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let card: CGFloat = 16
    static let chip: CGFloat = 12
    static let button: CGFloat = 14
}
