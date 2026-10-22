import SwiftUI
import Testing
import UIKit
import XCTest
import Fleet

/// An application-owned fake service injected into the screen under test.
@MainActor
final class FakeGreetingService: ObservableObject {
    @Published var greeting = "none"
    func load() { greeting = "hello" }
}

struct GreetingScreen: View {
    @EnvironmentObject var service: FakeGreetingService
    @State private var presented = false

    var body: some View {
        VStack {
            Text(service.greeting)
            Button("Load") { service.load() }
            Button("Show") { presented = true }
        }
        .sheet(isPresented: $presented) { Text("sheet content") }
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
        try await Fleet.withHostedView(GreetingScreen().environmentObject(service), window: window) { host in
            XCTAssertTrue(host.isReady)
            service.load()  // stands in for the screen action; ViewInspector may tap the real button
            try await host.waitForUpdate("greeting shown") { service.greeting == "hello" }
            XCTAssertEqual(host.lifecycle.count(of: .appeared), 1)
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
    @Test func presentedSheetIsLive() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        try await Fleet.withHostedView(GreetingScreen().environmentObject(FakeGreetingService()), window: window) { host in
            let sheet = UIHostingController(rootView: Text("sheet content"))
            host.hostingController.present(sheet, animated: false)
            try await host.waitForUpdate("sheet in window") { sheet.view.window === window }
            #expect(host.hostingController.presentedViewController === sheet)
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
