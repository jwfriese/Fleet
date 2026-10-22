import UIKit
#if SWIFT_PACKAGE
import FleetRuntime
#endif

public class Fleet {
    /**
     The process-start hosting policy. It is resolved once, from the `FLEET_HOSTING_POLICY`
     environment variable of the launched process, before Fleet selects which Objective-C hooks to install,
     and never changes afterwards. Set the variable in the test plan, scheme or launch environment, not per test.
     See `Documentation/RuntimeHooks.md`.
     */
    public enum HostingPolicy: String, Sendable, CaseIterable {
        /// Default. Presentation, dismissal, push and pop calls are forced nonanimated, and pushed views load eagerly.
        case legacy = "legacy"
        /// Production presentation and navigation calls keep UIKit's animated arguments, timing and lazy view loading.
        case preserveTiming = "preserve-timing"
    }

    /// The active process-start policy. An invalid `FLEET_HOSTING_POLICY` value already failed at load with a descriptive exception.
    public static var hostingPolicy: HostingPolicy {
        HostingPolicy(rawValue: FleetObjC._hostingPolicyName()) ?? .legacy
    }

    /**
     Provides a quick way of getting at the "main" application window in test.

     - returns:
     A `FLTScreen` instance wrapping the application's key window.
     */
    @MainActor
    public static func getApplicationScreen() -> FLTScreen? {
        guard let window = UIApplication.shared.keyWindow else {
            Logger.logWarning("Cannot get application screen: UIApplication not set up with a key window.")
            return nil
        }

        return Screen(forWindow: window)
    }

    /**
     Wraps the given window in an instance of `FLTScreen` and returns it.

     - returns:
     A `FLTScreen` instance wrapping the given `UIWindow` instance.
     */
    @MainActor
    public static func getScreen(forWindow window: UIWindow) -> FLTScreen {
        return Screen(forWindow: window)
    }

    /**
     Sets the given `UIViewController` as the main application window's root view controller.

     - note:
     This will kick off the given view controller's lifecycle.
     */
    @MainActor
    public static func setAsAppWindowRoot(_ viewController: UIViewController) {
        let window = UIApplication.shared.keyWindow
        // Finish the previous root's editing session before handing off the window.
        window?.endEditing(true)
        window?.rootViewController = viewController
        window?.layoutIfNeeded()
        RunLoop.current.run(mode: RunLoop.Mode.default, before: Date(timeIntervalSinceNow: 1))
    }

    /**
     Sets up a `UINavigationController` as the root view controller of the main application window, and sets
     the the given `UIViewController` as the root view controller of that navigation controller.

     - note:
     This will kick off the given view controller's lifecycle.

     - returns:
     The `UINavigationController` that is now the root view controller of the main app window.
     */
    @MainActor
    public static func setInAppWindowRootNavigation(_ viewController: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: viewController)
        setAsAppWindowRoot(navigationController)
        return navigationController
    }

    /**
     Every loaded `.xctest` bundle, in load order.
     */
    internal static var loadedTestBundles: [Bundle] {
        return Bundle.allBundles.filter { $0.bundlePath.hasSuffix(".xctest") }
    }

    /**
     Note: The original file this func was taken from can be found in the Quick
     project (https://github.com/Quick/Quick) .
     */
    internal static var currentTestBundle: Bundle? {
        return loadedTestBundles.first
    }
}
