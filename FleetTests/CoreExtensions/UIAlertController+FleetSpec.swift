import XCTest
import Nimble

import Fleet
@testable import FleetTestApp

class UIAlertController_FleetSpec: XCTestCase {
    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_executesTheActionHandlerAfterDismissingAlert() {
        let rootViewController = UIViewController()
        Fleet.setApplicationWindowRootViewController(rootViewController)

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
        Fleet.setApplicationWindowRootViewController(rootViewController)

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
}
