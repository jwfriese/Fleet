import SwiftUI
import XCTest
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp

    @MainActor
    private final class ContentModel: ObservableObject {
        @Published var name = "Soup"
        @Published var shown = true
    }

    private struct ContentScreen: View {
        @ObservedObject var model: ContentModel
        var body: some View {
            VStack {
                if model.shown {
                    Text(model.name).fleetObservedContent("detail", ["name": model.name])
                }
                Text("underlying").fleetObservedContent("list")
            }
        }
    }

    @MainActor
    class FleetPresentedContentSpec: XCTestCase {
        private var hostWindow: UIWindow!

        override func setUp() async throws {
            try await super.setUp()
            continueAfterFailure = false
            hostWindow = try XCTUnwrap(UIApplication.shared.keyWindow)
        }

        override func tearDown() async throws {
            hostWindow = nil
            try await super.tearDown()
        }

        func test_contentUpdatesInPlace_keepingInstanceIdentity() async throws {
            let model = ContentModel()
            try await Fleet.withHostedView(ContentScreen(model: model), window: hostWindow) { host in
                try await host.waitForContent("detail", values: ["name": "Soup"])
                let first = try XCTUnwrap(host.currentContent("detail"))
                model.name = "Salad"
                try await host.waitForContent("detail", values: ["name": "Salad"])
                XCTAssertEqual(host.currentContent("detail")?.instance, first.instance)
                XCTAssertEqual(host.presentationCount(of: "detail"), 1)
            }
        }

        func test_removedContent_isDismissedAndUnregisteredAfterScope() async throws {
            let model = ContentModel()
            var recorder: FleetLifecycleRecorder?
            try await Fleet.withHostedView(ContentScreen(model: model), window: hostWindow) { host in
                recorder = host.lifecycle
                try await host.waitForContentPresented("detail")
                model.shown = false
                try await host.waitForContentDismissed("detail")
                XCTAssertNotNil(host.currentContent("list"))
                model.shown = true
                try await host.waitForContentPresented("detail", count: 2)
            }
            XCTAssertTrue(try XCTUnwrap(recorder).displayedContent.isEmpty, "no observed content outlived the scope")
        }

        func test_timeout_namesWhatIsDisplayed() async throws {
            let model = ContentModel()
            do {
                try await Fleet.withHostedView(ContentScreen(model: model), window: hostWindow) { host in
                    try await host.waitForContent("detail", values: ["name": "Missing"], timeout: 0.2)
                }
                XCTFail("expected timeout")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
                XCTAssertTrue(failure.state.contains("Resolved environment"))
                XCTAssertTrue(failure.action.contains("name=Soup"))
            }
        }

        func test_changedSemanticIdentity_tracksCurrentIdentity() async throws {
            let model = ContentModel()
            struct Screen: View {
                @ObservedObject var model: ContentModel
                var body: some View {
                    Text(model.name).fleetObservedContent(model.name, ["name": model.name])
                }
            }
            try await Fleet.withHostedView(Screen(model: model), window: hostWindow) { host in
                try await host.waitForContent("Soup", values: ["name": "Soup"])
                model.name = "Salad"
                try await host.waitForContent("Salad", values: ["name": "Salad"])
                try await host.waitForContentDismissed("Soup")
                XCTAssertNil(host.currentContent("Soup"))
                XCTAssertEqual(host.presentationCount(of: "Salad"), 1)
            }
        }

        func test_timeout_reportsContentAtDeadline() async throws {
            let model = ContentModel()
            do {
                try await Fleet.withHostedView(ContentScreen(model: model), window: hostWindow) { host in
                    try await host.waitForContent("detail", values: ["name": "Soup"])
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        model.name = "Salad"
                    }
                    try await host.waitForContent("detail", values: ["name": "Missing"], timeout: 0.4)
                }
                XCTFail("expected timeout")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
                XCTAssertTrue(failure.action.contains("name=Salad"), failure.action)
            }
        }

        func test_modifierOutsideFleetHost_doesNothing() async throws {
            let originalRoot = hostWindow.rootViewController
            defer { hostWindow.rootViewController = originalRoot }
            let controller = UIHostingController(rootView: Text("plain").fleetObservedContent("x", ["a": "b"]))
            hostWindow.rootViewController = controller
            hostWindow.layoutIfNeeded()
            XCTAssertNotNil(controller.view.window)
        }
    }
#endif
