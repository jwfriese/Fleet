import XCTest

class FindTextAction: UserAction {
    var text: String!

    init(_ text: String) {
        self.text = text
    }

    func perform(app: XCUIApplication) throws -> UserActionResult {
        let textExists = app.staticTexts[text].exists
        if textExists {
            return Success()
        } else {
            return Failure("User could not find text \"\(text)\": It does not seem to exist")
        }
    }
}
