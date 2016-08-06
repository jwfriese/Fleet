import XCTest

public protocol Expectation {
    var description: String { get }
    func validate(app: XCUIApplication) -> ExpectationResult
}
