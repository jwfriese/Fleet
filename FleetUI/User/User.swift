import XCTest

public class User {
    private var app: XCUIApplication!
    
    public init(xcApp: XCUIApplication) {
        app = xcApp
    }
    
    public func tapButtonWithText(text: String) {
        app.buttons[text].tap()
    }

    public func canSeeText(text: String) -> Bool {
        return app.staticTexts[text].exists
    }
}