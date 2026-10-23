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

// MARK: - Optimistic deletion example (Reciplan-shaped public fixture)

/// Application-owned fake with explicit checkpoints: nothing resolves until the test releases it,
/// and `shutdown()` (also run on cancellation) releases every pending continuation.
@MainActor
final class FakeIngredientService {
    struct ServiceError: Error {}
    private(set) var started: [String] = []
    private var pending: [String: CheckedContinuation<Void, Error>] = [:]

    func delete(_ id: String) async throws {
        started.append(id)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending[id] = $0 }
        } onCancel: {
            Task { @MainActor in self.release(id, with: CancellationError()) }
        }
    }

    func isPending(_ id: String) -> Bool { pending[id] != nil }
    func releaseSuccess(_ id: String) { pending.removeValue(forKey: id)?.resume() }
    func releaseFailure(_ id: String) { release(id, with: ServiceError()) }
    func shutdown() { for id in Array(pending.keys) { release(id, with: CancellationError()) } }
    private func release(_ id: String, with error: Error) { pending.removeValue(forKey: id)?.resume(throwing: error) }
}

struct Ingredient: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
}

@MainActor
final class IngredientsModel: ObservableObject {
    @Published var ingredients = [
        Ingredient(id: "flour", name: "Flour"),
        Ingredient(id: "eggs", name: "Eggs"),
        Ingredient(id: "milk", name: "Milk"),
    ]
    @Published var errorMessage: String?
    /// Response-handled checkpoint: set only after a successful response is consumed.
    @Published var confirmation: String?
    @Published var deleting: Set<String> = []
    let service: FakeIngredientService
    private var generation = 0
    private var tasks: [Task<Void, Never>] = []

    init(service: FakeIngredientService) { self.service = service }

    /// Optimistic: the row leaves immediately; a failed response restores it at its original index.
    func delete(_ ingredient: Ingredient) {
        guard let index = ingredients.firstIndex(of: ingredient), !deleting.contains(ingredient.id) else { return }
        errorMessage = nil
        confirmation = nil
        deleting.insert(ingredient.id)
        ingredients.remove(at: index)
        let current = generation
        tasks.append(Task { [weak self] in
            guard let self else { return }
            do {
                try await service.delete(ingredient.id)
                if current == generation { confirmation = "Deleted \(ingredient.name)" }
            } catch {
                guard current == generation, !Task.isCancelled else { return }
                ingredients.insert(ingredient, at: min(index, ingredients.count))
                errorMessage = "Could not delete \(ingredient.name)"
            }
            if current == generation { deleting.remove(ingredient.id) }
        })
    }

    /// Ends this screen's work: later results are ignored and pending fake requests are released.
    func shutdown() {
        generation += 1
        tasks.forEach { $0.cancel() }
        tasks = []
        service.shutdown()
    }
}

struct IngredientsScreen: View {
    @ObservedObject var model: IngredientsModel

    var body: some View {
        VStack(alignment: .leading) {
            if let message = model.errorMessage {
                Text(message).fleetElement("error", text: message)
            }
            if let message = model.confirmation {
                Text(message).fleetElement("confirmation", text: message)
            }
            ForEach(model.ingredients) { ingredient in
                // The Delete button and Fleet's action run the same closure.
                let delete: @MainActor @Sendable () -> Void = { [model] in model.delete(ingredient) }
                HStack {
                    Text(ingredient.name)
                    Spacer()
                    Button("Delete", action: delete)
                }
                .frame(height: 44)
                .fleetElement("ingredient.\(ingredient.id)", text: ingredient.name, actions: [
                    FleetElementAction("Delete", isEnabled: !model.deleting.contains(ingredient.id), perform: delete)
                ])
            }
            Spacer()
        }
    }
}

private let allIngredientIDs = ["ingredient.flour", "ingredient.eggs", "ingredient.milk"]

// optimistic-deletion-xctest:begin
@MainActor
final class OptimisticDeletionXCTestStarter: XCTestCase {
    func test_failedDeletion_restoresRowInPlaceWithVisibleError() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForElement("ingredient.milk")
            XCTAssertEqual(host.mountedElementIDs, allIngredientIDs)

            // The second row's Delete, found by identity (every row's label is "Delete").
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitForUpdate("delete request started") { service.started == ["eggs"] }
            try await host.waitForElementRemoval("ingredient.eggs")  // local change, response still held
            XCTAssertTrue(service.isPending("eggs"))
            XCTAssertEqual(host.mountedElementIDs, ["ingredient.flour", "ingredient.milk"])

            service.releaseFailure("eggs")
            try await host.waitForElement("ingredient.eggs")
            try await host.waitForElement("error")
            XCTAssertEqual(host.mountedElementIDs.filter { $0.hasPrefix("ingredient.") }, allIngredientIDs)
            let error = try host.element("error")
            XCTAssertEqual(error.text, "Could not delete Eggs")
            XCTAssertGreaterThan(error.frame.height, 0)
        }
    }

    func test_successfulDeletion_leavesRowRemoved_andBadRequestsFailRecoverably() async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForElement("ingredient.milk")
            XCTAssertThrowsError(try host.perform("Delete", onElement: "ingredient.sugar")) { error in
                XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
                XCTAssertTrue((error as? FleetFailure)?.target.contains("ingredient.sugar") == true)
            }
            XCTAssertThrowsError(try host.perform("Archive", onElement: "ingredient.milk"))
            try host.perform("Delete", onElement: "ingredient.milk")
            try await host.waitForElementRemoval("ingredient.milk")
            service.releaseSuccess("milk")
            try await host.waitForElement("confirmation")  // rendered only after the response was handled
            XCTAssertEqual(try host.element("confirmation").text, "Deleted Milk")
            XCTAssertEqual(host.mountedElementIDs.filter { $0.hasPrefix("ingredient.") }, ["ingredient.flour", "ingredient.eggs"])
        }
        XCTAssertFalse(service.isPending("milk"))
    }
}
// optimistic-deletion-xctest:end

// optimistic-deletion-swift-testing:begin
@MainActor
@Suite("Optimistic deletion starter")
struct OptimisticDeletionSwiftTestingStarter {
    @Test func failedDeletionRestoresRowInPlace() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForElement("ingredient.milk")
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitForElementRemoval("ingredient.eggs")
            #expect(service.isPending("eggs"))
            service.releaseFailure("eggs")
            try await host.waitForElement("ingredient.eggs")
            try await host.waitForElement("error")
            #expect(host.mountedElementIDs.filter { $0.hasPrefix("ingredient.") } == allIngredientIDs)
        }
    }

    @Test func successKeepsRowRemovedAndScopeEndReleasesPendingRequest() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForElement("ingredient.milk")
            try host.perform("Delete", onElement: "ingredient.flour")
            try await host.waitForElementRemoval("ingredient.flour")
            service.releaseSuccess("flour")
            try await host.waitForElement("confirmation")  // rendered only after the response was handled
            #expect(host.mountedElementIDs.filter { $0.hasPrefix("ingredient.") } == ["ingredient.eggs", "ingredient.milk"])
            try host.perform("Delete", onElement: "ingredient.milk")  // left pending at scope end
            try await host.waitForUpdate("request started") { service.isPending("milk") }
        }
        #expect(!service.isPending("milk"))
    }
}
// optimistic-deletion-swift-testing:end
