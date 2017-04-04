import XCTest
import Nimble

import Fleet
@testable import FleetTestApp

class UIAlertController_FleetSpec: XCTestCase {
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

        try! alert.tapAlertAction(withTitle: "action")
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

        try! alert.tapAlertAction(withTitle: "cancel")
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

        expect { try alert.tapAlertAction(withTitle: "banana shoes") }.to(
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

        try! alert.tapAlertAction(withTitle: "action")
        expect(didCallOnMainThread).toEventually(beTrue())
    }
}
