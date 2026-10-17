import XCTest
import Testing
import UIKit
import Fleet
import Nimble

@MainActor
private final class Counter: NSObject {
    var count = 0
    @objc func fire() { count += 1 }
}

@MainActor
private func presentAlert(_ alert: UIAlertController) {
    let root = UIViewController()
    Fleet.setAsAppWindowRoot(root)
    root.present(alert, animated: false, completion: nil)
}

@MainActor
private func failure(of body: () throws -> Void) -> FleetFailure? {
    do { try body() } catch { return error as? FleetFailure }
    return nil
}

@MainActor
class ActionRecoverableFailureSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    // MARK: Alerts

    func test_tapAlertActionOrThrow_withDuplicateTitles_throwsInvalidInputAndRunsNothing() {
        var calls = 0
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in calls += 1 })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in calls += 1 })
        presentAlert(alert)

        XCTAssertThrowsError(try alert.tapAlertActionOrThrow(withTitle: "OK")) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        XCTAssertEqual(calls, 0)
        XCTAssertNotNil(alert.presentingViewController)
    }

    func test_tapAlertActionOrThrow_withMissingTitle_throwsInvalidInput() {
        let alert = UIAlertController(title: "title", message: nil, preferredStyle: .alert)
        presentAlert(alert)
        XCTAssertEqual(failure { try alert.tapAlertActionOrThrow(withTitle: "nope") }?.kind, .invalidInput)
    }

    func test_tapAlertActionOrThrow_withDisabledAction_throwsUnavailableInteraction() {
        var calls = 0
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default) { _ in calls += 1 }
        action.isEnabled = false
        alert.addAction(action)
        presentAlert(alert)

        XCTAssertEqual(failure { try alert.tapAlertActionOrThrow(withTitle: "OK") }?.kind, .unavailableInteraction)
        XCTAssertEqual(calls, 0)
    }

    func test_tapAlertActionOrThrow_whenNotPresented_throwsUnavailableInteraction() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        XCTAssertEqual(failure { try alert.tapAlertActionOrThrow(withTitle: "OK") }?.kind, .unavailableInteraction)
    }

    func test_tapAlertActionOrThrow_onSuccess_dismissesAndRunsHandlerOnce() {
        var calls = 0
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in calls += 1 })
        presentAlert(alert)
        XCTAssertNoThrow(try alert.tapAlertActionOrThrow(withTitle: "OK"))
        expect(calls).toEventually(equal(1))
    }

    // MARK: Buttons

    func test_tapOrThrow_onDisabledButton_throwsUnavailableInteraction() {
        let counter = Counter()
        let button = UIButton(type: .system)
        button.addTarget(counter, action: #selector(Counter.fire), for: .touchUpInside)
        button.isEnabled = false
        XCTAssertEqual(failure { try button.tapOrThrow() }?.kind, .unavailableInteraction)
        XCTAssertEqual(counter.count, 0)
    }

    func test_tapOrThrow_onEnabledButton_firesTargetOnce() throws {
        let counter = Counter()
        let button = UIButton(type: .system)
        button.addTarget(counter, action: #selector(Counter.fire), for: .touchUpInside)
        try button.tapOrThrow()
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: Bar button items

    func test_barButtonTapOrThrow_disabled_throwsUnavailableInteraction() {
        let counter = Counter()
        let item = UIBarButtonItem(title: "x", style: .plain, target: counter, action: #selector(Counter.fire))
        item.isEnabled = false
        XCTAssertEqual(failure { try item.tapOrThrow() }?.kind, .unavailableInteraction)
        XCTAssertEqual(counter.count, 0)
    }

    func test_barButtonTapOrThrow_withoutAction_throwsInvalidSetup() {
        let item = UIBarButtonItem(title: "x", style: .plain, target: nil, action: nil)
        XCTAssertEqual(failure { try item.tapOrThrow() }?.kind, .invalidSetup)
    }

    func test_barButtonTapOrThrow_targetNotRespondingToAction_throwsInvalidSetup() {
        let item = UIBarButtonItem(title: "x", style: .plain, target: NSObject(), action: #selector(Counter.fire))
        XCTAssertEqual(failure { try item.tapOrThrow() }?.kind, .invalidSetup)
    }

    func test_barButtonTapOrThrow_onSuccess_firesTargetOnce() throws {
        let counter = Counter()
        let item = UIBarButtonItem(title: "x", style: .plain, target: counter, action: #selector(Counter.fire))
        try item.tapOrThrow()
        XCTAssertEqual(counter.count, 1)
    }

    #if os(iOS)
    func test_barButtonTap_withPrimaryActionAndMenu_runsPrimaryActionOnce() throws {
        var calls = 0
        var menuCalls = 0
        let item = UIBarButtonItem(
            primaryAction: UIAction(title: "primary") { _ in calls += 1 },
            menu: UIMenu(children: [UIAction(title: "m") { _ in menuCalls += 1 }])
        )
        try item.tapOrThrow()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(menuCalls, 0)
    }

    func test_barButtonTapOrThrow_menuOnly_throwsUnavailableInteraction() {
        let item = UIBarButtonItem(title: "menu", menu: UIMenu(children: [UIAction(title: "x") { _ in }]))
        XCTAssertEqual(failure { try item.tapOrThrow() }?.kind, .unavailableInteraction)
    }

    // MARK: Toolbar and navigation bar title lookup

    func test_toolbarTapItemOrThrow_withDuplicateTitles_throwsInvalidInputAndTapsNothing() {
        let first = Counter(), second = Counter()
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(title: "Go", style: .plain, target: first, action: #selector(Counter.fire)),
            UIBarButtonItem(title: "Go", style: .plain, target: second, action: #selector(Counter.fire)),
        ]
        XCTAssertEqual(failure { try toolbar.tapItemOrThrow(withTitle: "Go") }?.kind, .invalidInput)
        XCTAssertEqual(first.count + second.count, 0)
    }

    func test_toolbarTapItemOrThrow_withUniqueTitle_tapsOnlyThatItem() throws {
        let first = Counter(), second = Counter()
        let toolbar = UIToolbar()
        toolbar.items = [
            UIBarButtonItem(title: "A", style: .plain, target: first, action: #selector(Counter.fire)),
            UIBarButtonItem(title: "B", style: .plain, target: second, action: #selector(Counter.fire)),
        ]
        try toolbar.tapItemOrThrow(withTitle: "B")
        XCTAssertEqual(first.count, 0)
        XCTAssertEqual(second.count, 1)
    }

    func test_toolbarTapItemOrThrow_withoutItems_throwsInvalidSetup() {
        XCTAssertEqual(failure { try UIToolbar().tapItemOrThrow(withTitle: "Go") }?.kind, .invalidSetup)
    }

    #endif

    #if os(iOS)
    func test_navBarTapTopItemOrThrow_titleOnBothSides_throwsInvalidInputAndTapsNothing() {
        let left = Counter(), right = Counter()
        let bar = UINavigationBar()
        let item = UINavigationItem(title: "t")
        item.leftBarButtonItem = UIBarButtonItem(title: "Go", style: .plain, target: left, action: #selector(Counter.fire))
        item.rightBarButtonItem = UIBarButtonItem(title: "Go", style: .plain, target: right, action: #selector(Counter.fire))
        bar.items = [item]
        XCTAssertEqual(failure { try bar.tapTopItemOrThrow(withTitle: "Go") }?.kind, .invalidInput)
        XCTAssertEqual(left.count + right.count, 0)
    }

    func test_navBarTapTopItemOrThrow_withUniqueTitle_tapsOnlyThatItem() throws {
        let left = Counter(), right = Counter()
        let bar = UINavigationBar()
        let item = UINavigationItem(title: "t")
        item.leftBarButtonItem = UIBarButtonItem(title: "L", style: .plain, target: left, action: #selector(Counter.fire))
        item.rightBarButtonItem = UIBarButtonItem(title: "R", style: .plain, target: right, action: #selector(Counter.fire))
        bar.items = [item]
        try bar.tapTopItemOrThrow(withTitle: "R")
        XCTAssertEqual(left.count, 0)
        XCTAssertEqual(right.count, 1)
    }

    func test_navBarTapTopItemOrThrow_withoutTopItem_throwsInvalidSetup() {
        XCTAssertEqual(failure { try UINavigationBar().tapTopItemOrThrow(withTitle: "Go") }?.kind, .invalidSetup)
    }
    #endif
}

@MainActor
struct ActionRecoverableFailureTests {
    @Test func duplicateAlertTitleIsAssertableWithoutCrashing() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presentAlert(alert)
        #expect(throws: FleetFailure.self) {
            try alert.tapAlertActionOrThrow(withTitle: "OK")
        }
    }

    @Test func disabledButtonIsAssertableWithoutCrashing() {
        let button = UIButton(type: .system)
        button.isEnabled = false
        #expect(throws: FleetFailure.self) {
            try button.tapOrThrow()
        }
    }

    @Test func barButtonWithoutActionIsAssertableWithoutCrashing() {
        let item = UIBarButtonItem(title: "x", style: .plain, target: nil, action: nil)
        #expect(throws: FleetFailure.self) {
            try item.tapOrThrow()
        }
    }
}
