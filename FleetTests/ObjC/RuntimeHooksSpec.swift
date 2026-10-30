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

    private func presentedAlert(_ action: UIAlertAction) -> UIAlertController {
        let root = UIViewController()
        Fleet.setAsAppWindowRoot(root)
        let alert = UIAlertController(title: "t", message: nil, preferredStyle: .alert)
        alert.addAction(action)
        root.present(alert, animated: false, completion: nil)
        return alert
    }

    func test_handlerCapture_distinguishesObservedHandlerFromObservedNil() {
        expect(UIAlertAction(title: "h", style: .default) { _ in }.handlerCapture).to(equal(.observedHandler))
        expect(UIAlertAction(title: "n", style: .default, handler: nil).handlerCapture).to(equal(.observedNil))
    }

    func test_strictTap_runsObservedHandlerExactlyOnce() async throws {
        var calls = 0
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls += 1 })
        let outcome = try await alert.tapAlertActionStrictly(withTitle: "go")
        expect(outcome).to(equal(.handlerInvoked))
        expect(calls).to(equal(1))
    }

    func test_strictTap_dismissesObservedNilHandlerWithoutClaimingExecution() async throws {
        let alert = presentedAlert(UIAlertAction(title: "none", style: .default, handler: nil))
        let outcome = try await alert.tapAlertActionStrictly(withTitle: "none")
        expect(outcome).to(equal(.dismissedWithoutHandler))
        expect(alert.presentingViewController).to(beNil())
    }

    private func strictFailure(_ alert: UIAlertController, _ title: String) async -> FleetFailure? {
        do {
            _ = try await alert.tapAlertActionStrictly(withTitle: title)
            return nil
        } catch {
            return error as? FleetFailure
        }
    }

    func test_strictTap_timesOutWhenCompletionIsWithheldThenLateCallbackRunsHandlerOnce() async throws {
        var calls = 0
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls += 1 })
        var pending: (() -> Void)?
        do {
            _ = try await alert.strictTap(withTitle: "go", timeout: 0.2) { _, completion in pending = completion }
            XCTFail("expected a timeout")
        } catch let failure as FleetFailure {
            expect(failure.kind).to(equal(.timedOut))
            expect(failure.target).to(contain("go"))
            expect(failure.state).to(contain("may still run"))
        }
        expect(calls).to(equal(0))
        pending?()
        pending?()
        expect(calls).to(equal(1))
    }

    func test_strictTap_handlesSynchronousDelayedAndDuplicateCompletion() async throws {
        var calls = 0
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls += 1 })
        let sync = try await alert.strictTap(withTitle: "go", timeout: 5) { _, completion in completion?(); completion?() }
        expect(sync).to(equal(.handlerInvoked))
        expect(calls).to(equal(1))

        var calls2 = 0
        let alert2 = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls2 += 1 })
        let delayed = try await alert2.strictTap(withTitle: "go", timeout: 5) { _, completion in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { completion?(); completion?() }
        }
        expect(delayed).to(equal(.handlerInvoked))
        expect(calls2).to(equal(1))
    }

    func test_strictTap_rejectsInvalidTimeoutBeforeDismissing() async {
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in })
        for bad in [0, -1, Double.nan, Double.infinity] {
            do {
                _ = try await alert.tapAlertActionStrictly(withTitle: "go", timeout: bad)
                XCTFail("expected invalidInput")
            } catch {
                expect((error as? FleetFailure)?.kind).to(equal(.invalidInput))
            }
        }
        expect(alert.presentingViewController).toNot(beNil())
    }

    func test_strictTap_preCancelledTaskHasNoSideEffects() async {
        var calls = 0
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls += 1 })
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await alert.tapAlertActionStrictly(withTitle: "go")
        }
        do { _ = try await task.value; XCTFail("expected cancellation") } catch { expect(error is CancellationError).to(beTrue()) }
        expect(alert.presentingViewController).toNot(beNil())
        expect(calls).to(equal(0))
    }

    func test_strictTap_cancellationWhileWaitingThrowsOnceAndLeavesCleanSuccessor() async {
        var calls = 0
        let alert = presentedAlert(UIAlertAction(title: "go", style: .default) { _ in calls += 1 })
        var pending: (() -> Void)?
        let task = Task { @MainActor in
            try await alert.strictTap(withTitle: "go", timeout: 30) { _, completion in pending = completion }
        }
        while pending == nil { await Task.yield() }
        task.cancel()
        do { _ = try await task.value; XCTFail("expected cancellation") } catch { expect(error is CancellationError).to(beTrue()) }
        pending?()
        expect(calls).to(equal(1))

        var calls2 = 0
        let next = presentedAlert(UIAlertAction(title: "again", style: .default) { _ in calls2 += 1 })
        let outcome = try? await next.tapAlertActionStrictly(withTitle: "again")
        expect(outcome).to(equal(.handlerInvoked))
        expect(calls2).to(equal(1))
    }

    func test_strictTap_throwsWithoutDismissingWhenCaptureEvidenceIsMissing() async {
        var calls = 0
        let action = UIAlertAction(title: "lost", style: .default) { _ in calls += 1 }
        action.fleet_discardCaptureEvidence()
        let alert = presentedAlert(action)
        expect(alert.alertHandlerCapture(forActionWithTitle: "lost")).to(equal(.unobserved))

        let failure = await strictFailure(alert, "lost")
        expect(failure?.kind).to(equal(.invalidSetup))
        expect(failure?.state).to(contain("never observed"))
        expect(alert.presentingViewController).toNot(beNil())
        expect(calls).to(equal(0))
    }

    func test_strictTap_throwsTypedFailureWhenCaptureHookIsUnavailable() async {
        let alert = presentedAlert(UIAlertAction(title: "x", style: .default) { _ in })
        let previous = UIAlertAction.fleet_setCaptureHookInstalled(false)
        defer { UIAlertAction.fleet_setCaptureHookInstalled(previous) }
        expect(alert.alertHandlerCapture(forActionWithTitle: "x")).to(equal(.unavailable))
        let failure = await strictFailure(alert, "x")
        expect(failure?.kind).to(equal(.invalidSetup))
        expect(failure?.state).to(contain("unavailable"))
        expect(alert.presentingViewController).toNot(beNil())
    }

    func test_strictTap_keepsClearFailuresForDisabledAmbiguousAndUnpresentedActions() async {
        let disabled = UIAlertAction(title: "d", style: .default) { _ in }
        disabled.isEnabled = false
        let alert = presentedAlert(disabled)
        let disabledFailure = await strictFailure(alert, "d")
        expect(disabledFailure?.kind).to(equal(.unavailableInteraction))
        let missingFailure = await strictFailure(alert, "zzz")
        expect(missingFailure?.kind).to(equal(.invalidInput))
        let loose = UIAlertController(title: "t", message: nil, preferredStyle: .alert)
        loose.addAction(UIAlertAction(title: "a", style: .default) { _ in })
        let looseFailure = await strictFailure(loose, "a")
        expect(looseFailure?.kind).to(equal(.unavailableInteraction))
    }
}
