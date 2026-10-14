import XCTest
import UIKit
import Fleet

@MainActor
private final class ActionTarget: NSObject {
    var count = 0
    @objc func tapped() { count += 1 }
}

private class LifecycleSpy: UIViewController {
    var loaded = false
    override func viewDidLoad() {
        super.viewDidLoad()
        loaded = true
    }
}

@MainActor
final class PackageConsumerTests: XCTestCase {
    private var window: UIWindow!
    private var previousRoot: UIViewController?

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        window = UIApplication.shared.keyWindow
        XCTAssertNotNil(window, "The external consumer must run in an application host")
        previousRoot = window.rootViewController
    }

    override func tearDown() async throws {
        window.endEditing(true)
        if let root = window.rootViewController, root.presentedViewController != nil {
            let dismissed = expectation(description: "Dismiss consumer UI")
            root.dismiss(animated: false) { dismissed.fulfill() }
            await fulfillment(of: [dismissed], timeout: 5)
        }
        window.rootViewController = previousRoot
        previousRoot = nil
        window = nil
        try await super.tearDown()
    }

    private func storyboard() -> UIStoryboard {
        UIStoryboard(name: "Consumer", bundle: .main)
    }

    func testUIHelpersFromDetachedTaskHopToMainActor() async {
        let result = await Task.detached {
            await MainActor.run {
                let target = ActionTarget()
                let button = UIButton(type: .custom)
                button.addTarget(target, action: #selector(ActionTarget.tapped), for: .touchUpInside)
                button.tap()
                let controller = UIViewController()
                let window = UIWindow()
                window.rootViewController = controller
                return (onMainThread: Thread.isMainThread, tapCount: target.count,
                        matchesScreen: Fleet.getScreen(forWindow: window).topmostViewController === controller)
            }
        }.value
        XCTAssertTrue(result.onMainThread)
        XCTAssertEqual(result.tapCount, 1)
        XCTAssertTrue(result.matchesScreen)
    }

    func testPublicButtonActionExecutesExactlyOnce() {
        let target = ActionTarget()
        let button = UIButton(type: .custom)
        button.addTarget(target, action: #selector(ActionTarget.tapped), for: .touchUpInside)
        button.tap()
        XCTAssertEqual(target.count, 1)
    }

    func testHostedNavigationPushAndPop() {
        let root = UIViewController()
        let navigation = Fleet.setInAppWindowRootNavigation(root)
        XCTAssertTrue(window.rootViewController === navigation)
        XCTAssertNotNil(Fleet.getApplicationScreen())
        let detail = UIViewController()
        navigation.pushViewController(detail, animated: true)
        XCTAssertTrue(navigation.topViewController === detail)
        XCTAssertTrue(navigation.popViewController(animated: true) === detail)
        XCTAssertTrue(navigation.topViewController === root)
    }

    func testEmptyAndRootOnlyNavigationPopsPreserveTheRoot() {
        let empty = UINavigationController()
        XCTAssertNil(empty.popViewController(animated: false))
        XCTAssertNil(empty.popToRootViewController(animated: false))
        XCTAssertTrue(empty.viewControllers.isEmpty)

        let root = UIViewController()
        let navigation = Fleet.setInAppWindowRootNavigation(root)
        XCTAssertNil(navigation.popViewController(animated: true))
        XCTAssertNil(navigation.popToRootViewController(animated: true))
        XCTAssertEqual(navigation.viewControllers, [root])
        XCTAssertTrue(navigation.topViewController === root)
    }

    func testInvalidTabIndicesAreNoOps() {
        let first = UIViewController()
        let second = UIViewController()
        let tabs = UITabBarController()
        tabs.viewControllers = [first, second]
        tabs.selectedIndex = 1
        tabs.selectTab(atIndex: -1)
        XCTAssertEqual(tabs.selectedIndex, 1)
        tabs.selectTab(atIndex: 2)
        XCTAssertEqual(tabs.selectedIndex, 1)
        XCTAssertTrue(tabs.selectedViewController === second)
    }

    func testInvalidTableRowRequestsRaiseWithoutMutationOrCallbacks() {
        let source = SelectionSource()
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        table.dataSource = source
        table.delegate = source
        table.reloadData()
        let original = IndexPath(row: 0, section: 0)
        table.selectRow(at: original)
        XCTAssertEqual(table.indexPathForSelectedRow, original)
        source.events.removeAll()

        for invalid in [IndexPath(row: -1, section: 0), IndexPath(row: 0, section: -1), IndexPath(row: 5, section: 0)] {
            var returned = false
            Fleet.swallowAnyErrors {
                table.selectRow(at: invalid)
                returned = true
            }
            XCTAssertFalse(returned, "\(invalid) should raise")
            XCTAssertEqual(table.indexPathForSelectedRow, original)
            XCTAssertTrue(source.events.isEmpty)
        }

        source.redirect = IndexPath(row: -1, section: 0)
        var returned = false
        Fleet.swallowAnyErrors {
            table.selectRow(at: IndexPath(row: 1, section: 0))
            returned = true
        }
        XCTAssertFalse(returned, "An invalid delegate redirect should raise")
        XCTAssertEqual(table.indexPathForSelectedRow, original)
        XCTAssertTrue(source.events.isEmpty, "No did(De)Select callbacks for an invalid redirect: \(source.events)")

        source.redirect = nil
        table.selectRow(at: IndexPath(row: 1, section: 0))
        XCTAssertEqual(table.indexPathForSelectedRow, IndexPath(row: 1, section: 0))
        XCTAssertEqual(source.events, ["didDeselect 0", "didSelect 1"])
    }

    func testCompiledStoryboardMetadataAndBinding() throws {
        let metadata = Bundle(for: type(of: self)).url(forResource: "Info", withExtension: "plist", subdirectory: "StoryboardInfo/Consumer")
        XCTAssertNotNil(metadata, "The phase must run the metadata script bundled with the SwiftPM product")
        let storyboard = storyboard()
        let replacement = UIViewController()
        try storyboard.bind(viewController: replacement, toIdentifier: "Detail")
        XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === replacement)
    }

    func testStoryboardMockSuppressesProductionLifecycle() throws {
        let storyboard = storyboard()
        let mock = try storyboard.mockIdentifier("Detail", usingMockFor: LifecycleSpy.self)
        XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === mock)
        mock.loadViewIfNeeded()
        XCTAssertFalse(mock.loaded)
        let real = LifecycleSpy()
        real.loadViewIfNeeded()
        XCTAssertTrue(real.loaded, "Mocking must not alter real instances")
    }

    func testViewDidLoadHookRejectsBindingAnAlreadyLoadedController() throws {
        let storyboard = storyboard()
        let loaded = UIViewController()
        loaded.loadViewIfNeeded()
        var bindingReturned = false
        Fleet.swallowAnyErrors {
            try! storyboard.bind(viewController: loaded, toIdentifier: "Detail")
            bindingReturned = true
        }
        XCTAssertFalse(bindingReturned, "The Objective-C category must activate Fleet's viewDidLoad tracking")
    }

    func testPublicExceptionBridgeCatchesRealObjectiveCException() {
        var returnedAfterRaise = false
        Fleet.swallowAnyErrors {
            NSException(name: NSExceptionName("ConsumerException"), reason: "bridge regression", userInfo: nil).raise()
            returnedAfterRaise = true
        }
        XCTAssertFalse(returnedAfterRaise)
    }

    func testPresentationCompletionWithPublicUIKitAPI() async {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let presented = UIViewController()
        let completion = expectation(description: "Presentation completed")
        root.present(presented, animated: true) { completion.fulfill() }
        await fulfillment(of: [completion], timeout: 5)
        XCTAssertTrue(root.presentedViewController === presented)
    }

    func testAlertHandlerCaptureAndDispatch() async {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let alert = UIAlertController(title: "Consumer", message: nil, preferredStyle: .alert)
        var count = 0
        let handler = expectation(description: "Alert action called")
        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
            count += 1
            handler.fulfill()
        })
        let presented = expectation(description: "Alert presented")
        root.present(alert, animated: false) { presented.fulfill() }
        await fulfillment(of: [presented], timeout: 5)
        alert.tapAlertAction(withTitle: "Continue")
        await fulfillment(of: [handler], timeout: 5)
        XCTAssertEqual(count, 1)
    }

#if os(iOS)
    func testContextualActionLeadingAndTrailingReplacements() {
        let source = SwipeSource()
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        table.dataSource = source
        table.delegate = source
        table.reloadData()
        let row = IndexPath(row: 0, section: 0)

        XCTAssertTrue(table.performContextualAction(withTitle: "Pin", edge: .leading, at: row))
        XCTAssertFalse(table.performContextualAction(atIndex: 0, edge: .trailing, at: row))
        XCTAssertEqual(source.invoked, ["Pin", "Delete"])

        var raised = false
        Fleet.swallowAnyErrors {
            table.performContextualAction(withTitle: "Missing", edge: .leading, at: row)
            raised = true
        }
        XCTAssertFalse(raised)
    }
#endif

    func testScopedContextHostsExplicitWindowAndScene() async throws {
        let host = try XCTUnwrap(window)
        let scene = try XCTUnwrap(host.windowScene)
        let borrowedRoot = UIViewController()
        try await Fleet.withContext(window: host) { context in
            try await context.setRoot(borrowedRoot)
            XCTAssertTrue(context.screen.topmostViewController === borrowedRoot)
        }
        XCTAssertTrue(host.rootViewController === previousRoot)

        weak var ownedRoot: UIViewController?
        try await Fleet.withContext(scene: scene) { context in
            let root = UIViewController()
            ownedRoot = root
            try await context.setRoot(root)
            XCTAssertTrue(context.window.windowScene === scene)
        }
        for _ in 0..<50 where ownedRoot != nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(ownedRoot)
        XCTAssertTrue(host.isKeyWindow)
    }

    func testScopedContextWaitTimesOutWithTypedFailure() async throws {
        let host = try XCTUnwrap(window)
        do {
            try await Fleet.withContext(window: host) { context in
                try await context.waitUntil("never", timeout: 0.05) { false }
            }
            XCTFail("Expected timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertTrue(failure.action.contains("never"))
        }
    }
}

#if os(iOS)
@MainActor
private final class SwipeSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    var invoked: [String] = []

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }

    private func action(_ title: String, completesWith result: Bool) -> UIContextualAction {
        UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            self?.invoked.append(title)
            completion(result)
        }
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [action("Pin", completesWith: true)])
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        UISwipeActionsConfiguration(actions: [action("Delete", completesWith: false)])
    }
}
#endif

@MainActor
private final class SelectionSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    var events: [String] = []
    var redirect: IndexPath?

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 2 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        UITableViewCell(style: .default, reuseIdentifier: nil)
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        redirect ?? indexPath
    }

    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? { indexPath }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        events.append("didSelect \(indexPath.row)")
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        events.append("didDeselect \(indexPath.row)")
    }
}
