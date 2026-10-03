import XCTest
import UIKit
import Fleet

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

final class PackageConsumerTests: XCTestCase {
    private var window: UIWindow!
    private var previousRoot: UIViewController?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        window = UIApplication.shared.keyWindow
        XCTAssertNotNil(window, "The external consumer must run in an application host")
        previousRoot = window.rootViewController
    }

    override func tearDown() {
        window.endEditing(true)
        if let root = window.rootViewController, root.presentedViewController != nil {
            let dismissed = expectation(description: "Dismiss consumer UI")
            root.dismiss(animated: false) { dismissed.fulfill() }
            wait(for: [dismissed], timeout: 5)
        }
        window.rootViewController = previousRoot
        previousRoot = nil
        window = nil
        super.tearDown()
    }

    private func storyboard() -> UIStoryboard {
        UIStoryboard(name: "Consumer", bundle: .main)
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

    func testPresentationCompletionWithPublicUIKitAPI() {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let presented = UIViewController()
        let completion = expectation(description: "Presentation completed")
        root.present(presented, animated: true) { completion.fulfill() }
        wait(for: [completion], timeout: 5)
        XCTAssertTrue(root.presentedViewController === presented)
    }

    func testAlertHandlerCaptureAndDispatch() {
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
        wait(for: [presented], timeout: 5)
        alert.tapAlertAction(withTitle: "Continue")
        wait(for: [handler], timeout: 5)
        XCTAssertEqual(count, 1)
    }
}
