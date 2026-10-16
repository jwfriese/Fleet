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
        return lifetimeScope {
            let controller = BoxTurtleViewController()
            try! storyboard.bind(viewController: controller, toIdentifier: identifier)
            return WeakController(controller)
        }
    }

    /// Attempts a bind that Fleet rejects. The rejected controller is created and dropped inside
    /// its own pool.
    ///
    /// Diagnosis of the CI retention failures (an earlier bound controller still alive after
    /// `removeBindings()`): Fleet's ownership is balanced (bind adds one retain and removal releases
    /// it, checked with `CFGetRetainCount`), and a leaks reverse-reference trace of a failing
    /// fresh-process run showed the remaining holders were the test's own stack and an entry in the
    /// test method's outer autorelease pool. Autorelease dumps showed that entry appearing
    /// between two statements that Fleet and UIKit ran outside any inner pool, so it is
    /// intermittent and depends on the process, not on Fleet's cleanup. A sync test therefore runs
    /// its whole body in one `lifetimeScope` and checks release afterwards.
    private func bindRejectedController(to storyboard: UIStoryboard) throws {
        try autoreleasepool {
            let rejected = BoxTurtleViewController()
            try storyboard.bind(viewController: rejected, toIdentifier: "WatermelonViewController")
        }
    }

    private typealias WeakController = WeakProbe<UIViewController>

    /// Whether the storyboard hands back `controller` for the identifier. Instantiation returns an
    /// autoreleased reference, so the comparison runs in its own scope instead of leaving that
    /// reference alive in the test method's pool, where it would mask a release check.
    private func isBound(_ storyboard: UIStoryboard, to controller: UIViewController?, identifier: String = "BoxTurtleViewController") -> Bool {
        return lifetimeScope { storyboard.instantiateViewController(withIdentifier: identifier) === controller }
    }

    private func isBound(_ storyboard: UIStoryboard, to probe: WeakController?, identifier: String = "BoxTurtleViewController") -> Bool {
        return lifetimeScope {
            guard let controller = probe?.value else { return false }
            return storyboard.instantiateViewController(withIdentifier: identifier) === controller
        }
    }

    func test_boundViewController_isReleasedWithItsStoryboard() {
        var weakController: WeakController!
        autoreleasepool {
            let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
            weakController = bindWeakly(to: storyboard)
            expect(weakController.value).toNot(beNil())
        }
        assertReleased(weakController)
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
        let weakController: WeakController = lifetimeScope {
            let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
            turtlesAndFriendsStoryboard.removeBindings()
            return weakController
        }

        assertReleased(weakController)
        let instantiated = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
        expect(instantiated).toNot(beNil())
    }

    /// Regression for the retention diagnosis (see `bindRejectedController`): Fleet's registration is
    /// gone after `removeBindings()`, and an autorelease pool that received a reference during the
    /// scope keeps the controller alive only until that scope ends. Were Fleet itself to keep an
    /// owner, the controller would survive the scope too and `assertReleased` would fail.
    func test_removeBindings_leavesOnlyScopedAutoreleasedReferencesAsHolders() {
        let probe: WeakController = lifetimeScope {
            let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
            // The swizzled instantiation returns an autoreleased reference that this scope's pool owns.
            _ = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
            turtlesAndFriendsStoryboard.removeBindings()
            // Fleet no longer registers the controller: instantiation yields a fresh one.
            let fresh = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
            expect(fresh).toNot(beIdenticalTo(weakController.value))
            return weakController
        }
        assertReleased(probe, "controller after removeBindings and the scope that received its instantiation result")
    }

    func test_removeBindings_onlyAffectsTheStoryboardItIsCalledOn() {
        // Everything runs inside one scope: references autoreleased between smaller scopes would
        // otherwise land in the test's outer pool and outlive the release check.
        let (ownedWeak, otherIsStillBound) = lifetimeScope { () -> (WeakController, Bool) in
            let other = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
            let ownedWeak = bindWeakly(to: turtlesAndFriendsStoryboard)
            let otherController = BoxTurtleViewController()
            try! other.bind(viewController: otherController, toIdentifier: "BoxTurtleViewController")

            turtlesAndFriendsStoryboard.removeBindings()
            return (ownedWeak, isBound(other, to: otherController))
        }

        assertReleased(ownedWeak)
        expect(otherIsStillBound).to(beTrue())
    }

    func test_sequentialStoryboardsWithTheSameName_doNotSeeEachOthersBindings() {
        let first = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let bound = BoxTurtleViewController()
        try! first.bind(viewController: bound, toIdentifier: "BoxTurtleViewController")

        let second = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        expect(self.isBound(second, to: bound)).to(beFalse())
    }

    func test_withBindings_releasesControllersAfterNormalCompletion() {
        let weakController: WeakController = lifetimeScope {
            turtlesAndFriendsStoryboard.withBindings {
                let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
                expect(weakController.value).toNot(beNil())
                return weakController
            }
        }
        assertReleased(weakController)
    }

    func test_withBindings_releasesControllersWhenBodyThrows() {
        struct Failure: Error {}
        var weakController: WeakController!
        lifetimeScope {
            do {
                try turtlesAndFriendsStoryboard.withBindings {
                    weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
                    throw Failure()
                }
                XCTFail("Expected the body's error to propagate")
            } catch {
                expect(error is Failure).to(beTrue())
            }
        }
        assertReleased(weakController)
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
        assertReleased(weakController!)
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
        assertReleased(weakController)
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
        assertReleased(weakController)

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
        assertReleased(weakController)

        try await Fleet.withContext(window: makeWindow()) { _ in
            let instantiated = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
            expect(instantiated).toNot(beNil())
        }
    }

    func test_context_releasesMocksAndExternalReferenceBindings() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        var weakMock: WeakProbe<BoxTurtleViewController>!
        try await Fleet.withContext(window: makeWindow()) { _ in
            weakMock = try lifetimeScope {
                let mock = try storyboard.mockIdentifier("BoxTurtleViewController", usingMockFor: BoxTurtleViewController.self)
                return WeakProbe(mock)
            }
            expect(weakMock.value).toNot(beNil())
        }
        assertReleased(weakMock)
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
        assertReleased(weakController)
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
        expect(self.isBound(storyboard, to: weakController)).to(beTrue())
        task.cancel()
        await task.value
        assertReleased(weakController!)
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
            expect(self.isBound(storyboard, to: weakReplacement.value)).to(beTrue())
        }
        assertReleased(weakReplacement)
        expect(self.isBound(storyboard, to: original)).to(beTrue())
    }

    func test_context_preservesBindingsOfOtherIdentifiersMadeOutside() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        let outside = AnimalListViewController()
        try storyboard.bind(viewController: outside, toIdentifier: "AnimalListViewController")
        try await Fleet.withContext(window: makeWindow()) { _ in
            _ = self.bindWeakly(to: storyboard)
        }
        expect(self.isBound(storyboard, to: outside, identifier: "AnimalListViewController")).to(beTrue())
    }

    func test_context_isolatesStoryboards() async throws {
        let other = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let otherController = BoxTurtleViewController()
        try other.bind(viewController: otherController, toIdentifier: "BoxTurtleViewController")
        try await Fleet.withContext(window: makeWindow()) { _ in
            _ = self.bindWeakly(to: self.turtlesAndFriendsStoryboard)
        }
        expect(self.isBound(other, to: otherController)).to(beTrue())
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
        assertReleased(weakController)
    }

    func test_workCarryingAnEndedContext_cannotCreateStaleRegistrations() async throws {
        let storyboard = turtlesAndFriendsStoryboard!
        var escaped: Task<Void, Error>?
        // The escaped work waits for an explicit signal sent after the context has ended.
        let (contextEnded, signalContextEnded) = AsyncStream<Void>.makeStream()
        try await Fleet.withContext(window: makeWindow()) { _ in
            escaped = Task { @MainActor in
                for await _ in contextEnded { break }
                try storyboard.bind(viewController: BoxTurtleViewController(), toIdentifier: "BoxTurtleViewController")
            }
        }
        signalContextEnded.yield()
        signalContextEnded.finish()
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
        let (weakController, weakRejected, earlierStillBound): (WeakController, WeakController, Bool) = lifetimeScope {
            let weakController = bindWeakly(to: turtlesAndFriendsStoryboard)
            let rejected = BoxTurtleViewController()
            expect { try self.turtlesAndFriendsStoryboard.bind(viewController: rejected, toIdentifier: "WatermelonViewController") }.to(
                throwStoryboardFailure()
            )
            expect(self.isBound(self.turtlesAndFriendsStoryboard, to: rejected)).to(beFalse())
            // The earlier registration is still owned by the storyboard, and the rejected one left no trace.
            let earlierStillBound = self.isBound(self.turtlesAndFriendsStoryboard, to: weakController)
            return (weakController, WeakProbe(rejected), earlierStillBound)
        }
        assertReleased(weakRejected, "rejected controller")
        expect(earlierStillBound).to(beTrue())

        lifetimeScope { turtlesAndFriendsStoryboard.removeBindings() }
        assertReleased(weakController)
    }

    // MARK: Explicit metadata

    func test_useBindingMetadata_withExplicitNameAndBundle_bindsUsingThatMetadata() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        try! storyboard.useBindingMetadata(forStoryboardNamed: "TurtlesAndFriendsStoryboard", in: Bundle(for: type(of: self)))
        let controller = BoxTurtleViewController()
        try! storyboard.bind(viewController: controller, toIdentifier: "BoxTurtleViewController")
        expect(self.isBound(storyboard, to: controller)).to(beTrue())
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
