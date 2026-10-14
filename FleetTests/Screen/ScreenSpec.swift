import XCTest
import Nimble
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
class ScreenSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func test_topmostViewController_returnsTopmostViewController() {
        let window = UIWindow()
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(rootViewController))

        let newTopmostViewController = UIViewController()
        rootViewController.present(newTopmostViewController, animated: true, completion: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(newTopmostViewController))
    }

    func test_topmostViewController_whenNavigationControllerIsInWindowViewStack_returnsVisibleViewController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let pushedViewController = UIViewController()
        rootNavigationController.pushViewController(pushedViewController, animated: false)

        expect(screen.topmostViewController).to(beIdenticalTo(pushedViewController))
    }

    func test_topmostViewController_whenOnlyANavigationControllerIsInViewStack_returnsTheNavigationController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(rootNavigationController))
    }

    func test_topmostViewController_whenTheTopViewControllerHasAPresentedViewController_returnsThatPresentedViewController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let rootViewController = UIViewController()
        rootNavigationController.pushViewController(rootViewController, animated: false)

        let viewControllerToPresent = UIViewController()
        rootViewController.present(viewControllerToPresent, animated: false, completion: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(viewControllerToPresent))
    }

    func test_topmostViewController_whenAViewControllerIsModallyPresentedOverTopViewControllerInNavigationStack_returnsModallyPresentedController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let rootViewController = UIViewController()
        rootNavigationController.pushViewController(rootViewController, animated: false)

        let viewControllerToShow = UIViewController()
        rootViewController.show(viewControllerToShow, sender: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(viewControllerToShow))
    }

    func test_topmostContainer_whenNavigationControllerIsRoot_returnsNavigationControllerWhileTopmostViewControllerReturnsVisibleChild() {
        let window = UIWindow()
        let navigationController = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let pushed = UIViewController()
        navigationController.pushViewController(pushed, animated: false)

        let screen = Screen(forWindow: window)

        expect(screen.topmostContainer).to(beIdenticalTo(navigationController))
        expect(screen.topmostViewController).to(beIdenticalTo(pushed))
    }

    func test_topmostContainer_whenNavigationControllerIsEmpty_returnsTheNavigationControllerForBoth() {
        let window = UIWindow()
        let navigationController = UINavigationController()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostContainer).to(beIdenticalTo(navigationController))
        expect(screen.topmostViewController).to(beIdenticalTo(navigationController))
    }

    func test_topmostViewController_whenTabBarControllerIsRoot_returnsSelectedViewController() {
        let window = UIWindow()
        let first = UIViewController()
        let second = UIViewController()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [first, second]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        tabBarController.selectedIndex = 1

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(second))
        expect(screen.topmostContainer).to(beIdenticalTo(tabBarController))
    }

    func test_topmostViewController_whenTabBarControllerHasNoViewControllers_returnsTheTabBarController() {
        let window = UIWindow()
        let tabBarController = UITabBarController()
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(tabBarController))
    }

    func test_topmostViewController_whenTabContainsNavigationController_returnsNavigationTopController() {
        let window = UIWindow()
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [navigationController]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        let pushed = UIViewController()
        navigationController.pushViewController(pushed, animated: false)

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(pushed))
        expect(screen.topmostContainer).to(beIdenticalTo(tabBarController))
    }

    func test_topmostViewController_whenNavigationControllerIsPresentedFromTab_descendsIntoPresentedContainer() {
        let window = UIWindow()
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [UIViewController()]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        let modalRoot = UIViewController()
        let modalNavigation = UINavigationController(rootViewController: modalRoot)
        tabBarController.present(modalNavigation, animated: false, completion: nil)

        let screen = Screen(forWindow: window)

        expect(screen.topmostContainer).to(beIdenticalTo(modalNavigation))
        expect(screen.topmostViewController).to(beIdenticalTo(modalRoot))
    }

    func test_nestedPresentations_overTabNavigationStack_resolveContainerAndVisibleContent() {
        let window = UIWindow()
        let navigation = UINavigationController(rootViewController: UIViewController())
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [navigation]
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        let pushed = UIViewController()
        navigation.pushViewController(pushed, animated: false)

        expect(Screen(forWindow: window).topmostViewController).to(beIdenticalTo(pushed))
        expect(Screen(forWindow: window).topmostContainer).to(beIdenticalTo(tabBarController))

        let modalRoot = UIViewController()
        let modalNavigation = UINavigationController(rootViewController: modalRoot)
        tabBarController.present(modalNavigation, animated: false, completion: nil)

        expect(Screen(forWindow: window).topmostContainer).to(beIdenticalTo(modalNavigation))
        expect(Screen(forWindow: window).topmostViewController).to(beIdenticalTo(modalRoot))

        // Settle the first presentation before presenting over it.
        expect(modalNavigation.presentingViewController).toEventually(beIdenticalTo(tabBarController))
        expect(modalNavigation.isBeingPresented).toEventually(beFalse())

        let nested = UIViewController()
        modalNavigation.present(nested, animated: false, completion: nil)

        expect(Screen(forWindow: window).topmostContainer).toEventually(beIdenticalTo(nested))
        expect(Screen(forWindow: window).topmostViewController).to(beIdenticalTo(nested))

        var dismissed = false
        tabBarController.dismiss(animated: false) { dismissed = true }
        expect(dismissed).toEventually(beTrue())

        expect(Screen(forWindow: window).topmostContainer).to(beIdenticalTo(tabBarController))
        expect(Screen(forWindow: window).topmostViewController).to(beIdenticalTo(pushed))
    }

    func test_topmostViewController_whenNavigationControllerPresentsDirectly_returnsPresentedController() {
        let window = UIWindow()
        let navigationController = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let presented = UIViewController()
        navigationController.present(presented, animated: false, completion: nil)

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(presented))
        expect(screen.topmostContainer).to(beIdenticalTo(presented))
    }

    func test_presentedAlert_whenNoAlertIsPresented_returnsNil() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewController(withIdentifier: "SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.presentedAlert).to(beNil())
    }

    func test_presentedAlert_whenAnAlertIsPresented_whenAlertIsAlertStyle_returnsTheAlert() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewController(withIdentifier: "SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let screen = Screen(forWindow: window)
        expect(screen.presentedAlert).toNot(beNil())
    }
}
