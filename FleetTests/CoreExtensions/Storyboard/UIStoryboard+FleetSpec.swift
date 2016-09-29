import XCTest
import Fleet
import Nimble
@testable import FleetTestApp

class UIStoryboard_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!

    class MockBoxTurtleViewController: BoxTurtleViewController { }
    class MockCrabViewController: CrabViewController { }
    class MockPuppyListViewController: PuppyListViewController { }

    override func setUp() {
        super.setUp()

        turtlesAndFriendsStoryboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
    }

    func test_bindingViewControllerToIdentifier_whenSameStoryboard_returnsBoundViewController() {
        let mockBoxTurtleViewController = MockBoxTurtleViewController()
        try! turtlesAndFriendsStoryboard.bind(viewController: mockBoxTurtleViewController, toIdentifier: "BoxTurtleViewController")

        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(boxTurtleViewController).to(beIdenticalTo(mockBoxTurtleViewController))
    }

    func test_bindingViewController_whenInvalidIdentifier_throwsError() {
        var threwError = false
        let whateverViewController = UIViewController()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController")
        } catch FLTStoryboardBindingError.invalidViewControllerIdentifier(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier WhateverViewController on storyboard with name TurtlesAndFriendsStoryboard"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerIdentifier error")
        }
    }

    func test_bindingViewController_whenIdentifierExistsOnlyOnStoryboardRef_throwsError() {
        var threwError = false
        let whateverViewController = UIViewController()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "CrabViewController")
        } catch FLTStoryboardBindingError.invalidViewControllerIdentifier(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier CrabViewController on storyboard with name TurtlesAndFriendsStoryboard, but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerIdentifier error")
        }
    }

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard() {
        let mockCrabViewController = MockCrabViewController()
        try! turtlesAndFriendsStoryboard.bind(viewController: mockCrabViewController, toIdentifier: "CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard")

        let testNavigationController = UINavigationController()

        let animalListViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "AnimalListViewController") as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)

        animalListViewController?.goToCrab()

        expect(testNavigationController.topViewController).to(beIdenticalTo(mockCrabViewController))
    }

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsError() {
        var threwError = false
        let whateverViewController = UIViewController()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController", forReferencedStoryboardWithName: "CrabStoryboard")
        } catch FLTStoryboardBindingError.invalidExternalStoryboardReference(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier WhateverViewController (external storyboard reference: CrabStoryboard) on storyboard TurtlesAndFriendsStoryboard"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
    }

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard() {
        let mockPuppyListViewController = MockPuppyListViewController()

        try! turtlesAndFriendsStoryboard.bind(viewController: mockPuppyListViewController, asInitialViewControllerForReferencedStoryboardWithName: "PuppyStoryboard")

        let testNavigationController = UINavigationController()

        let animalListViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "AnimalListViewController") as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)

        animalListViewController?.goToPuppy()

        expect(testNavigationController.topViewController).to(beIdenticalTo(mockPuppyListViewController))
    }

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsError() {
        var pass = false
        let whateverViewController = UIViewController()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, asInitialViewControllerForReferencedStoryboardWithName: "WhateverStoryboard")
        } catch FLTStoryboardBindingError.invalidExternalStoryboardReference {
            pass = true
        } catch { }

        if !pass {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
    }

    func test_multipleStoryboardSupport() {
        let turtleStoryboardTwo = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)

        let mockBoxTurtleViewControllerBlue = MockBoxTurtleViewController()
        try! turtlesAndFriendsStoryboard.bind(viewController: mockBoxTurtleViewControllerBlue, toIdentifier: "BoxTurtleViewController")

        let mockBoxTurtleViewControllerGreen = MockBoxTurtleViewController()
        try! turtleStoryboardTwo.bind(viewController: mockBoxTurtleViewControllerGreen, toIdentifier: "BoxTurtleViewController")

        let blueBoxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(blueBoxTurtleViewController).to(beIdenticalTo(mockBoxTurtleViewControllerBlue))

        let greenBoxTurtleViewController = turtleStoryboardTwo.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(greenBoxTurtleViewController).to(beIdenticalTo(mockBoxTurtleViewControllerGreen))
    }
}
