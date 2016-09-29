import XCTest
import Nimble

import Fleet
@testable import FleetTestApp

class UIAlertController_FleetSpec: XCTestCase {
    var storyboard: UIStoryboard!
    var viewControllerThatPresentsAlerts: SpottedTurtleViewController!

    override func setUp() {
        super.setUp()

        storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        viewControllerThatPresentsAlerts = storyboard.instantiateViewController(withIdentifier: "SpottedTurtleViewController") as! SpottedTurtleViewController

        Fleet.setApplicationWindowRootViewController(viewControllerThatPresentsAlerts)
    }

    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_executesTheActionHandler() {
        self.viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let alertController = Fleet.getApplicationScreen()?.presentedAlert
        alertController?.tapAlertActionWithTitle("Pick Up Anyway")

        expect(self.viewControllerThatPresentsAlerts.presentedViewController).to(beNil())
        expect(self.viewControllerThatPresentsAlerts.informationalLabel?.text).to(equal("WAIT NO PUT ME DOWN"))
    }

    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_whenActionIsCancelStyle_dismissesAlert() {
        let alertWithCancelAction = UIAlertController()
        alertWithCancelAction.addAction(UIAlertAction(title: "Go Away", style: .cancel, handler: nil))
        viewControllerThatPresentsAlerts.present(alertWithCancelAction, animated: false, completion: nil)

        let alertController = Fleet.getApplicationScreen()?.presentedAlert
        alertController?.tapAlertActionWithTitle("Go Away")

        expect(self.viewControllerThatPresentsAlerts.presentedViewController).to(beNil())
    }
}
