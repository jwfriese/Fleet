import Combine
import SwiftUI
import Testing
import UIKit
import XCTest
import Fleet

/// An application-owned fake service injected into the screen under test.
@MainActor
final class FakeGreetingService: ObservableObject {
    @Published var greeting = "none"
    /// What the screen's `Text` last rendered, reported when the rendered text appears.
    var displayed = "none"
    var sheetContent: String?
    func load() { greeting = "hello" }
}

/// Requests the test sends to the *mounted* screen. The screen's button and this seam call the
/// same screen action, so the test operates the screen's own code, not the fake directly. A
/// ViewInspector tap of the real button is shown in the optional ViewInspector proof.
enum GreetingRequest { case load, show }

struct GreetingScreen: View {
    @EnvironmentObject var service: FakeGreetingService
    @State private var shown = "none"
    @State private var presented = false
    let requests: PassthroughSubject<GreetingRequest, Never>

    private func load() {
        service.load()
        shown = service.greeting
    }

    var body: some View {
        VStack {
            // A changed identity makes the rendered text appear again, reporting what was rendered.
            Text(shown)
                .onAppear { service.displayed = shown }
                .id(shown)
            Button("Load") { load() }
            Button("Show") { presented = true }
        }
        .onReceive(requests) { request in
            switch request {
            case .load: load()
            case .show: presented = true
            }
        }
        .sheet(isPresented: $presented) {
            Text("sheet content").onAppear { service.sheetContent = "sheet content" }
        }
    }
}

/// A screen whose `.task` is observed by Fleet so removal's cooperative cancellation is asserted.
struct ObservedTaskScreen: View {
    let onCancel: @MainActor @Sendable () -> Void
    var body: some View {
        Text("working").fleetObservedTask("poll") {
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 5_000_000) }
            onCancel()
        }
    }
}

// swiftui-starter-xctest:begin
@MainActor
final class SwiftUIHostingXCTestStarter: XCTestCase {
    func test_screenAction_updatesObservableState() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let service = FakeGreetingService()
        let requests = PassthroughSubject<GreetingRequest, Never>()
        try await Fleet.withHostedView(GreetingScreen(requests: requests).environmentObject(service), window: window) { host in
            XCTAssertTrue(host.isReady)
            XCTAssertEqual(service.displayed, "none")
            // The mounted screen runs its own (idempotent) load action. The request is repeated
            // inside the bounded wait until the screen's subscription has answered it.
            try await host.waitForUpdate("greeting rendered") {
                requests.send(.load)
                return service.displayed == "hello"
            }
            XCTAssertEqual(host.lifecycle.count(of: .appeared), 1, "the same mounted host, not a second one")
        }
    }

    func test_screenSheet_presentsLiveContent() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let service = FakeGreetingService()
        let requests = PassthroughSubject<GreetingRequest, Never>()
        try await Fleet.withHostedView(GreetingScreen(requests: requests).environmentObject(service), window: window) { host in
            try await host.waitForUpdate("screen's sheet content on screen") {
                requests.send(.show)  // idempotent; repeated until the mounted screen answers
                return service.sheetContent == "sheet content" && host.hostingController.presentedViewController?.view.window === window
            }
        }
    }

    func test_removal_cancelsObservedTask() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        var cancelled = 0
        try await Fleet.withHostedView(ObservedTaskScreen(onCancel: { cancelled += 1 }), window: window) { host in
            try await host.waitForTaskStart("poll")
            try await host.remove()
            try await host.waitForTaskCancellation("poll")
        }
        XCTAssertEqual(cancelled, 1)
    }
}
// swiftui-starter-xctest:end

// swiftui-starter-swift-testing:begin
@MainActor
@Suite("SwiftUI hosting starter")
struct SwiftUIHostingSwiftTestingStarter {
    @Test func screenActionUpdatesRenderedState() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeGreetingService()
        let requests = PassthroughSubject<GreetingRequest, Never>()
        try await Fleet.withHostedView(GreetingScreen(requests: requests).environmentObject(service), window: window) { host in
            try await host.waitForUpdate("greeting rendered") {
                requests.send(.load)  // idempotent; repeated until the mounted screen answers
                return service.displayed == "hello"
            }
            #expect(host.lifecycle.count(of: .appeared) == 1)
        }
    }

    @Test func presentedSheetIsLive() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeGreetingService()
        let requests = PassthroughSubject<GreetingRequest, Never>()
        try await Fleet.withHostedView(GreetingScreen(requests: requests).environmentObject(service), window: window) { host in
            try await host.waitForUpdate("screen's sheet content on screen") {
                requests.send(.show)  // idempotent; repeated until the mounted screen answers
                return service.sheetContent == "sheet content" && host.hostingController.presentedViewController?.view.window === window
            }
        }
    }

    @Test func handleCannotOutliveScope() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        var escaped: FleetHostedView?
        try await Fleet.withHostedView(Text("x"), window: window) { escaped = $0 }
        await #expect(throws: FleetFailure.self) { try await escaped?.waitForAppearance(timeout: 0.1) }
    }
}
// swiftui-starter-swift-testing:end
