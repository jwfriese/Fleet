import XCTest
import Nimble
import Fleet

@testable import FleetExamples

class AlertPageViewControllerSpec: XCTestCase {
    var subject: AlertPageViewController!

    override func setUp() {
        super.setUp()

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        subject = storyboard.instantiateViewController(withIdentifier: "AlertPageViewController") as! AlertPageViewController
        let _ = Fleet.setInAppWindowRootNavigation(subject)
    }

    func test_tappingTheShowAlertButton_showsAnAlert() {
        try! subject.showAlertButton?.tap()

        // Tests asserting that an alert displays look a little different
        // because alerts don't usually come from the storyboard. Here,
        // we'll want to capture the alert and examine its content as part of
        // a good unit test. You have a lot of options available to you.
        // Following are some examples that all thoroughly test the content
        // of the alert.

        expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.title).toEventually(equal("Alert Title"))
        expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message).toEventually(equal("An alert has appeared"))

        // Many won't like the amount of casting that has to happen to finally
        // get to testing the content of the alert itself. This next set of tests
        // hides the fetching of the topmost alert behind a function defined
        // right in the test.

        let alertViewController =  { () -> (UIAlertController?) in
            return Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController
        }

        expect(alertViewController()?.title).toEventually(equal("Alert Title"))
        expect(alertViewController()?.message).toEventually(equal("An alert has appeared"))

        // Finally, you can also just define a function that wraps the casting and
        // content checks all into one predicate.

        let assertAlertContent = { () -> Bool in
            let alert = Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController
            return alert != nil &&
                alert!.title == "Alert Title" &&
                alert!.message == "An alert has appeared"
        }

        expect(assertAlertContent()).toEventually(beTrue())
    }

    func test_afterTheAlertIsShown_tappingTheOKButtonOnTheAlert_dismissesTheAlert() {
        try! subject.showAlertButton?.tap()

        // Normally, testing the behavior of a button on the alert is a pain, because
        // UIKit does not really give you easy access to actions on an alert. Fleet takes
        // that pain away.
        var didTapOK = false
        let assertOKTappedBehavior = { () -> Bool in
            if didTapOK {
                return Fleet.getApplicationScreen()?.topmostViewController === self.subject
            }

            if let alert = Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController {

                // Tapping an alert action with the text 'OK' takes one line once you
                // have the alert in hand.
                try! alert.tapAlertAction(withTitle: "OK")


                didTapOK = true
            }

            return false
        }

        expect(assertOKTappedBehavior()).toEventually(beTrue())
    }
}
