import XCTest
import Fleet
import Nimble
@testable import FleetTestApp

class SegueDetailSpec: XCTestCase {
    func test_bindingViewControllersInSegues_doesNotCallViewDidLoadBeforePrepareForSegue() {
        let storyboard = UIStoryboard(name: "PuppyStoryboard", bundle: nil)
        let corgiViewController = CorgiViewController()
        try! storyboard.bind(viewController: corgiViewController, toIdentifier: "CorgiViewController")

        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        Fleet.setAsAppWindowRoot(navigationController)

        guard let puppyViewController = navigationController.topViewController as? PuppyListViewController else {
            fail("Failed to properly set up controller for segue detail test")
            return
        }

        puppyViewController.performSegue(withIdentifier: "ShowCorgi", sender: nil)

        expect(puppyViewController.segueDestinationViewDidLoadCallCount).to(equal(0))
    }

    func test_bindingViewControllersInSegues_makesTheBoundViewControllerAvailableAsDestinationViewControllerInTheSegue() {
        let storyboard = UIStoryboard(name: "PuppyStoryboard", bundle: nil)
        let corgiViewController = CorgiViewController()
        try! storyboard.bind(viewController: corgiViewController, toIdentifier: "CorgiViewController")

        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        Fleet.setAsAppWindowRoot(navigationController)

        guard let puppyViewController = navigationController.topViewController as? PuppyListViewController else {
            fail("Failed to properly set up controller for segue detail test")
            return
        }

        puppyViewController.performSegue(withIdentifier: "ShowCorgi", sender: nil)

        expect(puppyViewController.segueDestinationViewController).to(beIdenticalTo(corgiViewController))
    }

    func test_verifyNoIBOutletsPopulatedBeforePrepareForSegueWhenBindingViewControllersInSegues() {
        let storyboard = UIStoryboard(name: "PuppyStoryboard", bundle: nil)
        let corgiViewController = CorgiViewController()
        try! storyboard.bind(viewController: corgiViewController, toIdentifier: "CorgiViewController")

        let navigationController = storyboard.instantiateInitialViewController() as! UINavigationController
        Fleet.setAsAppWindowRoot(navigationController)

        guard let puppyViewController = navigationController.topViewController as? PuppyListViewController else {
            fail("Failed to properly set up controller for segue detail test")
            return
        }

        puppyViewController.performSegue(withIdentifier: "ShowCorgi", sender: nil)

        expect(puppyViewController.corgiViewControllerImageViewIBOutletValue).to(beNil())
    }
}
