import XCTest

public class User {
    private var app: XCUIApplication!
    private var testCase: XCTestCase!
    private var reporter: Reporter!

    init(xcApp: XCUIApplication, testCase xcTestCase: XCTestCase, reporter aReporter: Reporter) {
        app = xcApp
        testCase = xcTestCase
        reporter = aReporter
    }

    public func tapButtonWithText(text: String) {
        doAction(TapButtonAction(text: text))
    }

    public func expectsTo(expectation: Expectation) {
        let expectationResult = expectation.validate(app)
        switch expectationResult {
        case .Satisfied:
            return
        case .Rejected:
            let failureMessage = "User expected to \(expectation.description), but \(expectationResult.description)"
            reporter.reportError(failureMessage, testCase: testCase)
        }
    }

    private func doAction(action: Action) {
        var actionResult: ActionResult?

        do {
            try actionResult = action.perform(app)
        } catch {
            actionResult = Error("\(error)")
        }

        guard let finalResult = actionResult else {
            reporter.reportError("Fleet fatal error: No user action result", testCase: testCase)
            return
        }

        if !finalResult.succeeded {
            reporter.reportError(finalResult.resultDescription, testCase: testCase)
        }
    }
}
