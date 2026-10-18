import XCTest

/// Drives the instrumented host with UIKit's real input path (`XCUIElement.tap()` on iOS, `XCUIRemote` on tvOS)
/// and compares the delegate callbacks UIKit sends with the sequences Fleet's `selectItem(at:)` models.
/// The same scenario names and sequences are asserted for Fleet in `UICollectionView_UIKitTraceModelSpec`.
@MainActor
final class UIKitCollectionTraceTests: XCTestCase {
    private var app: XCUIApplication!
#if os(tvOS)
    private var focusedItem = 0
#endif

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.staticTexts["trace"].waitForExistence(timeout: 10))
    }

    private func activate(_ item: Int) {
#if os(tvOS)
        while focusedItem < item { XCUIRemote.shared.press(.right); focusedItem += 1 }
        while focusedItem > item { XCUIRemote.shared.press(.left); focusedItem -= 1 }
        XCUIRemote.shared.press(.select)
#else
        let cell = app.cells["item-\(item)"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        cell.tap()
#endif
    }

    /// The label text after `count` events have been recorded (bounded wait).
    private func trace(count: Int, file: StaticString = #filePath, line: UInt = #line) -> String {
        let label = app.staticTexts["trace"]
        let predicate = NSPredicate(format: "value == %@", "\(count)")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: label)
        _ = XCTWaiter().wait(for: [expectation], timeout: 10)
        return label.label
    }

    func test_tapUnselectedItem() {
        launch()
        activate(1)
        XCTAssertEqual(trace(count: 2), "shouldSelect 0.1, didSelect 0.1")
    }

    func test_tapReplacesSelectionInSingleSelectionMode() {
        launch()
        activate(0)
        activate(1)
        XCTAssertEqual(trace(count: 5), "shouldSelect 0.0, didSelect 0.0, shouldSelect 0.1, didDeselect 0.0, didSelect 0.1")
    }

    func test_tapSelectedItemAgain() {
        launch()
        activate(0)
        activate(0)
        XCTAssertEqual(trace(count: 4), "shouldSelect 0.0, didSelect 0.0, shouldSelect 0.0, didSelect 0.0")
    }

    func test_delegateRefusesSelection() {
        launch(["-refuseSelect", "2"])
        activate(2)
        XCTAssertEqual(trace(count: 1), "shouldSelect 0.2")
    }

    /// UIKit does not consult `shouldDeselectItemAt` when a tap replaces the selection, so the replacement proceeds.
    func test_shouldDeselectIsNotConsultedWhenTapReplacesSelection() {
        launch(["-refuseDeselect", "0"])
        activate(0)
        activate(1)
        XCTAssertEqual(trace(count: 5), "shouldSelect 0.0, didSelect 0.0, shouldSelect 0.1, didDeselect 0.0, didSelect 0.1")
    }
}
