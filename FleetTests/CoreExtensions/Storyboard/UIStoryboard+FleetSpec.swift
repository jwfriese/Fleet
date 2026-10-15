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

    func test_mockIdentifier_whenInvalidIdentifier_throwsFailure() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", usingMockFor: UIViewController.self) }.to(
            throwStoryboardFailure(state: "Could not find identifier 'WatermelonViewController' on storyboard with name 'TurtlesAndFriendsStoryboard'")
        )
    }

    func test_mockIdentifier_whenIdentifierExistsOnlyOnStoryboardRef_throwsFailure() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("CrabViewController", usingMockFor: CrabViewController.self) }.to(
            throwStoryboardFailure(state: "Could not find identifier 'CrabViewController' on storyboard with name 'TurtlesAndFriendsStoryboard', but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references")
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

    func test_mockIdentifierForReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsFailure() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockIdentifier("WatermelonViewController", forReferencedStoryboardWithName: "CrabStoryboard", usingMockFor: CrabViewController.self) }.to(
            throwStoryboardFailure(state: "Could not find identifier 'WatermelonViewController' (external storyboard reference: 'CrabStoryboard') on storyboard 'TurtlesAndFriendsStoryboard'")
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

    func test_mockInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsFailure() {
        expect { _ = try self.turtlesAndFriendsStoryboard.mockInitialViewController(forReferencedStoryboardWithName: "WatermelonStoryboard", usingMockFor: UIViewController.self) }.to(
            throwStoryboardFailure(state: "Could not find reference to an external storyboard with name 'WatermelonStoryboard' on storyboard 'TurtlesAndFriendsStoryboard'")
        )
    }

    func test_bindingViewControllerToIdentifier_whenSameStoryboard_returnsBoundViewController() {
        let mockBoxTurtleViewController = MockBoxTurtleViewController()
        try! turtlesAndFriendsStoryboard.bind(viewController: mockBoxTurtleViewController, toIdentifier: "BoxTurtleViewController")

        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(boxTurtleViewController).to(beIdenticalTo(mockBoxTurtleViewController))
    }

    func test_bindingViewController_whenInvalidIdentifier_throwsFailure() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController") }.to(
            throwStoryboardFailure(state: "Could not find identifier 'WhateverViewController' on storyboard with name 'TurtlesAndFriendsStoryboard'")
        )
    }

    func test_bindingViewController_whenIdentifierExistsOnlyOnStoryboardRef_throwsFailure() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "CrabViewController") }.to(
            throwStoryboardFailure(state: "Could not find identifier 'CrabViewController' on storyboard with name 'TurtlesAndFriendsStoryboard', but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references")
        )
    }

    func test_bindingViewController_whenBoundViewControllerHasAlreadyLoadedItsView_throwsFailure() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "BoxTurtleViewController") }.to(
            throwStoryboardFailure(state: "Attempted to bind a view controller whose view has already been loaded to storyboard identifier 'BoxTurtleViewController'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.")
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

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsFailure() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, toIdentifier: "WhateverViewController", forReferencedStoryboardWithName: "CrabStoryboard") }.to(
            throwStoryboardFailure(state: "Could not find identifier 'WhateverViewController' (external storyboard reference: 'CrabStoryboard') on storyboard 'TurtlesAndFriendsStoryboard'")
        )
    }

    func test_bindingViewControllerToIdentifierReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_throwsFailure() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, toIdentifier: "CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard") }.to(
            throwStoryboardFailure(state: "Attempted to bind a view controller whose view has already been loaded to view controller identifier 'CrabViewController' on storyboard 'CrabStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.")
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

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenInvalidIdentifier_throwsFailure() {
        let whateverViewController = UIViewController()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: whateverViewController, asInitialViewControllerForReferencedStoryboardWithName: "WhateverStoryboard") }.to(
            throwStoryboardFailure(state: "Could not find reference to an external storyboard with name 'WhateverStoryboard' on storyboard 'TurtlesAndFriendsStoryboard'")
        )
    }

    func test_bindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard_whenBoundViewControllerHasAlreadyLoadedItsView_throwsFailure() {
        let preloadedViewController = MockBoxTurtleViewController()
        preloadedViewController.viewDidLoad()
        expect { try self.turtlesAndFriendsStoryboard.bind(viewController: preloadedViewController, asInitialViewControllerForReferencedStoryboardWithName: "PuppyStoryboard") }.to(
            throwStoryboardFailure(state: "Attempted to bind a view controller whose view has already been loaded to initial view controller of storyboard 'PuppyStoryboard'. Fleet throws an error when this occurs because UIKit does not load the view of a segue destination view controller before calling 'prepareForSegue:', and so binding a preloaded view controller invalidates the environment of the test code.")
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
        // Drain autoreleased temporaries so only real owners keep the controller alive.
        return autoreleasepool {
            let controller = BoxTurtleViewController()
            try! storyboard.bind(viewController: controller, toIdentifier: identifier)
            return WeakController(controller)
        }
    }

    /// Attempts a bind that Fleet rejects. The rejected controller is created and dropped inside
    /// its own pool. Passing `BoxTurtleViewController()` inline to the throwing call made the earlier
    /// bound instance outlive the context when this test ran alone (reproduced locally, and in CI),
    /// although Fleet had already removed the registration; the exact holder was not identified, but
    /// the outcome depends on how the temporary is scoped, not on Fleet's cleanup.
    private func bindRejectedController(to storyboard: UIStoryboard) throws {
        try autoreleasepool {
            let rejected = BoxTurtleViewController()
            try storyboard.bind(viewController: rejected, toIdentifier: "WatermelonViewController")
        }
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

    func test_withBindings_releasesControllersWhenAFleetBindingFails() {
        var weakController: WeakController!
        autoreleasepool {
            do {
                try turtlesAndFriendsStoryboard.withBindings {
                    weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
                    try bindRejectedController(to: turtlesAndFriendsStoryboard)
                }
                XCTFail("Expected the failing bind to throw")
            } catch {
                expect(error is FleetFailure).to(beTrue())
            }
        }
        expect(weakController.value).to(beNil())
        expect(self.turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beNil())
    }

    func test_contextCleanup_releasesControllersAcrossSuccessiveContexts() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        var weakController: WeakController!
        try await Fleet.withContext(window: window) { context in
            try context.addCleanup { storyboard.removeBindings() }
            weakController = self.bindWeakly(to: storyboard)
            expect(weakController.value).toNot(beNil())
        }
        expect(weakController.value).to(beNil())

        try await Fleet.withContext(window: window) { _ in
            expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beNil())
        }
    }

    // MARK: Automatic context ownership

    private func makeWindow() -> UIWindow { UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480)) }

    func test_context_releasesBindingsOnRetainedStoryboardWithoutManualCleanup() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        var weakController: WeakController!
        try await Fleet.withContext(window: makeWindow()) { _ in
            weakController = self.bindWeakly(to: storyboard)
            expect(weakController.value).toNot(beNil())
        }
        expect(weakController.value).to(beNil())

        try await Fleet.withContext(window: makeWindow()) { _ in
            let instantiated = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
            expect(instantiated).toNot(beNil())
        }
    }

    func test_context_releasesMocksAndExternalReferenceBindings() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        weak var weakMock: BoxTurtleViewController?
        try await Fleet.withContext(window: makeWindow()) { _ in
            weakMock = try storyboard.mockIdentifier("BoxTurtleViewController", usingMockFor: BoxTurtleViewController.self)
            expect(weakMock).toNot(beNil())
        }
        expect(weakMock).to(beNil())
    }

    func test_context_releasesBindingsWhenBodyThrowsAfterFailedBind() async {
        let storyboard = turtlesAndFriendsStoryboard!
        var weakController: WeakController!
        do {
            try await Fleet.withContext(window: makeWindow()) { _ in
                weakController = self.bindWeakly(to: storyboard)
                try self.bindRejectedController(to: storyboard)
            }
            XCTFail("Expected the failing bind to throw")
        } catch {
            expect(error is FleetFailure).to(beTrue())
        }
        expect(weakController.value).to(beNil())
    }

    func test_context_releasesBindingsWhenCancelled() async {
        let storyboard = turtlesAndFriendsStoryboard!
        let window = makeWindow()
        var weakController: WeakController?
        var sawCancellation = false
        let task = Task { @MainActor in
            do {
                try await Fleet.withContext(window: window) { _ in
                    weakController = self.bindWeakly(to: storyboard)
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                }
            } catch is CancellationError {
                sawCancellation = true
            } catch {}
        }
        let deadline = Date().addingTimeInterval(10)
        while weakController == nil, Date() < deadline {
            await Task.yield()
        }
        XCTAssertNotNil(weakController, "The context body never registered a binding")
        expect(weakController?.value).toNot(beNil())
        expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(weakController?.value))
        task.cancel()
        await task.value
        expect(weakController?.value).to(beNil())
        expect(sawCancellation).to(beTrue())
        expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beNil())
    }

    func test_context_restoresAnOutsideBindingItOverrode() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        let original = BoxTurtleViewController()
        try storyboard.bind(viewController: original, toIdentifier: "BoxTurtleViewController")
        var weakReplacement: WeakController!
        try await Fleet.withContext(window: makeWindow()) { _ in
            weakReplacement = self.bindWeakly(to: storyboard)
            expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(weakReplacement.value))
        }
        expect(weakReplacement.value).to(beNil())
        expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(original))
    }

    func test_context_preservesBindingsOfOtherIdentifiersMadeOutside() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        let outside = AnimalListViewController()
        try storyboard.bind(viewController: outside, toIdentifier: "AnimalListViewController")
        try await Fleet.withContext(window: makeWindow()) { _ in
            _ = self.bindWeakly(to: storyboard)
        }
        expect(storyboard.instantiateViewController(withIdentifier: "AnimalListViewController")).to(beIdenticalTo(outside))
    }

    func test_context_isolatesStoryboards() async throws {
        let other = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let otherController = BoxTurtleViewController()
        try other.bind(viewController: otherController, toIdentifier: "BoxTurtleViewController")
        try await Fleet.withContext(window: makeWindow()) { _ in
            _ = self.bindWeakly(to: self.turtlesAndFriendsStoryboard)
        }
        expect(other.instantiateViewController(withIdentifier: "BoxTurtleViewController")).to(beIdenticalTo(otherController))
    }

    func test_context_doesNotOwnBindingsFromDetachedWork() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        var weakController: WeakController!
        try await Fleet.withContext(window: makeWindow()) { _ in
            let detached = Task.detached { @MainActor in self.bindWeakly(to: storyboard) }
            weakController = await detached.value
        }
        expect(weakController.value).toNot(beNil())
        storyboard.removeBindings()
        expect(weakController.value).to(beNil())
    }

    func test_workCarryingAnEndedContext_cannotCreateStaleRegistrations() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        var escaped: Task<Void, Error>?
        try await Fleet.withContext(window: makeWindow()) { _ in
            escaped = Task { @MainActor in
                try await Task.sleep(nanoseconds: 200_000_000)
                try storyboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController")
            }
        }
        do {
            try await escaped?.value
            XCTFail("Expected the ended context to reject the registration")
        } catch {
            expect(error is FleetFailure).to(beTrue())
        }
        try await Fleet.withContext(window: makeWindow()) { _ in
            expect(storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beNil())
        }
    }

    func test_failedBinding_recordsNothingAndLeavesEarlierBindingsOwnedByTheStoryboard() {
        let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
        weak var weakRejected: BoxTurtleViewController?
        do {
            let rejected = BoxTurtleViewController()
            weakRejected = rejected
            expect { try self.turtlesAndFriendsStoryboard.bind(viewController: rejected, toIdentifier: "WatermelonViewController") }.to(
                throwStoryboardFailure()
            )
            expect(self.turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")).toNot(beIdenticalTo(rejected))
        }
        expect(weakRejected).to(beNil())

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

    func test_useBindingMetadata_withBundleLackingMetadata_throwsActionableFailure() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        try! storyboard.useBindingMetadata(forStoryboardNamed: "TurtlesAndFriendsStoryboard", in: Bundle(for: UIView.self))
        expect { try storyboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController") }.to(
            throwStoryboardFailure()
        )
    }

    func test_useBindingMetadata_afterBindingWithDifferentIdentity_throwsFailure() {
        try! turtlesAndFriendsStoryboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController")
        expect { try self.turtlesAndFriendsStoryboard.useBindingMetadata(forStoryboardNamed: "Other", in: nil) }.to(
            throwStoryboardFailure()
        )
    }
}
