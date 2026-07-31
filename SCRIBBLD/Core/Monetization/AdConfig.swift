import Foundation

/// AdMob unit IDs. Live IDs for Release; Google's official test IDs for
/// Debug builds so we never click our own ads during development (which
/// would violate AdMob policy and risk account suspension).
enum AdConfig {
    static let appID = "ca-app-pub-9946296672999343~8615261305"

    enum Banner {
        static var home: String      { isProd ? "ca-app-pub-9946296672999343/1297905841" : test }
        static var postGame: String  { isProd ? "ca-app-pub-9946296672999343/4553104664" : test }
        static var sketch: String    { isProd ? "ca-app-pub-9946296672999343/5957308373" : test }
        /// Google's official banner test unit. https://developers.google.com/admob/ios/test-ads
        private static let test = "ca-app-pub-3940256099942544/2934735716"
    }

    enum Rewarded {
        static var sketchUnlock: String { isProd ? "ca-app-pub-9946296672999343/6734065356" : test }
        private static let test = "ca-app-pub-3940256099942544/1712485313"
    }

    /// Flip via build configuration — Release builds talk to real AdMob,
    /// every other build uses Google test units.
    private static var isProd: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
