import XCTest
import ObjectiveC
import Nimble

@testable import Fleet

/// Probes for every runtime hook Fleet retains (see Documentation/RuntimeHooks.md).
/// Each probe checks that the automatic `+load` activation took effect and observes the
/// hook's behavioral effect through UIKit's public API.
@MainActor
class RuntimeHooksSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func test_privateSelectorsRetainedByHooksStillExist() {
        expect(class_getInstanceMethod(UIAlertAction.self, Selector(("setHandler:")))).toNot(beNil())
    }

    func test_viewDidLoadHook_countsLoadsOfRealControllers() {
        let controller = UIViewController()
        expect(controller.viewDidLoadCallCount).to(equal(0))
        controller.loadViewIfNeeded()
        controller.loadViewIfNeeded()
        expect(controller.viewDidLoadCallCount).to(equal(1))
    }

    func test_hostingPolicy_isExposedAndMatchesProcessStartEnvironment() {
        let requested = ProcessInfo.processInfo.environment["FLEET_HOSTING_POLICY"]
        expect(Fleet.hostingPolicy.rawValue).to(equal(requested?.isEmpty == false ? requested : "legacy"))
    }

    func test_preserveTiming_doesNotForceNonanimatedNavigationOrLoadPushedViews() throws {
        try XCTSkipUnless(Fleet.hostingPolicy == .preserveTiming, "Runs only in a process launched with FLEET_HOSTING_POLICY=preserve-timing")
        let root = UIViewController()
        let second = UIViewController()
        let navigation = Fleet.setInAppWindowRootNavigation(root)

        navigation.pushViewController(second, animated: true)
        expect(navigation.transitionCoordinator).toNot(beNil())
        expect(navigation.viewControllers).to(equal([root, second]))
        expect(second.isViewLoaded).toEventually(beTrue())
    }

    func test_presentAndDismissHooks_completeSynchronouslyEvenWhenAnimationIsRequested() throws {
        try XCTSkipUnless(Fleet.hostingPolicy == .legacy, "Timing hooks are installed only by the legacy policy")
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let presented = UIViewController()

        root.present(presented, animated: true, completion: nil)
        expect(root.presentedViewController).to(beIdenticalTo(presented))

        root.dismiss(animated: true, completion: nil)
        expect(root.presentedViewController).toEventually(beNil())
    }

    func test_navigationHooks_pushAndPopSynchronouslyWithoutAnimation() throws {
        try XCTSkipUnless(Fleet.hostingPolicy == .legacy, "Timing hooks are installed only by the legacy policy")
        let root = UIViewController()
        let second = UIViewController()
        let third = UIViewController()
        let navigation = Fleet.setInAppWindowRootNavigation(root)

        navigation.pushViewController(second, animated: true)
        navigation.pushViewController(third, animated: true)
        expect(navigation.viewControllers).to(equal([root, second, third]))
        expect(second.isViewLoaded).to(beTrue())

        expect(navigation.popViewController(animated: true)).to(beIdenticalTo(third))
        expect(navigation.popToRootViewController(animated: true)).to(equal([second]))
        expect(navigation.viewControllers).to(equal([root]))
    }

    func test_alertActionHook_capturesHandlerAndLeavesUIKitStateIntact() {
        var calls = 0
        let action = UIAlertAction(title: "captured", style: .destructive) { _ in calls += 1 }

        action.handler?(action)

        expect(calls).to(equal(1))
        expect(action.title).to(equal("captured"))
        expect(action.style).to(equal(.destructive))
        expect(UIAlertAction(title: "none", style: .default, handler: nil).handler).to(beNil())
    }
}
