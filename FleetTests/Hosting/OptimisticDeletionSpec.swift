import SwiftUI
import XCTest
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

/// Application-owned fake service with explicit checkpoints. Nothing resolves until the test
/// releases it; cancellation and `shutdown()` release every pending continuation.
@MainActor
private final class FakeIngredientService {
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

private struct Ingredient: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
}

private enum DeletionMode { case correct, deferLocalUpdate, noRollback }

@MainActor
private final class IngredientsModel: ObservableObject {
    @Published var ingredients = [
        Ingredient(id: "flour", name: "Flour"),
        Ingredient(id: "eggs", name: "Eggs"),
        Ingredient(id: "milk", name: "Milk"),
    ]
    @Published var errorMessage: String?
    /// Application-owned response-handled checkpoint: set only after a successful response is consumed.
    @Published var confirmation: String?
    @Published var deleting: Set<String> = []
    let service: FakeIngredientService
    let mode: DeletionMode
    private var generation = 0
    private var tasks: [Task<Void, Never>] = []

    init(service: FakeIngredientService, mode: DeletionMode = .correct) {
        self.service = service
        self.mode = mode
    }

    func delete(_ ingredient: Ingredient) {
        guard let index = ingredients.firstIndex(of: ingredient), !deleting.contains(ingredient.id) else { return }
        errorMessage = nil
        confirmation = nil
        deleting.insert(ingredient.id)
        if mode != .deferLocalUpdate { ingredients.remove(at: index) }
        let current = generation
        tasks.append(Task { [weak self] in
            guard let self else { return }
            do {
                try await service.delete(ingredient.id)
                guard current == generation else { return }
                if mode == .deferLocalUpdate, let now = ingredients.firstIndex(of: ingredient) { ingredients.remove(at: now) }
                confirmation = "Deleted \(ingredient.name)"
            } catch {
                guard current == generation, !Task.isCancelled else { return }
                if mode != .noRollback { ingredients.insert(ingredient, at: min(index, ingredients.count)) }
                errorMessage = "Could not delete \(ingredient.name)"
            }
            deleting.remove(ingredient.id)
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

private struct IngredientsScreen: View {
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

@MainActor
final class OptimisticDeletionSpec: XCTestCase {
    private var window: UIWindow!
    private let original = ["ingredient.flour", "ingredient.eggs", "ingredient.milk"]

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        window = try XCTUnwrap(UIApplication.shared.keyWindow)
    }

    override func tearDown() async throws {
        window = nil
        try await super.tearDown()
    }

    private func ingredientIDs(_ host: FleetHostedView) -> [String] {
        host.mountedElementIDs.filter { $0.hasPrefix("ingredient.") }
    }

    private func requireVisibleError(_ host: FleetHostedView, _ text: String) throws {
        let error = try host.element("error")
        XCTAssertEqual(error.text, text)
        XCTAssertGreaterThan(error.frame.height, 0)
        XCTAssertTrue(host.hostingController.view.bounds.intersects(host.hostingController.view.convert(error.frame, from: nil)), "error is on screen")
    }

    private func run(mode: DeletionMode = .correct, _ body: @MainActor (FleetHostedView, IngredientsModel, FakeIngredientService) async throws -> Void) async throws {
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service, mode: mode)
        try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForElement("ingredient.milk")
            try await body(host, model, service)
        }
    }

    func test_deletion_removesRowBeforeResponse_thenSuccessKeepsItRemoved() async throws {
        try await run { host, model, service in
            XCTAssertEqual(ingredientIDs(host), original)
            let eggsBefore = try host.element("ingredient.eggs")
            XCTAssertEqual(eggsBefore.actions, ["Delete": true])
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitUntilStarted(service, "eggs")
            try await host.waitForElementRemoval("ingredient.eggs")
            XCTAssertTrue(service.isPending("eggs"), "response still unresolved while the row is gone")
            XCTAssertEqual(ingredientIDs(host), ["ingredient.flour", "ingredient.milk"])
            service.releaseSuccess("eggs")
            try await host.waitForElement("confirmation")  // rendered only after the response was handled
            XCTAssertEqual(try host.element("confirmation").text, "Deleted Eggs")
            XCTAssertFalse(model.deleting.contains("eggs"))
            XCTAssertEqual(ingredientIDs(host), ["ingredient.flour", "ingredient.milk"])
            XCTAssertThrowsError(try host.element("error"))
        }
    }

    func test_deletion_failureRestoresOriginalPositionWithVisibleError() async throws {
        try await run { host, _, service in
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitForElementRemoval("ingredient.eggs")
            XCTAssertTrue(service.isPending("eggs"))
            service.releaseFailure("eggs")
            try await host.waitForElement("ingredient.eggs")
            try await host.waitForElement("error")
            XCTAssertEqual(ingredientIDs(host), original)
            try requireVisibleError(host, "Could not delete Eggs")
        }
    }

    func test_mutation_deferringLocalUpdate_failsTheRemovalAssertion() async throws {
        try await run(mode: .deferLocalUpdate) { host, _, service in
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitUntilStarted(service, "eggs")
            do {
                try await host.waitForElementRemoval("ingredient.eggs", timeout: 0.3)
                XCTFail("row was removed before the response")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
                XCTAssertTrue(failure.description.contains("element 'ingredient.eggs' to be removed"), failure.description)
            }
        }
    }

    func test_mutation_brokenRollback_failsTheRestoreAssertion() async throws {
        try await run(mode: .noRollback) { host, _, service in
            try host.perform("Delete", onElement: "ingredient.eggs")
            try await host.waitForElementRemoval("ingredient.eggs")
            service.releaseFailure("eggs")
            do {
                try await host.waitForElement("ingredient.eggs", timeout: 0.3)
                XCTFail("row was restored")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .timedOut)
                XCTAssertTrue(failure.description.contains("element 'ingredient.eggs' to be mounted"), failure.description)
            }
        }
    }

    func test_actionRequests_failRecoverablyWithIdentityAndActionContext() async throws {
        try await run { host, _, service in
            @MainActor func failure(_ action: String, _ id: String) -> FleetFailure? {
                do { try host.perform(action, onElement: id) } catch let failure as FleetFailure { return failure } catch {}
                return nil
            }
            let missing = failure("Delete", "ingredient.sugar")
            XCTAssertEqual(missing?.kind, .invalidInput)
            XCTAssertTrue(missing?.target.contains("ingredient.sugar") == true)
            XCTAssertTrue(missing?.action.contains("Delete") == true)
            XCTAssertNotNil(missing?.source)
            let unsupported = failure("Archive", "ingredient.milk")
            XCTAssertEqual(unsupported?.kind, .invalidInput)
            XCTAssertTrue(unsupported?.state.contains("Delete") == true)
            // Disabled: a pending delete disables that row's action.
            try host.perform("Delete", onElement: "ingredient.milk")
            try await host.waitForElementRemoval("ingredient.milk")
            service.releaseFailure("milk")
            try await host.waitForElement("error")
            XCTAssertEqual(try host.element("ingredient.milk").actions, ["Delete": true])
        }
        // Ambiguous: two mounted elements share an identity.
        try await Fleet.withHostedView(VStack { Text("a").fleetElement("dup"); Text("b").fleetElement("dup") }, window: window) { host in
            try await host.waitUntilStillMounted(count: 2, id: "dup")
            XCTAssertThrowsError(try host.perform("Delete", onElement: "dup")) { error in
                let failure = error as? FleetFailure
                XCTAssertEqual(failure?.kind, .invalidInput)
                XCTAssertTrue(failure?.state.contains("2 mounted elements") == true)
            }
        }
        // Disabled.
        try await Fleet.withHostedView(Text("x").fleetElement("row", actions: [FleetElementAction("Delete", isEnabled: false) {}]), window: window) { host in
            try await host.waitForElement("row")
            XCTAssertThrowsError(try host.perform("Delete", onElement: "row")) { error in
                let failure = error as? FleetFailure
                XCTAssertEqual(failure?.kind, .unavailableInteraction)
                XCTAssertTrue(failure?.target.contains("row") == true)
            }
        }
    }

    func test_earlyFailure_releasesPendingContinuations_andNoLateResultReachesSuccessor() async throws {
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        struct Boom: Error {}
        do {
            try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
                try host.context.addCleanup { model.shutdown() }
                try await host.waitForElement("ingredient.eggs")
                try host.perform("Delete", onElement: "ingredient.eggs")
                try await host.waitUntilStarted(service, "eggs")
                throw Boom()
            }
            XCTFail("expected failure")
        } catch is Boom {}
        XCTAssertFalse(service.isPending("eggs"), "scope end released the pending continuation")
        // A successor scope with fresh state is untouched by the old request.
        let successorService = FakeIngredientService()
        let successor = IngredientsModel(service: successorService)
        try await Fleet.withHostedView(IngredientsScreen(model: successor), window: window) { host in
            try host.context.addCleanup { successor.shutdown() }
            try await host.waitForElement("ingredient.milk")
            try await host.waitForUpdate("yield for late results") { true }
            XCTAssertEqual(host.mountedElementIDs, original)
            XCTAssertNil(successor.errorMessage)
            XCTAssertEqual(model.ingredients.map(\.id), ["flour", "milk"], "old model ignores the cancelled response")
            XCTAssertNil(model.errorMessage)
        }
    }

    func test_cancellation_releasesPendingRequestAndObservers() async throws {
        let service = FakeIngredientService()
        let model = IngredientsModel(service: service)
        struct StartupTimeout: Error {}
        var finished = false
        let task = Task { @MainActor in
            defer { finished = true }
            try await Fleet.withHostedView(IngredientsScreen(model: model), window: window) { host in
                try host.context.addCleanup { model.shutdown() }
                try await host.waitForElement("ingredient.eggs")
                try host.perform("Delete", onElement: "ingredient.eggs")
                try await host.waitUntilStarted(service, "eggs")
                try await host.waitForUpdate("never", timeout: 30) { false }
            }
        }
        // Bounded wait for the request to start; a startup failure in the child surfaces here
        // instead of looping, and the child is always cancelled and awaited.
        let deadline = Date().addingTimeInterval(10)
        var startupFailure: Error?
        while !service.started.contains("eggs") {
            if Date() >= deadline { startupFailure = StartupTimeout(); break }
            if finished {
                do { try await task.value } catch { startupFailure = error }
                if startupFailure == nil { startupFailure = StartupTimeout() }
                break
            }
            await Task.yield()
        }
        if let startupFailure {
            task.cancel()
            _ = await task.result
            XCTFail("request never started: \(startupFailure)")
            return
        }
        task.cancel()
        do { try await task.value; XCTFail("expected cancellation") } catch is CancellationError {}
        XCTAssertFalse(service.isPending("eggs"))
        XCTAssertNil(model.errorMessage)
    }
}

@MainActor
private extension FleetHostedView {
    /// Bounded wait for the fake service to have received the request.
    func waitUntilStarted(_ service: FakeIngredientService, _ id: String) async throws {
        try await waitForUpdate("delete request for '\(id)' started") { service.started.contains(id) }
    }

    func waitUntilStillMounted(count: Int, id: String) async throws {
        try await waitForUpdate("\(count) elements '\(id)' mounted") { self.elements.records.filter { $0.id == id }.count == count }
    }
}
