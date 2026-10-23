import UIKit

// Compiled into both the Fleet-linked consumer tests and the Fleet-free baseline tests. It uses only UIKit, so any
// difference between the traces comes from the process's runtime hooks, never from the scenario.

@MainActor
private final class TraceLog {
    var events: [String] = []
}

private final class TraceController: UIViewController {
    let name: String
    let log: TraceLog
    init(name: String, log: TraceLog) {
        self.name = name
        self.log = log
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("unused") }
    override func viewDidLoad() { super.viewDidLoad(); MainActor.assumeIsolated { log.events.append("\(name).viewDidLoad") } }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); MainActor.assumeIsolated { log.events.append("\(name).viewWillAppear(animated: \(animated))") } }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); MainActor.assumeIsolated { log.events.append("\(name).viewDidAppear(animated: \(animated))") } }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); MainActor.assumeIsolated { log.events.append("\(name).viewWillDisappear(animated: \(animated))") } }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); MainActor.assumeIsolated { log.events.append("\(name).viewDidDisappear(animated: \(animated))") } }
}

private final class TraceDelegate: NSObject, UINavigationControllerDelegate {
    let log: TraceLog
    init(log: TraceLog) { self.log = log }
    private func name(_ controller: UIViewController) -> String { (controller as? TraceController)?.name ?? "?" }
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        MainActor.assumeIsolated { log.events.append("delegate.willShow(\(name(viewController)), animated: \(animated))") }
    }
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        MainActor.assumeIsolated { log.events.append("delegate.didShow(\(name(viewController)), animated: \(animated))") }
    }
}

enum HostingTraceScenario {
    /// Runs animated push, pop, presentation and dismissal (plus an offscreen push) and returns the observed
    /// callback order, forwarded animated arguments and view-loading state. Each step waits, boundedly, for its
    /// own completion; a timed-out wait shows up as a missing event in the comparison.
    @MainActor
    static func run() async -> [String] {
        let log = TraceLog()
        let delegate = TraceDelegate(log: log)

        // Offscreen push: UIKit leaves the pushed view unloaded until the navigation controller is shown.
        let offscreen = UINavigationController(rootViewController: TraceController(name: "offscreenRoot", log: log))
        let hidden = TraceController(name: "hidden", log: log)
        offscreen.pushViewController(hidden, animated: true)
        log.events.append("offscreen.hiddenViewLoaded=\(hidden.isViewLoaded)")

        let window = (UIApplication.shared.delegate?.window ?? nil) ?? UIWindow()
        let visibleRoot = TraceController(name: "visibleRoot", log: log)
        let navigation = UINavigationController(rootViewController: visibleRoot)
        navigation.delegate = delegate
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        await settle { navigation.transitionCoordinator == nil && visibleRoot.view.window != nil && log.events.contains { $0.hasPrefix("visibleRoot.viewDidAppear") } }
        log.events.append("--- push")

        let detail = TraceController(name: "detail", log: log)
        navigation.pushViewController(detail, animated: true)
        log.events.append("push.returned")
        await settle { navigation.topViewController === detail && navigation.transitionCoordinator == nil && log.events.contains { $0.hasPrefix("delegate.didShow(detail") } }
        log.events.append("--- pop")
        _ = navigation.popViewController(animated: true)
        log.events.append("pop.returned")
        await settle { navigation.topViewController === visibleRoot && navigation.transitionCoordinator == nil && log.events.contains { $0.hasPrefix("delegate.didShow(visibleRoot") } }
        log.events.append("--- present")

        let modal = TraceController(name: "modal", log: log)
        visibleRoot.present(modal, animated: true) { log.events.append("present.completion") }
        log.events.append("present.returned")
        await settle { log.events.contains("present.completion") }
        log.events.append("--- dismiss")
        visibleRoot.dismiss(animated: true) { log.events.append("dismiss.completion") }
        log.events.append("dismiss.returned")
        await settle { log.events.contains("dismiss.completion") }
        log.events.append("--- done")

        navigation.delegate = nil
        window.rootViewController = UIViewController()
        return log.events
    }

    @MainActor
    private static func settle(_ condition: () -> Bool) async {
        for _ in 0..<250 where !condition() {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// Writes the trace as JSON to `FLEET_TRACE_OUT/<name>.json`, which the distribution checker compares.
    static func record(_ events: [String], as name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["FLEET_TRACE_OUT"], !directory.isEmpty else {
            throw NSError(domain: "HostingTraceScenario", code: 1, userInfo: [NSLocalizedDescriptionKey: "FLEET_TRACE_OUT is not set"])
        }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".json")
        try JSONSerialization.data(withJSONObject: events, options: [.prettyPrinted]).write(to: url)
    }
}
