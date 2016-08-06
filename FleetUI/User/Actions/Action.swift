import XCTest

protocol Action {
    func perform(app: XCUIApplication) throws -> ActionResult
}
