import Testing
import UIKit
import Fleet

/// Records the order in which overlapping context bodies start and finish.
@MainActor
private final class IntervalLog {
    var events: [String] = []
}

/// Swift Testing coverage through the public API only. These tests deliberately do not rely on
/// `.serialized`: whole-lifetime coordination comes from `Fleet.withContext`, which also covers
/// attempts that start from different suites or tasks.
@MainActor
@Suite("Fleet Swift Testing consumer")
struct SwiftTestingConsumerTests {
    private func hostWindow() throws -> UIWindow {
        try #require(UIApplication.shared.keyWindow, "The external consumer must run in an application host")
    }

    @Test func typedFailuresAreAssertableWithoutExceptions() throws {
        let button = UIButton(type: .system)
        button.isEnabled = false
        let failure = #expect(throws: FleetFailure.self) { try button.tapOrThrow() }
        #expect(failure?.kind == .unavailableInteraction)

        let item = UIBarButtonItem(title: "none", style: .plain, target: nil, action: nil)
        let itemFailure = #expect(throws: FleetFailure.self) { try item.tapOrThrow() }
        #expect(itemFailure?.kind == .invalidSetup)

        #if os(iOS)
        let toggle = UISwitch()
        toggle.isEnabled = false
        let switchFailure = #expect(throws: FleetFailure.self) { try toggle.flipOrThrow() }
        #expect(switchFailure?.kind == .unavailableInteraction)
        #endif

        let collection = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        let collectionFailure = #expect(throws: FleetFailure.self) { try collection.fetchCellOrThrow(at: IndexPath(item: 0, section: 0)) }
        #expect(collectionFailure?.kind == .invalidSetup)
    }

    @Test func timeoutIsATypedFailureThatNamesTheCondition() async throws {
        let host = try hostWindow()
        let failure = await #expect(throws: FleetFailure.self) {
            try await Fleet.withContext(window: host) { context in
                try await context.waitUntil("never", timeout: 0.05) { false }
            }
        }
        #expect(failure?.kind == .timedOut)
        #expect(failure?.action.contains("never") == true)
    }

    @Test func scopedHostingBorrowsAWindowAndRestoresItsRoot() async throws {
        let host = try hostWindow()
        let previousRoot = host.rootViewController
        let root = UIViewController()
        try await Fleet.withContext(window: host) { context in
            try await context.setRoot(root)
            #expect(context.screen.topmostViewController === root)
        }
        #expect(host.rootViewController === previousRoot)
    }

    @Test func scopedHostingOwnsAWindowForAnExplicitSceneAndReleasesIt() async throws {
        let host = try hostWindow()
        let scene = try #require(host.windowScene)
        weak var ownedRoot: UIViewController?
        try await Fleet.withContext(scene: scene) { context in
            let root = UIViewController()
            ownedRoot = root
            try await context.setRoot(root)
            #expect(context.window.windowScene === scene)
            #expect(context.ownsWindow)
        }
        for _ in 0..<50 where ownedRoot != nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(ownedRoot == nil)
        #expect(host.isKeyWindow)
    }

    @Test func presentationCompletesAndIsDismissedOnCleanup() async throws {
        let host = try hostWindow()
        let previousRoot = host.rootViewController
        let root = UIViewController()
        let presented = UIViewController()
        try await Fleet.withContext(window: host) { context in
            try await context.setRoot(root)
            root.present(presented, animated: false)
            try await context.waitUntil("presented controller is visible") {
                root.presentedViewController === presented
            }
            #expect(context.screen.topmostViewController === presented)
        }
        #expect(host.rootViewController === previousRoot)
        #expect(root.presentedViewController == nil)
    }

    @Test func cleanupRunsWhenTheBodyThrows() async throws {
        struct Boom: Error {}
        let host = try hostWindow()
        let previousRoot = host.rootViewController
        var cleaned = false
        await #expect(throws: Boom.self) {
            try await Fleet.withContext(window: host) { context in
                try context.addCleanup { cleaned = true }
                try await context.setRoot(UIViewController())
                throw Boom()
            }
        }
        #expect(cleaned)
        #expect(host.rootViewController === previousRoot)
    }

    @Test func overlappingAttemptsRunOneAtATimeForTheirWholeLifetime() async throws {
        let host = try hostWindow()
        let previousRoot = host.rootViewController
        let log = IntervalLog()
        let attempts = ["a", "b", "c"].map { name in
            Task { @MainActor in
                try await Fleet.withContext(window: host) { context in
                    log.events.append("start \(name)")
                    let root = UIViewController()
                    try await context.setRoot(root)
                    // Yield while holding the context so a coordination bug would interleave.
                    try await context.waitUntil("root is installed") { host.rootViewController === root }
                    try await Task.sleep(nanoseconds: 20_000_000)
                    #expect(host.rootViewController === root, "another context replaced \(name)'s root")
                    log.events.append("end \(name)")
                }
            }
        }
        for attempt in attempts {
            try await attempt.value
        }
        #expect(log.events.count == 6)
        for pair in stride(from: 0, to: log.events.count, by: 2) {
            let started = log.events[pair].dropFirst("start ".count)
            #expect(log.events[pair] == "start \(started)")
            #expect(log.events[pair + 1] == "end \(started)", "contexts interleaved: \(log.events)")
        }
        #expect(host.rootViewController === previousRoot)
    }
}

// quick-start:begin
@MainActor
private final class GreetingViewController: UIViewController {
    let button = UIButton(type: .system)
    private(set) var taps = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        button.addAction(UIAction { [weak self] _ in self?.taps += 1 }, for: .touchUpInside)
        view.addSubview(button)
    }
}

@MainActor
struct QuickStartTests {
    @Test func tappingTheButtonRunsItsAction() async throws {
        let host = try #require(UIApplication.shared.keyWindow)
        try await Fleet.withContext(window: host) { context in
            let controller = GreetingViewController()
            try await context.setRoot(controller)

            try controller.button.tapOrThrow()

            #expect(controller.taps == 1)
        }
    }
}
// quick-start:end
