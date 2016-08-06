import XCTest

class CanSeeTextExpectation: Expectation {
    var text: String!

    init(_ text: String) {
        self.text = text
    }

    var description: String {
        get {
            return "find text \"\(text)\""
        }
    }

    func validate(app: XCUIApplication) -> ExpectationResult {
        let textExists = app.staticTexts[text].exists
        if textExists {
            return .Satisfied
        } else {
            return .Rejected("it does not seem to exist")
        }
    }
}
