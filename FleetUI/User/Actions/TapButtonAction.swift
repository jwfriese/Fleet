import XCTest

class TapButtonAction: Action {
    private var text: String!

    init(text: String) {
        self.text = text
    }

    func perform(app: XCUIApplication) throws -> ActionResult {
        let buttonExists = wait(3) { return app.buttons[self.text].exists }
        guard buttonExists else {
            return Failure("User could not find button with text \"\(text)\": It does not seem to exist")
        }

        let isButtonHittable = wait(3) { return app.buttons[self.text].hittable }
        guard isButtonHittable else {
            return Failure("User could not tap button with text \"\(text)\": It was never hittable")
        }

        app.buttons[text].tap()
        return Success()
    }
}
