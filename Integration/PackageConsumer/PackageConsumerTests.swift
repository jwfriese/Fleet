import XCTest
import UIKit
import Fleet

@MainActor
private final class ChainResponder: UIViewController {
    var count = 0
    override var canBecomeFirstResponder: Bool { true }
    @objc func chainAction(_ sender: Any?) { count += 1 }
}

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
private final class ConsumerFlag {
    var value = false
}

/// Starts an independent caller; a detached task does not inherit the active scope.
@MainActor
private func queuedAttempt(flag: ConsumerFlag) -> Task<Void, Error> {
    Task.detached { try await runQueued(flag) }
}

@MainActor
private func runQueued(_ flag: ConsumerFlag) async throws {
    let host = try XCTUnwrap(UIApplication.shared.keyWindow)
    try await Fleet.withContext(window: host) { _ in flag.value = true }
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

    private func waitUntilSettled(_ condition: () -> Bool) async throws {
        for _ in 0..<250 where !condition() {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition(), "State did not settle within the bounded wait")
    }

    func testScreenSeparatesContainerFromVisibleContent() async throws {
        let window = UIWindow()
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        let tabs = UITabBarController()
        tabs.viewControllers = [navigation]
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        let pushed = UIViewController()
        navigation.pushViewController(pushed, animated: true)

        var screen = Fleet.getScreen(forWindow: window)
        XCTAssertTrue(screen.topmostViewController === pushed)
        XCTAssertTrue(screen.topmostContainer === tabs)

        let modalRoot = UIViewController()
        let modalNavigation = UINavigationController(rootViewController: modalRoot)
        tabs.present(modalNavigation, animated: false, completion: nil)
        try await waitUntilSettled { modalNavigation.presentingViewController === tabs && !modalNavigation.isBeingPresented }
        screen = Fleet.getScreen(forWindow: window)
        XCTAssertTrue(screen.topmostContainer === modalNavigation)
        XCTAssertTrue(screen.topmostViewController === modalRoot)

        let secondModal = UIViewController()
        modalNavigation.present(secondModal, animated: false, completion: nil)
        try await waitUntilSettled { Fleet.getScreen(forWindow: window).topmostContainer === secondModal }

        screen = Fleet.getScreen(forWindow: window)
        XCTAssertTrue(screen.topmostContainer === secondModal)
        XCTAssertTrue(screen.topmostViewController === secondModal)
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

    func testStoryboardBindingsAreReleasedAndMetadataBundleIsExplicit() throws {
        let storyboard = storyboard()
        try storyboard.useBindingMetadata(forStoryboardNamed: "Consumer", in: Bundle(for: type(of: self)))
        weak var weakController: UIViewController?
        try autoreleasepool {
            let controller = UIViewController()
            weakController = controller
            try storyboard.bind(viewController: controller, toIdentifier: "Detail")
            XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === controller)
        }
        XCTAssertNotNil(weakController)
        storyboard.removeBindings()
        XCTAssertNil(weakController)
        XCTAssertFalse(storyboard.instantiateViewController(withIdentifier: "Detail") === weakController)
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
        XCTAssertThrowsError(try storyboard.bind(viewController: loaded, toIdentifier: "Detail"),
                             "The Objective-C category must activate Fleet's viewDidLoad tracking") { error in
            guard let failure = error as? FleetFailure else {
                return XCTFail("Expected FleetFailure, got \(error)")
            }
            XCTAssertEqual(failure.kind, .invalidInput)
        }
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

    func testCollectionViewSelectionAndCellInspectionWithDiffableDataSource() async throws {
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        let dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { view, indexPath, _ in
            view.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(["Dune", "Fern"])
        await dataSource.apply(snapshot, animatingDifferences: false)
        let root = UIViewController()
        root.view.addSubview(collectionView)
        Fleet.setAsAppWindowRoot(root)
        collectionView.layoutIfNeeded()

        let item = IndexPath(item: 1, section: 0)
        XCTAssertNotNil(collectionView.displayedCell(at: item))
        XCTAssertTrue(collectionView.displayedCell(at: item) === collectionView.fetchCell(at: item))
        collectionView.selectItem(at: item)
        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [item])
        XCTAssertTrue(try collectionView.displayedCellOrThrow(at: item) === collectionView.displayedCell(at: item))
        XCTAssertThrowsError(try collectionView.deselectItemOrThrow(at: IndexPath(item: 99, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [item])
        collectionView.deselectItem(at: item)
        XCTAssertEqual(collectionView.indexPathsForSelectedItems ?? [], [])
    }

    func testContextReleasesBindingsOnRetainedStoryboardWithoutManualCleanup() async throws {
        let host = try XCTUnwrap(window)
        let storyboard = storyboard()
        let original = UIViewController()
        try storyboard.bind(viewController: original, toIdentifier: "Detail")
        weak var replacement: UIViewController?
        try await Fleet.withContext(window: host) { _ in
            let mock = try storyboard.mockIdentifier("Detail", usingMockFor: UIViewController.self)
            replacement = mock
            XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === mock)
        }
        XCTAssertNil(replacement)
        XCTAssertTrue(storyboard.instantiateViewController(withIdentifier: "Detail") === original)
    }

    func testModernAndRetainedButtonActionsEachExecuteExactlyOnce() {
        let target = ActionTarget()
        var primary = 0
        var modern = 0
        let button = UIButton(primaryAction: UIAction { _ in primary += 1 })
        button.addAction(UIAction { _ in modern += 1 }, for: .touchUpInside)
        button.addTarget(target, action: #selector(ActionTarget.tapped), for: .touchUpInside)
        button.tap()
        XCTAssertEqual([primary, modern, target.count], [1, 1, 1])
    }

    func testBarButtonItemDispatchesPrimaryActionAndTargetActionOnce() {
        let target = ActionTarget()
        let item = UIBarButtonItem(title: "Item", style: .plain, target: target, action: #selector(ActionTarget.tapped))
        item.tap()
        XCTAssertEqual(target.count, 1)

        var primary = 0
        UIBarButtonItem(primaryAction: UIAction(title: "Primary") { _ in primary += 1 }).tap()
        XCTAssertEqual(primary, 1)
    }

    func testBarButtonItemWithoutTargetUsesResponderChainAndFailsWhenUnresolved() {
        let responder = ChainResponder()
        Fleet.setAsAppWindowRoot(responder)
        XCTAssertTrue(responder.becomeFirstResponder())
        defer { _ = responder.resignFirstResponder() }
        UIBarButtonItem(title: "Chain", style: .plain, target: nil, action: #selector(ChainResponder.chainAction(_:))).tap()
        XCTAssertEqual(responder.count, 1)

        var returnedAfterRaise = false
        Fleet.swallowAnyErrors {
            UIBarButtonItem(title: "Lost", style: .plain, target: nil, action: Selector(("consumerNobodyImplementsThis:"))).tap()
            returnedAfterRaise = true
        }
        XCTAssertFalse(returnedAfterRaise)
    }

    func testRuntimeHooksPresentSynchronously() {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let presented = UIViewController()
        root.present(presented, animated: true)
        XCTAssertTrue(root.presentedViewController === presented, "The present hook must run automatically")
    }

    func testAlertTapRejectsAmbiguousTitlesWithoutRunningHandlers() {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let alert = UIAlertController(title: "Consumer", message: nil, preferredStyle: .alert)
        var count = 0
        alert.addAction(UIAlertAction(title: "Same", style: .default) { _ in count += 1 })
        alert.addAction(UIAlertAction(title: "Same", style: .cancel) { _ in count += 1 })
        root.present(alert, animated: false)

        var returnedAfterRaise = false
        Fleet.swallowAnyErrors {
            alert.tapAlertAction(withTitle: "Same")
            returnedAfterRaise = true
        }
        XCTAssertFalse(returnedAfterRaise)
        XCTAssertEqual(count, 0)
        XCTAssertTrue(root.presentedViewController === alert)
    }

    func testRecoverableActionFailuresAreAssertableWithoutExceptions() throws {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let alert = UIAlertController(title: "Consumer", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Same", style: .default))
        alert.addAction(UIAlertAction(title: "Same", style: .cancel))
        root.present(alert, animated: false)
        XCTAssertThrowsError(try alert.tapAlertActionOrThrow(withTitle: "Same")) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }

        let button = UIButton(type: .system)
        button.isEnabled = false
        XCTAssertThrowsError(try button.tapOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }

        let item = UIBarButtonItem(title: "none", style: .plain, target: nil, action: nil)
        XCTAssertThrowsError(try item.tapOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }

        let target = ActionTarget()
        let navBar = UINavigationBar()
        let navItem = UINavigationItem(title: "t")
        navItem.leftBarButtonItem = UIBarButtonItem(title: "Go", style: .plain, target: target, action: #selector(ActionTarget.tapped))
        navItem.rightBarButtonItem = UIBarButtonItem(title: "Go", style: .plain, target: target, action: #selector(ActionTarget.tapped))
        navBar.items = [navItem]
        XCTAssertThrowsError(try navBar.tapTopItemOrThrow(withTitle: "Go")) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        XCTAssertEqual(target.count, 0)
    }

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

    func testNestedScopedContextIsRejectedWithoutWaitingAndRecovers() async throws {
        let host = try XCTUnwrap(window)
        let scene = try XCTUnwrap(host.windowScene)
        let queuedRan = ConsumerFlag()
        var failures: [FleetFailure] = []
        var queued: Task<Void, Error>?
        var child: Task<Void, Error>?
        let scenario = Task { @MainActor in
            try await Fleet.withContext(window: host) { _ in
                // Direct nesting, both overloads.
                do { try await Fleet.withContext(window: host) { _ in XCTFail("Nested body ran") } } catch let failure as FleetFailure { failures.append(failure) }
                do { try await Fleet.withContext(scene: scene) { _ in XCTFail("Nested body ran") } } catch let failure as FleetFailure { failures.append(failure) }
                // An awaited child task inherits the active context.
                let inherited = Task { @MainActor in
                    try await Fleet.withContext(window: host) { _ in XCTFail("Nested body ran") }
                }
                child = inherited
                do { try await inherited.value } catch let failure as FleetFailure { failures.append(failure) }
                // A detached task does not inherit ownership, so it queues behind this scope.
                queued = queuedAttempt(flag: queuedRan)
                for _ in 0..<20 { await Task.yield() }
            }
        }
        let watchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            scenario.cancel()
            child?.cancel()
            queued?.cancel()
        }
        defer { watchdog.cancel() }
        try await scenario.value
        if let queued { try await queued.value }
        XCTAssertEqual(failures.map(\.kind), [.invalidSetup, .invalidSetup, .invalidSetup])
        XCTAssertTrue(queuedRan.value)
        let successorTask = Task { @MainActor in try await Fleet.withContext(window: host) { _ in true } }
        let successorWatchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            successorTask.cancel()
        }
        defer { successorWatchdog.cancel() }
        let successor = try await successorTask.value
        XCTAssertTrue(successor)
        XCTAssertTrue(host.rootViewController === previousRoot)
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

@MainActor
final class EnvironmentConsumerTests: XCTestCase {
    func test_publicEnvironmentConfiguration_appliesAndRestores() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let frame = window.frame
        let style = window.overrideUserInterfaceStyle
        let size = CGSize(width: frame.width / 2, height: frame.height / 2)
        try await Fleet.withContext(window: window) { context in
            try await context.setRoot(UIViewController())
            try await context.configure(FleetEnvironment(size: size, userInterfaceStyle: .dark))
            XCTAssertEqual(window.bounds.size, size)
            XCTAssertEqual(window.traitCollection.userInterfaceStyle, .dark)
            if #available(iOS 17, tvOS 17, *) {
                try await context.configure(FleetEnvironment(contentSizeCategory: .accessibilityLarge))
                XCTAssertEqual(window.traitCollection.preferredContentSizeCategory, .accessibilityLarge)
            }
        }
        XCTAssertEqual(window.frame, frame)
        XCTAssertEqual(window.overrideUserInterfaceStyle, style)
    }
}
