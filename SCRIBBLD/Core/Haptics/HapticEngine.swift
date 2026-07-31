import UIKit

enum HapticEngine {
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "scribbld.haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "scribbld.haptics") }
    }

    static func light()   { fire(.light) }
    static func medium()  { fire(.medium) }
    static func heavy()   { fire(.heavy) }
    static func soft()    { fire(.soft) }
    static func rigid()   { fire(.rigid) }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()   { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }

    private static func fire(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
