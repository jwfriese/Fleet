import XCTest

class Test {}

/// A weak reference probe. Tests keep only this outside an ownership boundary, so that the probe
/// itself never contributes to the lifetime being measured.
struct WeakProbe<T: AnyObject>: @unchecked Sendable {  // holds no strong reference
    weak var value: T?
    init(_ value: T) { self.value = value }
}

/// Runs synchronous work in its own autorelease pool, so temporaries from Objective-C returns,
/// casts, and assertion evaluation are released when the scope ends rather than when the
/// enclosing test method returns. Do not hold a pool across a suspension point; scope async work
/// in synchronous helpers instead.
func lifetimeScope<T>(_ body: () throws -> T) rethrows -> T {
    return try autoreleasepool(invoking: body)
}

/// Asserts that the probed object is released once every ownership boundary that could hold it has
/// ended. The check drains autorelease pools and spins the run loop until the deadline, because
/// UIKit may release objects on a later run loop turn; an object that is genuinely retained still
/// fails at the deadline. Call it outside any scope that touched the object.
@MainActor
func assertReleased<T: AnyObject>(
    _ probe: WeakProbe<T>,
    _ description: String = "object",
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
        lifetimeScope { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        if lifetimeScope({ probe.value == nil }) { return }
        if Date() >= deadline { break }
    }
    XCTFail("The \(description) was still alive \(timeout)s after its owners were released", file: file, line: line)
}

/// Owns the UI state one hosted test borrows from the application, and puts it back afterwards.
///
/// Create it in `setUp` (it records the key window, its root, and the root's presentation), make
/// windows and embed views through it, and `await restore()` in `tearDown`. Restoration runs in the
/// safe order: finish editing, dismiss presentations (bounded wait), detach embedded views, hide the
/// windows the test created, then give the borrowed window its original root and key status back.
/// It is idempotent, so it is also safe to call from a `defer` on a throwing path.
@MainActor
final class HostedUIFixture {
    private weak var borrowedWindow: UIWindow?
    private var borrowedRoot: UIViewController?
    /// The top of the borrowed root's presentation chain at `init`. Presentations above it belong to
    /// the scenario; it and everything below it belong to the borrowed baseline and are preserved.
    private var baselineTop: UIViewController?
    private var ownedWindows: [UIWindow] = []
    private var embeddedViews: [UIView] = []

    init() {
        borrowedWindow = UIApplication.shared.keyWindow
        borrowedRoot = borrowedWindow?.rootViewController
        baselineTop = borrowedRoot.map(Self.top(of:))
    }

    private static func top(of controller: UIViewController) -> UIViewController {
        var top = controller
        while let next = top.presentedViewController { top = next }
        return top
    }

    /// A window owned by the fixture, made key and visible with `root` installed.
    @discardableResult
    func makeKeyWindow(root: UIViewController? = nil) -> UIWindow {
        let window = UIWindow()
        window.rootViewController = root
        window.makeKeyAndVisible()
        ownedWindows.append(window)
        return window
    }

    /// Takes ownership of a window the test created itself, so restoration hides it.
    func adopt(_ window: UIWindow) -> UIWindow {
        ownedWindows.append(window)
        return window
    }

    /// Attaches `view` to the borrowed application root, remembering it for removal.
    func embed(_ view: UIView) throws {
        try Test.embedViewIntoMainApplicationWindow(view)
        embeddedViews.append(view)
    }

    func restore(timeout: TimeInterval = 5) async {
        let windows = ownedWindows + [borrowedWindow].compactMap { $0 }
        windows.forEach { $0.endEditing(true) }

        // Dismissing from a presenter dismisses its presented child and everything above it. The
        // borrowed root only dismisses above its baseline chain; a root the test replaced has no
        // baseline presentations, so it dismisses from itself.
        var presenters = ownedWindows.compactMap { $0.rootViewController }
        if let window = borrowedWindow, let root = window.rootViewController {
            presenters.append(root === borrowedRoot ? (baselineTop ?? root) : root)
        }
        presenters.filter { $0.presentedViewController != nil }.forEach { $0.dismiss(animated: false) }
        let deadline = Date().addingTimeInterval(timeout)
        while presenters.contains(where: { $0.presentedViewController != nil }) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        if let stuck = presenters.first(where: { $0.presentedViewController != nil }) {
            XCTFail("Fixture cleanup: \(type(of: stuck)) still presents \(String(describing: stuck.presentedViewController)) after \(timeout)s")
        }

        embeddedViews.forEach { $0.removeFromSuperview() }
        embeddedViews.removeAll()

        for window in ownedWindows {
            window.rootViewController = nil
            window.isHidden = true
        }
        ownedWindows.removeAll()

        if let window = borrowedWindow {
            if window.rootViewController !== borrowedRoot {
                window.rootViewController = borrowedRoot
            }
            window.makeKeyAndVisible()
        }
    }

    /// Whether the application's key window, root, and presentation are what they were at `init`.
    var isRestored: Bool {
        guard let window = borrowedWindow else { return true }
        return UIApplication.shared.keyWindow === window
            && window.rootViewController === borrowedRoot
            && borrowedRoot.map(Self.top(of:)) === baselineTop
            && ownedWindows.isEmpty
            && embeddedViews.isEmpty
    }
}
