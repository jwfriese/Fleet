import XCTest
import Quick
import Nimble
import Fleet

@testable import FleetExamples

class HomeScreenViewControllerQuickSpec: QuickSpec {
    override func spec() {
        describe("HomeScreenViewController") {
            var subject: HomeScreenViewController!
            var mockAlertPageViewController: AlertPageViewController!

            beforeEach {
                // We want to test the behavior of the home page, which comes from a storyboard. First,
                // get the storyboard.
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

                // From the home page we can go to many different pages, all connected by segues. Fleet
                // make it trivial to test those segues. For example, here we use Fleet to mock out
                // the view controller produced anytime UIKit wants to instantiate a view controller with
                // the storyboard identifier "AlertPageViewController".
                mockAlertPageViewController = try! storyboard.mockIdentifier("AlertPageViewController", usingMockFor: AlertPageViewController.self)

                subject = storyboard.instantiateViewController(withIdentifier: "HomeScreenViewController") as! HomeScreenViewController
            }

            describe("After the view has loaded") {
                var navigationController: UINavigationController!

                beforeEach {
                    // This is how you kick off the lifecycle of your view controller under test.
                    // For more on why Fleet recommends you test view controllers in a window,
                    // read the 'Why should I make sure all UIViewController unit tests happen in a
                    // UIWindow?' FAQ section.

                    // This version sets up the 'subject' in a UINavigationController.
                    // You could also use `Fleet.setAsAppWindowRoot(_:)` to set the 'subject'
                    // directly as the root of a window.
                    navigationController = Fleet.setInAppWindowRootNavigation(subject)
                }

                it("will have updated its text label once its view finishes loading") {
                    expect(subject.loadingStatusLabel?.text).to(equal("Finished loading!"))
                }

                describe("Tapping the 'Go to Alert Page' button") {
                    beforeEach {
                        // When you want to test what a button on the screen does, just "tap" it.
                        // This is where the real power of Fleet comes in -- tapping this button
                        // fires a segue to present a new page...
                        try! subject.goToAlertPageButton?.tap()
                    }

                    // ... and now we want to see the result. Recall above how we mocked out the "AlertPageViewController"
                    // identifier. It's time to use that mock.
                    it("presents the alerts page to the user") {
                        // Verifying that your segue successfully presented the right controller is done in one line.
                        expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockAlertPageViewController))

                        // The following assertion is functionally equivalent to the above.
                        expect(navigationController.topViewController).toEventually(beIdenticalTo(mockAlertPageViewController))
                    }
                }
            }
        }
    }
}
