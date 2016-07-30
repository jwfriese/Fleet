import XCTest

protocol UserAction {
    func perform(app: XCUIApplication) throws -> FLTUserActionResult
}
