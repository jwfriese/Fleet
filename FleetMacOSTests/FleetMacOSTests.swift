#if os(macOS)
import AppKit
import SwiftUI
import Testing
import XCTest
@testable import FleetMacOS

@MainActor
final class Model: ObservableObject {
    @Published var unlocked = false
    @Published var draft = "pending"
}

struct Screen: View {
    @ObservedObject var model: Model
    var body: some View {
        VStack {
            Text(model.unlocked ? "account: \(model.draft)" : "locked")
        }
        .frame(width: 200, height: 100)
    }
}

@MainActor
final class Counter {
    var active = 0
    var maxActive = 0
}

@MainActor
@Suite(.serialized)
struct FleetMacOSSwiftTestingTests {
    @Test func hostsObservesAndClears() async throws {
        let model = Model()
        var ownedWindow: NSWindow?
        try await FleetMacOS.withHostedView(Screen(model: model)) { host in
            ownedWindow = host.window
            #expect(host.ownsWindow)
            try await host.waitUntilReady()
            try await host.waitForAppearance()
            model.unlocked = true
            try await host.waitForUpdate("unlocked content") {
                host.hostingController.view.fittingSize.width > 0 && model.unlocked
            }
            model.unlocked = false
            model.draft = ""
        }
        #expect(ownedWindow?.contentViewController == nil)
        #expect(ownedWindow?.isVisible == false)
        #expect(!FleetMacOSCoordinator.shared.isHeld)
    }

    @Test func rawContentViewIsRestored() async throws {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let original = NSView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let button = NSButton(title: "Go", target: nil, action: nil)
        original.addSubview(button)
        window.contentView = original
        try await FleetMacOS.withHostedView(Screen(model: Model()), window: window) { host in
            try await host.waitForAppearance()
        }
        #expect(window.contentView === original)
        #expect(button.window === window)
    }

    @Test func contentSizeLimitsAreRestored() async throws {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 80, height: 60)
        window.contentMaxSize = NSSize(width: 900, height: 800)
        try await FleetMacOS.withHostedView(Screen(model: Model()), window: window) { host in
            try await host.waitForAppearance()
        }
        #expect(window.contentMinSize == NSSize(width: 80, height: 60))
        #expect(window.contentMaxSize == NSSize(width: 900, height: 800))
    }

    @Test func errorRestoresBorrowedWindow() async throws {
        struct Boom: Error {}
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let original = NSViewController()
        window.contentViewController = original
        var cleaned = false
        do {
            try await FleetMacOS.withHostedView(Screen(model: Model()), window: window) { host in
                try host.addCleanup { cleaned = true }
                try await host.waitForAppearance()
                throw Boom()
            }
            Issue.record("expected error")
        } catch is Boom {}
        #expect(cleaned)
        #expect(window.contentViewController === original)
        #expect(!FleetMacOSCoordinator.shared.isHeld)
    }

    @Test func timeoutIsBoundedAndTyped() async throws {
        do {
            try await FleetMacOS.withHostedView(Screen(model: Model())) { host in
                try await host.waitUntil("never", timeout: 0.05) { false }
            }
            Issue.record("expected timeout")
        } catch let failure as FleetMacOSFailure {
            #expect(failure.kind == .timedOut)
        }
        #expect(!FleetMacOSCoordinator.shared.isHeld)
    }

    @Test func nestingIsRejected() async throws {
        try await FleetMacOS.withHostedView(Screen(model: Model())) { _ in
            do {
                try await FleetMacOS.withHostedView(Screen(model: Model())) { _ in }
                Issue.record("expected nesting failure")
            } catch let failure as FleetMacOSFailure {
                #expect(failure.kind == .invalidSetup)
            }
        }
    }

    @Test func cancellationCleansUp() async throws {
        let task = Task { @MainActor in
            try await FleetMacOS.withHostedView(Screen(model: Model())) { host in
                try await host.waitUntil("never", timeout: 30) { false }
            }
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do { try await task.value; Issue.record("expected cancellation") } catch is CancellationError {}
        #expect(!FleetMacOSCoordinator.shared.isHeld)
    }

    @Test func scopesAreSerialized() async throws {
        let counter = Counter()
        var tasks: [Task<Void, Never>] = []
        for _ in 0..<3 {
            tasks.append(Task { @MainActor in
                try? await FleetMacOS.withHostedView(Screen(model: Model())) { host in
                    counter.active += 1
                    counter.maxActive = max(counter.maxActive, counter.active)
                    try await host.waitForAppearance()
                    counter.active -= 1
                }
            })
        }
        for task in tasks { await task.value }
        #expect(counter.maxActive == 1)
    }
}

@MainActor
final class WaitProbe {
    var evaluations = 0
    var flag = false
}

@MainActor
@Suite(.serialized)
struct FleetMacOSWaitLifetimeTests {
    @Test func waitOutlivingItsScopeFailsWithoutEvaluatingPredicate() async throws {
        let probe = WaitProbe()
        var old: Task<FleetMacOSFailure?, Never>?
        try await FleetMacOS.withHostedView(Screen(model: Model())) { host in
            old = Task { @MainActor in
                do {
                    try await host.waitUntil("flag", timeout: 5, pollInterval: 0.05) { probe.evaluations += 1; return probe.flag }
                } catch let failure as FleetMacOSFailure { return failure } catch {}
                return nil
            }
            while probe.evaluations == 0 { try await Task.sleep(nanoseconds: 5_000_000) }
        }
        let before = probe.evaluations
        try await FleetMacOS.withHostedView(Screen(model: Model())) { _ in
            probe.flag = true
            let failure = await old?.value
            #expect(failure?.kind == .invalidSetup)
        }
        #expect(probe.evaluations == before)
    }
}

@MainActor
final class FleetMacOSXCTests: XCTestCase {
    func test_hostsInXCTest() async throws {
        let model = Model()
        try await FleetMacOS.withHostedView(Screen(model: model)) { host in
            try await host.waitUntilReady()
            XCTAssertTrue(host.isReady)
        }
    }
}
#endif
