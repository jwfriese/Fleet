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
        viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController

        Fleet.swapWindowRootViewController(viewControllerThatPresentsAlerts)
    }

    func test_tapAlertActionWithTitle_whenActionWithThatTitleExistsOnAlert_executesTheActionHandler() {
        self.viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let alertController = Fleet.getCurrentScreen()?.presentedAlert
        alertController?.tapAlertActionWithTitle("Pick Up Anyway")

        expect(self.viewControllerThatPresentsAlerts.presentedViewController).to(beNil())
        expect(self.viewControllerThatPresentsAlerts.informationalLabel?.text).to(equal("WAIT NO PUT ME DOWN"))
    }
}
