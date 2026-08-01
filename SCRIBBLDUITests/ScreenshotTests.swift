import XCTest

/// Drives the app to capture App Store screenshots.
///
/// Not a correctness test — it exists so screenshots can be regenerated in one
/// command whenever the UI changes, instead of being hand-captured and going
/// stale. Every step is best-effort: a screen that can't be reached is skipped
/// with a log line rather than failing the run, so one changed label doesn't
/// cost the whole set.
///
///   xcodebuild test -scheme SCRIBBLD -only-testing:SCRIBBLDUITests \
///     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
///
/// Then pull the PNGs out of the .xcresult with `tools/extract-screenshots.sh`.
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        // Hides the AdMob test banner, which must never appear in store artwork.
        app.launchArguments += ["-SCRIBBLD_SCREENSHOTS"]
        app.launch()
        // Splash animation.
        sleep(4)
    }

    // MARK: - Helpers

    private func shot(_ name: String) {
        let s = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        s.name = name
        s.lifetime = .keepAlways
        add(s)
    }

    /// Tap the first element carrying `label`, whatever kind it is. SwiftUI
    /// surfaces cards as buttons on some builds and static text on others, so
    /// querying a single type is brittle.
    @discardableResult
    private func tap(_ label: String, timeout: TimeInterval = 6) -> Bool {
        for query in [app.buttons, app.staticTexts, app.otherElements, app.images] {
            let el = query[label]
            if el.waitForExistence(timeout: timeout / 4), el.isHittable {
                el.tap()
                return true
            }
        }
        // Fall back to a substring match across buttons.
        let pred = NSPredicate(format: "label CONTAINS[c] %@", label)
        let el = app.buttons.containing(pred).firstMatch
        if el.waitForExistence(timeout: timeout / 4), el.isHittable {
            el.tap()
            return true
        }
        NSLog("[screenshots] could not find '\(label)'")
        return false
    }

    /// Relaunch rather than navigate back. In-game screens hide the tab bar,
    /// so tapping "Home" silently fails and every later step falls over — which
    /// is exactly what cost three screenshots on the first run.
    private func goHome() {
        app.terminate()
        app.launch()
        sleep(4)
    }

    // MARK: - The run

    func testCaptureAppStoreScreenshots() throws {
        // 1 — Home, the whole library at a glance.
        shot("01-home")

        // 2 — Tic Tac Toe mid-game.
        if tap("Tic Tac Toe") {
            sleep(2)
            _ = tap("Start Game")
            sleep(3)
            // Play a few cells so the board isn't empty. Coordinates are
            // normalised, so this survives layout changes.
            let board: [(CGFloat, CGFloat)] = [(0.30, 0.44), (0.50, 0.52), (0.70, 0.44)]
            for (x, y) in board {
                app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
                sleep(2)
            }
            shot("02-tictactoe")
            goHome()
        }

        // 3 — Sand Snake. The how-to card auto-presents on first run, which is
        // a good screenshot in itself: it explains the buried-snake concept.
        if tap("Sand Snake") {
            sleep(3)
            shot("03-sandsnake-howto")
            _ = tap("Start burrowing")
            sleep(1)
            // Tap the board to start the run, then capture while it's still
            // travelling. Steering it sideways ran it straight into the wall
            // and the first attempt captured a game-over screen.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            usleep(1_100_000)
            shot("04-sandsnake")
            goHome()
        }

        // 4 — Sketching with something actually drawn on the canvas.
        if tap("Sketching") {
            sleep(3)
            let c = app.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.55))
            c.press(forDuration: 0.1,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.66)))
            sleep(1)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.32, dy: 0.66))
                .press(forDuration: 0.1,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.55)))
            sleep(1)
            shot("05-sketching")
            goHome()
        }

        // 5 — Hangman.
        if tap("Hangman") {
            sleep(2)
            _ = tap("Start Game")
            sleep(3)
            shot("06-hangman")
            goHome()
        }

        // 6 — Dots & Boxes.
        if tap("Dots and Boxes") {
            sleep(2)
            _ = tap("Start Game")
            sleep(3)
            shot("07-dotsandboxes")
        }
    }
}
