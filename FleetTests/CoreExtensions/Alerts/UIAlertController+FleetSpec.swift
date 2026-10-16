import XCTest
import Nimble

import Fleet
@testable import FleetTestApp

@MainActor
class UIAlertController_FleetSpec: XCTestCase {
    private var fixture: HostedUIFixture!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        fixture = HostedUIFixture()
    }

    override func tearDown() async throws {
        await fixture.restore()
        fixture = nil
        try await super.tearDown()
    }

    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_executesTheActionHandlerAfterDismissingAlert() {
        let rootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(rootViewController)

        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        var didCallHandlerAfterDismissingAlert = false
        let actionHandler: (UIAlertAction) -> () = { _ in
            if Fleet.getApplicationScreen()?.topmostViewController === rootViewController {
                didCallHandlerAfterDismissingAlert = true
            }
        }

        let action = UIAlertAction(title: "action", style: .default, handler: actionHandler)
        alert.addAction(action)
        rootViewController.present(alert, animated: false, completion: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))

        alert.tapAlertAction(withTitle: "action")
        expect(didCallHandlerAfterDismissingAlert).toEventually(beTrue())
    }

    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_whenActionIsCancelStyle_executesTheActionHandlerAfterDismissingAlert() {
        let rootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(rootViewController)

        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        var didCallHandlerAfterDismissingAlert = false
        let actionHandler: (UIAlertAction) -> () = { _ in
            if Fleet.getApplicationScreen()?.topmostViewController === rootViewController {
                didCallHandlerAfterDismissingAlert = true
            }
        }

        let action = UIAlertAction(title: "cancel", style: .cancel, handler: actionHandler)
        alert.addAction(action)
        rootViewController.present(alert, animated: false, completion: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))

        alert.tapAlertAction(withTitle: "cancel")
        expect(didCallHandlerAfterDismissingAlert).toEventually(beTrue())
    }

    func test_tapAlertActionWithTitle_whenNoActionWithThatTitleExists_raisesException() {
        let rootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(rootViewController)

        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)

        let action = UIAlertAction(title: "action", style: .default, handler: nil)
        alert.addAction(action)
        rootViewController.present(alert, animated: false, completion: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))

        expect { alert.tapAlertAction(withTitle: "banana shoes") }.to(
            raiseException(named: "Fleet.AlertError", reason: "No action with title 'banana shoes' found on alert.", userInfo: nil, closure: nil)
        )
    }

    func test_tapAlertActionWithTitle_callsUIKitMethodsOnMainThread() {
        let rootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(rootViewController)

        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        var didCallOnMainThread = false
        let actionHandler: (UIAlertAction) -> () = { _ in
            if Fleet.getApplicationScreen()?.topmostViewController === rootViewController {
                didCallOnMainThread = Thread.isMainThread
            }
        }

        let action = UIAlertAction(title: "action", style: .default, handler: actionHandler)
        alert.addAction(action)
        rootViewController.present(alert, animated: false, completion: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))

        alert.tapAlertAction(withTitle: "action")
        expect(didCallOnMainThread).toEventually(beTrue())
    }

    private func presentAlert(_ actions: [UIAlertAction]) -> (UIViewController, UIAlertController) {
        let rootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(rootViewController)
        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        actions.forEach { alert.addAction($0) }
        rootViewController.present(alert, animated: false, completion: nil)
        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))
        return (rootViewController, alert)
    }

    func test_tapAlertActionWithTitle_whenMultipleActionsShareTitle_raisesExceptionAndFiresNoHandler() {
        var calls = 0
        let (_, alert) = presentAlert([
            UIAlertAction(title: "same", style: .default) { _ in calls += 1 },
            UIAlertAction(title: "same", style: .destructive) { _ in calls += 1 }
        ])

        expect { alert.tapAlertAction(withTitle: "same") }.to(
            raiseException(named: "Fleet.AlertError", reason: "2 actions with title 'same' found on alert; Fleet will not guess which to tap.", userInfo: nil, closure: nil)
        )
        expect(calls).to(equal(0))
        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))
    }

    func test_tapAlertActionWithTitle_whenActionIsDisabled_raisesExceptionAndFiresNoHandler() {
        var calls = 0
        let action = UIAlertAction(title: "off", style: .default) { _ in calls += 1 }
        action.isEnabled = false
        let (_, alert) = presentAlert([action])

        expect { alert.tapAlertAction(withTitle: "off") }.to(
            raiseException(named: "Fleet.AlertError", reason: "Cannot tap alert action with title 'off': Action is not enabled.", userInfo: nil, closure: nil)
        )
        expect(calls).to(equal(0))
        expect(Fleet.getApplicationScreen()?.topmostViewController).to(beIdenticalTo(alert))
    }

    func test_tapAlertActionWithTitle_whenAlertIsNotPresented_raisesExceptionAndFiresNoHandler() {
        var calls = 0
        let alert = UIAlertController(title: "title", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "action", style: .default) { _ in calls += 1 })

        expect { alert.tapAlertAction(withTitle: "action") }.to(
            raiseException(named: "Fleet.AlertError", reason: "Cannot tap alert action with title 'action': Alert is not presented.", userInfo: nil, closure: nil)
        )
        expect(calls).to(equal(0))
    }

    func test_tapAlertActionWithTitle_whenActionHasNoHandler_dismissesAlert() {
        let (rootViewController, alert) = presentAlert([UIAlertAction(title: "plain", style: .default, handler: nil)])

        alert.tapAlertAction(withTitle: "plain")

        expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(rootViewController))
    }

    func test_tapAlertActionWithTitle_invokesHandlerExactlyOnceAfterDismissalCompletes() {
        var calls = 0
        var alertWasStillPresentedInHandler: Bool?
        weak var presenter: UIViewController?
        let (rootViewController, alert) = presentAlert([
            UIAlertAction(title: "go", style: .default) { _ in
                calls += 1
                alertWasStillPresentedInHandler = presenter?.presentedViewController != nil
            }
        ])
        presenter = rootViewController

        alert.tapAlertAction(withTitle: "go")

        expect(calls).toEventually(equal(1))
        expect(alertWasStillPresentedInHandler).to(equal(false))
        expect(calls).toNever(beGreaterThan(1), until: .milliseconds(300))
    }
}
