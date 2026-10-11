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

    func testCollectionViewSelectionAndCellInspectionWithDiffableDataSource() async {
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
        XCTAssertFalse(collectionView.configuredCell(at: item) === collectionView.fetchCell(at: item))
        collectionView.selectItem(at: item)
        XCTAssertEqual(collectionView.indexPathsForSelectedItems, [item])
        collectionView.deselectItem(at: item)
        XCTAssertEqual(collectionView.indexPathsForSelectedItems ?? [], [])
    }
}
