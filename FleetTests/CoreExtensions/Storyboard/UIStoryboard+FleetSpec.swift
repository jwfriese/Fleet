import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
class UIStoryboard_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!

    class MockBoxTurtleViewController: BoxTurtleViewController { }
    class MockCrabViewController: CrabViewController { }
    class MockPuppyListViewController: PuppyListViewController { }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        turtlesAndFriendsStoryboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
    }

    func test_mockIdentifier_whenTheIdentifierExistsOnTheStoryboard_returnsMockViewController() {
        let mockViewController = try! turtlesAndFriendsStoryboard.mockIdentifier("BoxTurtleViewController", usingMockFor: BoxTurtleViewController.self)
        expect(mockViewController).to(beAKindOf(BoxTurtleViewController.self))

        let storyboardViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(storyboardViewController).to(beIdenticalTo(mockViewController))
    }

    func test_mockIdentifier_tabBarController_whenTheIdentifierExistsOnTheStoryboard_returnsMockViewController() {
        let mockTabBarController = try! turtlesAndFriendsStoryboard.mockIdentifier("HomeTabBar", usingMockFor: HomeTabBarController.self)
        expect(mockTabBarController).to(beAKindOf(HomeTabBarController.self))

        let storyboardViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "HomeTabBar")
        expect(storyboardViewController).to(beIdenticalTo(mockTabBarController))
    }

    func test_mockIdentifier_whenInvalidIdentifier_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", usingMockFor: UIViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'WatermelonViewController' on storyboard with name 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
        )
    }

    func test_mockIdentifier_whenIdentifierExistsOnlyOnStoryboardRef_raisesException() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("CrabViewController", usingMockFor: CrabViewController.self) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'CrabViewController' on storyboard with name 'TurtlesAndFriendsStoryboard', but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references", userInfo: nil, closure: nil)
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
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'WatermelonViewController' (external storyboard reference: 'CrabStoryboard') on storyboard 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
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
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find reference to an external storyboard with name 'WatermelonStoryboard' on storyboard 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
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
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'WhateverViewController' on storyboard with name 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
        )
    }

    func test_bindingViewController_whenIdentifierExistsOnlyOnStoryboardRef_raisesException() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "CrabViewController") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'CrabViewController' on storyboard with name 'TurtlesAndFriendsStoryboard', but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references", userInfo: nil, closure: nil)
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
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find identifier 'WhateverViewController' (external storyboard reference: 'CrabStoryboard') on storyboard 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
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
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find reference to an external storyboard with name 'WhateverStoryboard' on storyboard 'TurtlesAndFriendsStoryboard'", userInfo: nil, closure: nil)
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

    // MARK: Binding lifetime

    private func bindWeakly(to storyboard: UIStoryboard, identifier: String = "BoxTurtleViewController") -> WeakController {
        let controller = BoxTurtleViewController()
        try! storyboard.bind(viewController: controller, toIdentifier: identifier)
        return WeakController(controller)
    }

    private struct WeakController {
        weak var value: UIViewController?
        init(_ value: UIViewController) { self.value = value }
    }

    func test_boundViewController_isReleasedWithItsStoryboard() {
        var weakController: WeakController!
        autoreleasepool {
            let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
            weakController = bindWeakly(to: storyboard)
            expect(weakController.value).toNot(beNil())
        }
        expect(weakController.value).to(beNil())
    }

    func test_boundMock_isReleasedWithItsStoryboard() {
        weak var weakMock: BoxTurtleViewController?
        autoreleasepool {
            let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
            weakMock = try! storyboard.mockIdentifier("BoxTurtleViewController", usingMockFor: BoxTurtleViewController.self)
            expect(weakMock).toNot(beNil())
        }
        expect(weakMock).to(beNil())
    }

    func test_removeBindings_releasesControllersAndRestoresStoryboardInstantiation() {
        let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
        turtlesAndFriendsStoryboard.removeBindings()

        expect(weakController.value).to(beNil())
        let instantiated = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(instantiated).toNot(beNil())
    }

    func test_removeBindings_onlyAffectsTheStoryboardItIsCalledOn() {
        let other = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let ownedWeak = bindWeakly(to: turtlesAndFriendsStoryboard)
        let otherController = BoxTurtleViewController()
        try! other.bind(viewController: otherController, toIdentifier: "BoxTurtleViewController")

        turtlesAndFriendsStoryboard.removeBindings()

        expect(ownedWeak.value).to(beNil())
        expect(other.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(otherController))
    }

    func test_sequentialStoryboardsWithTheSameName_doNotSeeEachOthersBindings() {
        let first = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let bound = BoxTurtleViewController()
        try! first.bind(viewController: bound, toIdentifier: "BoxTurtleViewController")

        let second = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        expect(second.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beIdenticalTo(bound))
    }

    func test_withBindings_releasesControllersAfterNormalCompletion() {
        var weakController: WeakController!
        turtlesAndFriendsStoryboard.withBindings {
            weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
            expect(weakController.value).toNot(beNil())
        }
        expect(weakController.value).to(beNil())
    }

    func test_withBindings_releasesControllersWhenBodyThrows() {
        struct Failure: Error {}
        var weakController: WeakController!
        do {
            try turtlesAndFriendsStoryboard.withBindings {
                weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
                throw Failure()
            }
            XCTFail("Expected the body's error to propagate")
        } catch {
            expect(error is Failure).to(beTrue())
        }
        expect(weakController.value).to(beNil())
    }

    func test_withBindings_releasesControllersWhenAsyncBodyIsCancelled() async {
        let storyboard = turtlesAndFriendsStoryboard!
        var weakController: WeakController?
        var sawCancellation = false
        let task = Task { @MainActor in
            do {
                try await storyboard.withBindings {
                    weakController = self.bindWeakly(to: storyboard)
                    // The task is cancelled before it first runs, so this throws immediately.
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                }
            } catch is CancellationError {
                sawCancellation = true
            } catch {}
        }
        task.cancel()
        await task.value

        expect(sawCancellation).to(beTrue())
        expect(weakController).toNot(beNil())
        expect(weakController?.value).to(beNil())
    }

    func test_failedBinding_recordsNothingAndLeavesEarlierBindingsOwnedByTheStoryboard() {
        // An Objective-C exception unwinding through Swift frames does not release the references
        // they held, so the rejected controller itself is not asserted on here; the storyboard's own
        // registrations are.
        let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
        let rejected = BoxTurtleViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: rejected, toIdentifier: "WatermelonViewController") }.to(
            raiseException(named: "Fleet.StoryboardError")
        )
        expect(self.turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beIdenticalTo(rejected))

        turtlesAndFriendsStoryboard.removeBindings()
        expect(weakController.value).to(beNil())
    }

    // MARK: Explicit metadata

    func test_useBindingMetadata_withExplicitNameAndBundle_bindsUsingThatMetadata() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        try! storyboard.useBindingMetadata(forStoryboardNamed: "TurtlesAndFriendsStoryboard", in: Bundle(for: type(of: self)))
        let controller = BoxTurtleViewController()
        try! storyboard.bind(viewController: controller, toIdentifier: "BoxTurtleViewController")
        expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(controller))
    }

    func test_useBindingMetadata_withBundleLackingMetadata_raisesActionableException() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        try! storyboard.useBindingMetadata(forStoryboardNamed: "TurtlesAndFriendsStoryboard", in: Bundle(for: UIView.self))
        expect { try storyboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController") }.to(
            raiseException(named: "Fleet.StoryboardError")
        )
    }

    func test_useBindingMetadata_afterBindingWithDifferentIdentity_raisesException() {
        try! turtlesAndFriendsStoryboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController")
        expect { try self.turtlesAndFriendsStoryboard.useBindingMetadata(forStoryboardNamed: "Other", in: nil) }.to(
            raiseException(named: "Fleet.StoryboardError")
        )
    }
}
