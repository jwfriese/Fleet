import XCTest
import Fleet
import Nimble

@MainActor
class UINavigationController_FleetSpec: XCTestCase {
    fileprivate class TestViewController: UIViewController {
        var testViewDidLoadCallCount: UInt = 0
        var capturedNavigationController: UINavigationController?

        fileprivate override func viewDidLoad() {
            super.viewDidLoad()
            testViewDidLoadCallCount += 1
            capturedNavigationController = navigationController
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func test_pushViewController_immediatelySetsTheViewControllerAsTheTopController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = UIViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(controllerToPush))
    }

    func test_pushViewController_immediatelyLoadsThePushedViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)
        expect(controllerToPush.testViewDidLoadCallCount).to(equal(1))
    }

    func test_pushViewController_doesNotCausePushedViewControllerToLoadMultipleTimes() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(controllerToPush.testViewDidLoadCallCount).toEventuallyNot(beGreaterThan(1))
    }

    func test_pushViewController_doesNotLoadThePushedViewControllerUntilItWouldHaveANavigationController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(controllerToPush.capturedNavigationController).toEventuallyNot(beNil())
    }

    func test_popViewController_returnsPoppedViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPushThenPop = UIViewController()

        navigationController.pushViewController(controllerToPushThenPop, animated: true)
        let poppedViewController = navigationController.popViewController(animated: true)

        expect(poppedViewController).to(beIdenticalTo(controllerToPushThenPop))
    }

    func test_popViewController_immediatelySetsTheNextViewControllerInStackAsTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPushThenPop = UIViewController()

        navigationController.pushViewController(controllerToPushThenPop, animated: true)
        navigationController.popViewController(animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popToViewController_immediatelySetsTheGivenViewControllerAsTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        navigationController.popToViewController(controllerOne, animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(controllerOne))
    }

    func test_popToViewController_whenTheNavigationControllerIsInVisibleWindow_returnsThePoppedViewControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        let poppedControllers = navigationController.popToViewController(controllerOne, animated: true)

        if poppedControllers != nil {
            expect(poppedControllers!.count).to(equal(2))
            expect(poppedControllers![0]).to(beIdenticalTo(controllerTwo))
            expect(poppedControllers![1]).to(beIdenticalTo(controllerThree))
        } else {
            fail("Expected popToViewController(_:animated:) to return popped view controllers")
        }
    }

    func test_popToViewController_whenTheNavigationControllerNotInVisibleWindow_returnsPoppedControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        let poppedControllers = navigationController.popToViewController(controllerOne, animated: true)

        // Current UIKit returns the removed controllers even for an offscreen stack.
        expect(poppedControllers?.count).to(equal(2))
        expect(poppedControllers?[0]).to(beIdenticalTo(controllerTwo))
        expect(poppedControllers?[1]).to(beIdenticalTo(controllerThree))
        expect(navigationController.topViewController).to(beIdenticalTo(controllerOne))
    }

    func test_popToRootViewController_immediatelySetsTheRootViewControllerAsTheTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: true)
        navigationController.pushViewController(controllerTwo, animated: true)

        navigationController.popToRootViewController(animated: false)

        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popToRootViewController_whenTheNavigationControllerIsInVisibleWindow_returnsThePoppedViewControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)

        let poppedControllers = navigationController.popToRootViewController(animated: true)

        if poppedControllers != nil {
            expect(poppedControllers!.count).to(equal(2))
            expect(poppedControllers![0]).to(beIdenticalTo(controllerOne))
            expect(poppedControllers![1]).to(beIdenticalTo(controllerTwo))
        } else {
            fail("Expected popToRootViewControllerAnimated(_:) to return popped view controllers")
        }
    }

    func test_popToRootViewController_whenTheNavigationControllerIsNotInVisibleWindow_returnsPoppedControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)

        let poppedControllers = navigationController.popToRootViewController(animated: true)

        expect(poppedControllers?.count).to(equal(2))
        expect(poppedControllers?[0]).to(beIdenticalTo(controllerOne))
        expect(poppedControllers?[1]).to(beIdenticalTo(controllerTwo))
        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    fileprivate class RecordingDelegate: NSObject, UINavigationControllerDelegate {
        var events: [String] = []
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            events.append("willShow")
        }
        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            events.append("didShow")
        }
    }

    func test_pushViewController_notifiesDelegateInOrder() {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.pushViewController(UIViewController(), animated: true)

        // UIKit delivers these callbacks after the call returns for a non-animated transition in
        // the hosted test window, so wait for them rather than asserting immediately.
        expect(delegate.events).toEventually(equal(["willShow", "didShow"]))
    }

    func test_popViewController_notifiesDelegateInOrder() {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        navigationController.pushViewController(UIViewController(), animated: false)
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.popViewController(animated: true)

        // UIKit delivers these callbacks after the call returns for a non-animated transition in
        // the hosted test window, so wait for them rather than asserting immediately.
        expect(delegate.events).toEventually(equal(["willShow", "didShow"]))
    }

    func test_popViewController_whenOnlyRootIsInStack_returnsNilAndPreservesRoot() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popViewController(animated: false)

        expect(popped).to(beNil())
        expect(navigationController.viewControllers).to(equal([root]))
        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popViewController_whenStackIsEmpty_returnsNil() {
        let navigationController = UINavigationController()

        let popped = navigationController.popViewController(animated: false)

        expect(popped).to(beNil())
        expect(navigationController.viewControllers).to(beEmpty())
    }

    func test_popToRootViewController_whenOnlyRootIsInStack_returnsNoControllersAndPreservesRoot() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popToRootViewController(animated: false)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(equal([root]))
    }

    func test_popToRootViewController_whenStackIsEmpty_returnsNoControllers() {
        let navigationController = UINavigationController()

        let popped = navigationController.popToRootViewController(animated: false)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(beEmpty())
    }

    func test_popToViewController_whenAlreadyTop_returnsNoControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popToViewController(root, animated: true)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(equal([root]))
    }

    func test_pushViewController_repeatedPushesBuildStackInOrder() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let one = UIViewController()
        let two = UIViewController()

        navigationController.pushViewController(one, animated: true)
        navigationController.pushViewController(two, animated: true)

        expect(navigationController.viewControllers).to(equal([root, one, two]))
    }

    func test_navigationControllerWithSegueInViewDidLoad_segueHappensAndResultIsImmediatelyVisible() {
        let storyboard = UIStoryboard(name: "KittensStoryboard", bundle: nil)
        let viewController = UIViewController()
        try! storyboard.bind(viewController: viewController, toIdentifier: "KittenImage")

        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        expect(navigationController?.visibleViewController).to(beIdenticalTo(viewController))
    }

    // MARK: Reference parity
    //
    // Fleet exchanges the implementations of the navigation methods, so the `fleet_`-prefixed
    // selectors hold UIKit's original code. The reference path below calls that original code
    // directly with `animated: false` (Fleet's animation policy), bypassing the Fleet wrappers,
    // and the tests compare the traces of both paths.

    fileprivate class TracingViewController: UIViewController {
        let name: String
        let trace: TraceLog
        init(name: String, trace: TraceLog) {
            self.name = name
            self.trace = trace
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) { fatalError("unused") }
        override func viewDidLoad() { super.viewDidLoad(); trace.events.append("\(name).viewDidLoad") }
        override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); trace.events.append("\(name).viewWillAppear") }
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); trace.events.append("\(name).viewDidAppear") }
        override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); trace.events.append("\(name).viewWillDisappear") }
        override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); trace.events.append("\(name).viewDidDisappear") }
    }

    fileprivate final class TraceLog {
        var events: [String] = []
    }

    fileprivate final class TracingDelegate: NSObject, UINavigationControllerDelegate {
        let trace: TraceLog
        init(trace: TraceLog) { self.trace = trace }
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            trace.events.append("delegate.willShow(\((viewController as? TracingViewController)?.name ?? "?"), animated: \(animated))")
        }
        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            trace.events.append("delegate.didShow(\((viewController as? TracingViewController)?.name ?? "?"), animated: \(animated))")
        }
    }

    @MainActor private enum Reference {
        static func push(_ nav: UINavigationController, _ controller: UIViewController) {
            typealias Fn = @convention(c) (AnyObject, Selector, UIViewController, Bool) -> Void
            let selector = NSSelectorFromString("fleet_pushViewController:animated:")
            let imp = nav.method(for: selector)
            unsafeBitCast(imp, to: Fn.self)(nav, selector, controller, false)
            _ = controller.view
        }
        static func pop(_ nav: UINavigationController) -> UIViewController? {
            typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> UIViewController?
            let selector = NSSelectorFromString("fleet_popViewControllerAnimated:")
            return unsafeBitCast(nav.method(for: selector), to: Fn.self)(nav, selector, false)
        }
        static func popTo(_ nav: UINavigationController, _ controller: UIViewController) -> [UIViewController]? {
            typealias Fn = @convention(c) (AnyObject, Selector, UIViewController, Bool) -> [UIViewController]?
            let selector = NSSelectorFromString("fleet_popToViewController:animated:")
            return unsafeBitCast(nav.method(for: selector), to: Fn.self)(nav, selector, controller, false)
        }
        static func popToRoot(_ nav: UINavigationController) -> [UIViewController]? {
            typealias Fn = @convention(c) (AnyObject, Selector, Bool) -> [UIViewController]?
            let selector = NSSelectorFromString("fleet_popToRootViewControllerAnimated:")
            return unsafeBitCast(nav.method(for: selector), to: Fn.self)(nav, selector, false)
        }
    }

    private struct Operations: Sendable {
        let push: @MainActor (UINavigationController, UIViewController) -> Void
        let pop: @MainActor (UINavigationController) -> UIViewController?
        let popTo: @MainActor (UINavigationController, UIViewController) -> [UIViewController]?
        let popToRoot: @MainActor (UINavigationController) -> [UIViewController]?

        static let fleet = Operations(
            push: { $0.pushViewController($1, animated: true) },
            pop: { $0.popViewController(animated: true) },
            popTo: { $0.popToViewController($1, animated: true) },
            popToRoot: { $0.popToRootViewController(animated: true) })
        static let reference = Operations(
            push: { Reference.push($0, $1) },
            pop: { Reference.pop($0) },
            popTo: { Reference.popTo($0, $1) },
            popToRoot: { Reference.popToRoot($0) })
    }

    /// Runs the scenario in a fresh hosted window and returns the settled trace plus the
    /// names of the returned controllers and the final stack.
    private func runScenario(_ ops: Operations) async -> [String] {
        let trace = TraceLog()
        let root = TracingViewController(name: "root", trace: trace)
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        let delegate = TracingDelegate(trace: trace)   // UIKit holds the delegate weakly
        navigation.delegate = delegate
        defer { withExtendedLifetime(delegate) {} }
        let a = TracingViewController(name: "a", trace: trace)
        let b = TracingViewController(name: "b", trace: trace)
        let c = TracingViewController(name: "c", trace: trace)
        func names(_ controllers: [UIViewController]?) -> String {
            guard let controllers else { return "nil" }
            return controllers.map { ($0 as? TracingViewController)?.name ?? "?" }.joined(separator: ",")
        }
        var results: [String] = []

        ops.push(navigation, a)
        ops.push(navigation, b)   // back-to-back while the previous appearance work may be pending
        ops.push(navigation, c)
        results.append("stack \(names(navigation.viewControllers))")
        results.append("popTo(a) -> \(names(ops.popTo(navigation, a)))")
        results.append("popTo(a again) -> \(names(ops.popTo(navigation, a)))")
        results.append("pop -> \(names(ops.pop(navigation).map { [$0] }))")
        results.append("pop at root -> \(names(ops.pop(navigation).map { [$0] }))")
        ops.push(navigation, b)
        results.append("popToRoot -> \(names(ops.popToRoot(navigation)))")
        results.append("popToRoot at root -> \(names(ops.popToRoot(navigation)))")
        results.append("stack \(names(navigation.viewControllers))")

        // Bounded wait for the appearance work to settle: the root is the last controller to appear.
        // Back-to-back operations are compared as a whole: whatever UIKit does with the pending
        // transitions on the reference path, Fleet's forwarding must produce the identical trace.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, trace.events.last != "root.viewDidAppear" {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        window.isHidden = true
        return results + trace.events
    }

    func test_navigationTrace_matchesUnhookedUIKitReference() async {
        let reference = await runScenario(.reference)
        let fleet = await runScenario(.fleet)

        expect(reference).to(contain("root.viewDidAppear"))
        expect(reference.first).to(equal("stack root,a,b,c"))
        expect(fleet).to(equal(reference))
    }

    /// Runs spaced-out operations (each waits for its transition) and returns the settled trace.
    private func runSpacedScenario(_ ops: Operations) async -> [String] {
        let trace = TraceLog()
        let root = TracingViewController(name: "root", trace: trace)
        let navigation = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        let delegate = TracingDelegate(trace: trace)   // UIKit holds the delegate weakly
        navigation.delegate = delegate
        defer { withExtendedLifetime(delegate) {} }
        let a = TracingViewController(name: "a", trace: trace)

        // Settle on both the delegate and the appearance callback: UIKit may deliver
        // didShow and viewDidAppear in either order, and the initial root appearance can
        // lag the window becoming visible, so each boundary waits for both.
        func settle(_ event: String, after count: Int) async {
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline, trace.events.filter({ $0 == event }).count < count {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        await settle("root.viewDidAppear", after: 1)
        await settle("delegate.didShow(root, animated: false)", after: 1)
        ops.push(navigation, a)
        await settle("a.viewDidAppear", after: 1)
        await settle("delegate.didShow(a, animated: false)", after: 1)
        _ = ops.popTo(navigation, root)
        await settle("root.viewDidAppear", after: 2)
        await settle("delegate.didShow(root, animated: false)", after: 2)
        window.isHidden = true
        return trace.events
    }

    func test_spacedPushAndPopTo_deliverDelegateAndLifecycleCallbacksLikeUnhookedUIKitReference() async {
        let reference = await runSpacedScenario(.reference)
        let fleet = await runSpacedScenario(.fleet)

        expect(reference).to(contain("delegate.willShow(a, animated: false)"))
        expect(reference).to(contain("delegate.didShow(root, animated: false)"))
        expect(fleet).to(equal(reference))
    }

    func test_navigationReturnValues_matchUnhookedUIKitReference() async {
        let reference = await runScenario(.reference)
        let fleet = await runScenario(.fleet)
        let returns = { (trace: [String]) in trace.filter { $0.contains("->") } }

        expect(returns(reference)).to(contain("popTo(a) -> b,c"))
        expect(returns(reference)).to(contain("pop at root -> nil"))
        expect(returns(fleet)).to(equal(returns(reference)))
    }
}
