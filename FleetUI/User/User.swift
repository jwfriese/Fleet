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

    public func canSeeText(text: String) -> Bool {
        return app.staticTexts[text].exists
    }
    
    private func doAction(action: UserAction) {
        var actionResult: FLTUserActionResult = .Success
        
        do {
            try actionResult = action.perform(app)
        } catch {
            actionResult = .Error(error)
        }
        
        switch actionResult {
        case .Success:
            return
        case .Failure:
            reporter.reportError(actionResult.resultDescription(), testCase: testCase)
        case .Error:
            reporter.reportError(actionResult.resultDescription(), testCase: testCase)
        }
    }
}