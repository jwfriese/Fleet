import XCTest

class TapButtonAction: UserAction {
    private var text: String!

    init(text: String) {
        self.text = text
    }

    func perform(app: XCUIApplication) throws -> FLTUserActionResult {
        let buttonExists = app.buttons[text].exists
        if buttonExists {
            app.buttons[text].tap()
            return .Success
        } else {
            return .Failure("User could not find button with text \"\(text)\": It does not seem to exist")
        }
    }
}
