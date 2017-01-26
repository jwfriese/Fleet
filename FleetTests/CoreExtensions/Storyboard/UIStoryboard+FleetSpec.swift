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

    func test_mockIdentifier_whenTheIdentifierExistsOnTheStoryboard_returnsMockViewController() {
        let mockViewController = try! turtlesAndFriendsStoryboard.mockIdentifier("BoxTurtleViewController", usingMockFor: BoxTurtleViewController.self)
        expect(mockViewController).to(beAKindOf(BoxTurtleViewController.self))

        let storyboardViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(storyboardViewController).to(beIdenticalTo(mockViewController))
    }

    func test_mockIdentifier_whenInvalidIdentifier_throwsError() {
        var threwError = false
        do {
            let _ = try turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", usingMockFor: UIViewController.self)
        } catch Fleet.StoryboardError.invalidViewControllerIdentifier(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier WatermelonViewController on storyboard with name TurtlesAndFriendsStoryboard"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerIdentifier error")
        }
    }

    func test_mockIdentifier_whenIdentifierExistsOnlyOnStoryboardRef_returnsError() {
        var threwError = false
        do {
            let _ = try turtlesAndFriendsStoryboard.mockIdentifier("CrabViewController", usingMockFor: CrabViewController.self)
        } catch Fleet.StoryboardError.invalidViewControllerIdentifier(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier CrabViewController on storyboard with name TurtlesAndFriendsStoryboard, but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerIdentifier error")
        }
    }

    func test_mockIdentifierForReferenceToAnotherStoryboard() {
        let mockViewController = try! turtlesAndFriendsStoryboard.mockIdentifier("CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard", usingMockFor: CrabViewController.self)
        expect(mockViewController).to(beAKindOf(CrabViewController.self))

        let testNavigationController = UINavigationController()

        let animalListViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "AnimalListViewController") as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)

        animalListViewController?.goToCrab()

        expect(testNavigationController.topViewController).to(beIdenticalTo(mockViewController))
    }

    func test_mockIdentifierForReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsError() {
        var threwError = false
        do {
            let _ = try turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", forReferencedStoryboardWithName: "CrabStoryboard", usingMockFor: CrabViewController.self)
        } catch Fleet.StoryboardError.invalidExternalStoryboardReference(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier WatermelonViewController (external storyboard reference: CrabStoryboard) on storyboard TurtlesAndFriendsStoryboard"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
    }

    func test_mockInitialViewControllerOfReferenceToAnotherStoryboard() {
        let mockInitialViewController = try! turtlesAndFriendsStoryboard.mockInitialViewController(forReferencedStoryboardWithName: "PuppyStoryboard", usingMockFor: PuppyListViewController.self)
        expect(mockInitialViewController).to(beAKindOf(PuppyListViewController.self))

        let testNavigationController = UINavigationController()

        let animalListViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "AnimalListViewController") as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)

        animalListViewController?.goToPuppy()

        expect(testNavigationController.topViewController).to(beIdenticalTo(mockInitialViewController))
    }

    func test_mockInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsError() {
        var threwError = false
        do {
            let _ = try turtlesAndFriendsStoryboard.mockInitialViewController(forReferencedStoryboardWithName: "WatermelonStoryboard", usingMockFor: UIViewController.self)
        } catch Fleet.StoryboardError.invalidExternalStoryboardReference(let message) {
            threwError = true
            expect(message).to(equal("Could not find reference to an external storyboard with name WatermelonStoryboard on storyboard TurtlesAndFriendsStoryboard"))
        }catch { }

        if !threwError {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
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
        } catch Fleet.StoryboardError.invalidViewControllerIdentifier(let message) {
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
        } catch Fleet.StoryboardError.invalidViewControllerIdentifier(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier CrabViewController on storyboard with name TurtlesAndFriendsStoryboard, but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerIdentifier error")
        }
    }

    func test_bindingViewController_whenBoundViewControllerHasAlreadyLoadedItsView_throwsError() {
        var threwError = false
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "BoxTurtleViewController")
        } catch Fleet.StoryboardError.invalidViewControllerState(let message) {
            threwError = true
            expect(message).to(equal("Attempted to bind a view controller whose view has already been loaded to storyboard identifier 'BoxTurtleViewController'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerState error")
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
        } catch Fleet.StoryboardError.invalidExternalStoryboardReference(let message) {
            threwError = true
            expect(message).to(equal("Could not find identifier WhateverViewController (external storyboard reference: CrabStoryboard) on storyboard TurtlesAndFriendsStoryboard"))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
    }

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_throwsError() {
        var threwError = false
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard")
        } catch Fleet.StoryboardError.invalidViewControllerState(let message) {
            threwError = true
            expect(message).to(equal("Attempted to bind a view controller whose view has already been loaded to view controller identifier 'CrabViewController' on storyboard 'CrabStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerState error")
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
        } catch Fleet.StoryboardError.invalidExternalStoryboardReference {
            pass = true
        } catch { }

        if !pass {
            fail("Expected to throw InvalidExternalStoryboardReference error")
        }
    }

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_throwsError() {
        var threwError = false
        let preloadedViewController = UIViewController()
        preloadedViewController.viewDidLoad()
        do {
            try turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, asInitialViewControllerForReferencedStoryboardWithName: "PuppyStoryboard")
        } catch Fleet.StoryboardError.invalidViewControllerState(let message) {
            threwError = true
            expect(message).to(equal("Attempted to bind a view controller whose view has already been loaded to initial view controller of storyboard 'PuppyStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code."))
        } catch { }

        if !threwError {
            fail("Expected to throw InvalidViewControllerState error")
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
