import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        setupSnapshot(app)
    }

    func testScreenshots() {
        // 1. Hero compass shot — needle + curved place name + carousel
        app.launchArguments += ["--demo-mode"]
        app.launch()
        sleep(2)
        snapshot("1_compass")

        // 2. Expanded card — tap first card to show address, phone, directions
        // Cards use .accessibilityLabel(place.name) and .accessibilityAddTraits(.isButton)
        let firstCard = app.buttons["Joe's Pizza"].firstMatch
        if firstCard.waitForExistence(timeout: 5) {
            firstCard.tap()
            sleep(1)
        }
        snapshot("2_card_expanded")

        // 3. Mystery mode — compass with "PIZZA" text, hidden card names
        app.terminate()
        app.launchArguments = ["--demo-mode", "--mystery-mode"]
        app.launch()
        sleep(2)
        snapshot("3_mystery")

        // 4. Settings with tip jar — relaunch in normal mode
        app.terminate()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        sleep(2)
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
        }
        snapshot("4_settings")
    }
}
