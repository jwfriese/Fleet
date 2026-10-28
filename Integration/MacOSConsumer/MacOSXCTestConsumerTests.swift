import AppKit
import FleetMacOS
import SwiftUI
import XCTest

/// External XCTest consumer of the public `FleetMacOS` product. Imports are public (no `@testable`).
@MainActor
final class MacOSXCTestConsumerTests: XCTestCase {
    func test_ownedWindowIsCreatedHostedAndClosed() async throws {
        let model = SessionModel()
        var owned: NSWindow?
        try await FleetMacOS.withHostedView(SessionScreen(model: model)) { host in
            owned = host.window
            XCTAssertTrue(host.ownsWindow)
            try await host.waitUntilReady()
            try await host.waitForAppearance()
            XCTAssertTrue(host.window.isVisible)
            model.unlock()
            try await host.waitForUpdate("account content") { model.unlocked }
            model.revoke()
            try await host.waitForUpdate("private content cleared") { model.draft.isEmpty }
        }
        XCTAssertNil(owned?.contentViewController)
        XCTAssertEqual(owned?.isVisible, false)
    }

    func test_borrowedWindowRestoresContentController() async throws {
        let window = makeBorrowedWindow()
        let original = NSViewController()
        window.contentViewController = original
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
            XCTAssertFalse(host.ownsWindow)
            try await host.waitForAppearance()
            XCTAssertTrue(window.contentViewController === host.hostingController)
        }
        XCTAssertTrue(window.contentViewController === original)
    }

    func test_borrowedWindowRestoresDirectContentViewAndSubviews() async throws {
        let window = makeBorrowedWindow()
        let original = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        let button = NSButton(title: "Go", target: nil, action: nil)
        original.addSubview(button)
        window.contentView = original
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
            try await host.waitForAppearance()
            XCTAssertFalse(window.contentView === original)
        }
        XCTAssertTrue(window.contentView === original)
        XCTAssertTrue(button.window === window)
        XCTAssertTrue(button.superview === original)
    }

    func test_borrowedWindowRestoresSizeConstraintsFrameAndVisibility() async throws {
        let window = makeBorrowedWindow()
        window.contentMinSize = NSSize(width: 80, height: 60)
        window.contentMaxSize = NSSize(width: 900, height: 800)
        let frame = window.frame
        XCTAssertFalse(window.isVisible)
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
            try await host.waitForAppearance()
            XCTAssertTrue(window.isVisible)
        }
        XCTAssertEqual(window.contentMinSize, NSSize(width: 80, height: 60))
        XCTAssertEqual(window.contentMaxSize, NSSize(width: 900, height: 800))
        XCTAssertEqual(window.frame, frame)
        XCTAssertFalse(window.isVisible)
    }

    func test_thrownErrorRunsCleanupsLastFirstAndRestoresWindow() async throws {
        let window = makeBorrowedWindow()
        let original = NSViewController()
        window.contentViewController = original
        var order: [Int] = []
        do {
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel()), window: window) { host in
                try host.addCleanup { order.append(1) }
                try host.addCleanup { order.append(2) }
                try await host.waitForAppearance()
                throw ConsumerError()
            }
            XCTFail("Expected the body's error")
        } catch let error as ConsumerError {
            XCTAssertEqual(error, ConsumerError())
        }
        XCTAssertEqual(order, [2, 1])
        XCTAssertTrue(window.contentViewController === original)
    }

    func test_timeoutIsBoundedTypedAndDescribesWindowState() async throws {
        let start = Date()
        do {
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
                try await host.waitUntil("a state that never occurs", timeout: 0.1) { false }
            }
            XCTFail("Expected a timeout")
        } catch let failure as FleetMacOSFailure {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertTrue(failure.state.contains("Window state:"))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    func test_nonFiniteTimeoutIsInvalidInput() async throws {
        do {
            try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
                try await host.waitUntil("anything", timeout: .infinity) { true }
            }
            XCTFail("Expected invalid input")
        } catch let failure as FleetMacOSFailure {
            XCTAssertEqual(failure.kind, .invalidInput)
        }
    }

    func test_nestedScopeIsRejected() async throws {
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { _ in
            do {
                try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { _ in }
                XCTFail("Expected a nesting failure")
            } catch let failure as FleetMacOSFailure {
                XCTAssertEqual(failure.kind, .invalidSetup)
            }
        }
    }

    func test_cancellationCleansUpAndSuccessorScopeStartsFresh() async throws {
        let model = SessionModel()
        var cleaned = false
        var reached = false
        let first = Task { @MainActor in
            try await FleetMacOS.withHostedView(SessionScreen(model: model)) { host in
                try host.addCleanup { cleaned = true }
                try await host.waitForAppearance()
                reached = true
                try await host.waitUntil("cancellation", timeout: 30) { false }
            }
        }
        let didReach = await eventually { reached }
        XCTAssertTrue(didReach)
        first.cancel()
        do {
            try await first.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertTrue(cleaned)

        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
            try await host.waitForAppearance()
            // Counts are per scope: nothing from the cancelled scope carries over.
            XCTAssertEqual(host.appearCount, 1, "the successor must see exactly its own appearance")
            XCTAssertEqual(host.disappearCount, 0)
            XCTAssertTrue(host.window.contentViewController === host.hostingController)
        }
    }

    func test_hostIsUnusableAfterItsScope() async throws {
        var escaped: FleetMacOSHost?
        try await FleetMacOS.withHostedView(SessionScreen(model: SessionModel())) { host in
            escaped = host
        }
        XCTAssertThrowsError(try escaped?.addCleanup {}) { error in
            XCTAssertEqual((error as? FleetMacOSFailure)?.kind, .invalidSetup)
        }
    }
}
