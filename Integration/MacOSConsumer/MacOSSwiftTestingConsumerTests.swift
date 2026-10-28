import AppKit
import FleetMacOS
import SwiftUI
import Testing

/// External Swift Testing consumer of the public `FleetMacOS` product.
@MainActor
@Suite(.serialized)
struct MacOSSwiftTestingConsumerTests {
    @Test func ownedScopeHostsObservesAndClears() async throws {
        let model = SessionModel()
        var owned: NSWindow?
        try await FleetMacOS.withHostedView(SessionScreen(model: model)) { host in
            owned = host.window
            #expect(host.ownsWindow)
            try await host.waitUntilReady()
            model.unlock()
            try await host.waitForUpdate("account content") { model.unlocked }
            model.revoke()
            try await host.waitForUpdate("private content cleared") { model.draft.isEmpty }
        }
        #expect(owned?.contentViewController == nil)
        #expect(owned?.isVisible == false)
    }

    @Test func borrowedWindowRestoresContentViewAndLimits() async throws {
        let window = makeBorrowedWindow()
        let original = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        window.contentView = original
        window.contentMinSize = NSSize(width: 90, height: 70)
        window.contentMaxSize = NSSize(width: 700, height: 600)
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
            try await host.waitForAppearance()
            #expect(window.contentViewController === host.hostingController)
        }
        #expect(window.contentView === original)
        #expect(window.contentMinSize == NSSize(width: 90, height: 70))
        #expect(window.contentMaxSize == NSSize(width: 700, height: 600))
    }

    @Test func errorAndTimeoutAreTypedAndLeaveWindowRestored() async throws {
        let window = makeBorrowedWindow()
        let original = NSViewController()
        window.contentViewController = original
        await #expect(throws: ConsumerError.self) {
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { _ in
                throw ConsumerError()
            }
        }
        #expect(window.contentViewController === original)
        do {
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
                try await host.waitUntil("never", timeout: 0.1) { false }
            }
            Issue.record("Expected a timeout")
        } catch let failure as FleetMacOSFailure {
            #expect(failure.kind == .timedOut)
        }
        #expect(window.contentViewController === original)
    }

    @Test func cancellationThenSuccessorIsIsolated() async throws {
        var reached = false
        var cleaned = false
        let first = Task { @MainActor in
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
                try host.addCleanup { cleaned = true }
                try await host.waitForAppearance()
                reached = true
                try await host.waitUntil("cancellation", timeout: 30) { false }
            }
        }
        #expect(await eventually { reached })
        first.cancel()
        await #expect(throws: CancellationError.self) { try await first.value }
        #expect(cleaned)
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
            try await host.waitForAppearance()
            // Counts are per scope: nothing from the cancelled scope carries over.
            #expect(host.appearCount == 1)
            #expect(host.disappearCount == 0)
        }
    }
}
