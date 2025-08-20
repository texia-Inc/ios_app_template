import XCTest

class SnapshotTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        setupSnapshot(app)
        app.launch()
    }

    func testShots() {
        snapshot("01-home")
        
        // Wait for UI to load
        sleep(2)
        
        // Look for common UI elements to navigate
        if app.buttons["Play"].exists {
            app.buttons["Play"].tap()
            snapshot("02-battle")
        }
        
        if app.buttons["Result"].exists {
            app.buttons["Result"].tap()
            snapshot("03-result")
        }
        
        // Additional screenshots for common screens
        if app.buttons["Settings"].exists {
            app.buttons["Settings"].tap()
            snapshot("04-settings")
        }
        
        if app.buttons["Profile"].exists {
            app.buttons["Profile"].tap()
            snapshot("05-profile")
        }
    }
}