import XCTest
import Quick
import Nimble
import Fleet

@testable import FleetExamples

class HomeScreenViewControllerSpec: QuickSpec {
    override func spec() {
        describe("HomeScreenViewController") {
            var subject: HomeScreenViewController!

            beforeEach {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

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
            }
        }
    }
}
