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

    func test_mockIdentifier_whenInvalidIdentifier_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", usingMockFor: UIViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier WatermelonViewController on storyboard with name TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
    }

    func test_mockIdentifier_whenIdentifierExistsOnlyOnStoryboardRef_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("CrabViewController", usingMockFor: CrabViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier CrabViewController on storyboard with name TurtlesAndFriendsStoryboard, but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references", userInfo: nil, closure: nil)
        )
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

    func test_mockIdentifierForReferenceToAnotherStoryboard_whenInvalidIdentifier_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", forReferencedStoryboardWithName: "CrabStoryboard", usingMockFor: CrabViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier WatermelonViewController (external storyboard reference: CrabStoryboard) on storyboard TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
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

    func test_mockInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockInitialViewController(forReferencedStoryboardWithName: "WatermelonStoryboard", usingMockFor: UIViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find reference to an external storyboard with name WatermelonStoryboard on storyboard TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewControllerToIdentifier_whenSameStoryboard_returnsBoundViewController() {
        let mockBoxTurtleViewController = MockBoxTurtleViewController()
        try! turtlesAndFriendsStoryboard.bind(viewController: mockBoxTurtleViewController, toIdentifier: "BoxTurtleViewController")

        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(boxTurtleViewController).to(beIdenticalTo(mockBoxTurtleViewController))
    }

    func test_bindingViewController_whenInvalidIdentifier_raisesException() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier WhateverViewController on storyboard with name TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewController_whenIdentifierExistsOnlyOnStoryboardRef_raisesException() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "CrabViewController") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier CrabViewController on storyboard with name TurtlesAndFriendsStoryboard, but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewController_whenBoundViewControllerHasAlreadyLoadedItsView_raisesException() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "BoxTurtleViewController") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Attempted to bind a view controller whose view has already been loaded to storyboard identifier 'BoxTurtleViewController'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.", userInfo: nil, closure: nil)
        )
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

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenInvalidIdentifier_raisesException() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController", forReferencedStoryboardWithName: "CrabStoryboard") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier WhateverViewController (external storyboard reference: CrabStoryboard) on storyboard TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_raisesException() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Attempted to bind a view controller whose view has already been loaded to view controller identifier 'CrabViewController' on storyboard 'CrabStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.", userInfo: nil, closure: nil)
        )
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

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_raisesException() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, asInitialViewControllerForReferencedStoryboardWithName: "WhateverStoryboard") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find reference to an external storyboard with name WhateverStoryboard on storyboard TurtlesAndFriendsStoryboard", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_raisesException() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, asInitialViewControllerForReferencedStoryboardWithName: "PuppyStoryboard") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Attempted to bind a view controller whose view has already been loaded to initial view controller of storyboard 'PuppyStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.", userInfo: nil, closure: nil)
        )
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
