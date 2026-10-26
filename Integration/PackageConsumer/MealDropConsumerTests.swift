#if os(iOS)
import Combine
import SwiftUI
import UIKit
import XCTest
import Fleet

// A Fleet-owned, representative meal-planner transfer fixture. It uses fake transfer data and only public Fleet APIs.
// It is NOT Reciplan's code: see Documentation/MealDropFixture.md for what is application-owned and what is not covered.

// MARK: Fake transfer data and application-owned rules

struct MealPayload: Equatable {
    var id: String
    var title: String
    /// Only "meal" payloads are supported; anything else is rejected before any mutation.
    var kind = "meal"
}

struct MealSlot: Equatable, Hashable {
    var week: Int
    var day: Int
}

enum DropRejection: Error, Equatable {
    case unsupportedPayload(kind: String)
    case invalidDestination(MealSlot)
    case sourceMissing(MealSlot)
    case duplicate(id: String, MealSlot)
    case serviceFailed
}

/// What a helper actually did. A direct handler call is never reported as physical drag delivery.
enum DropCoverage: Equatable {
    /// Only the application's validation rules were evaluated.
    case intentValidated
    /// The application's drop handler was invoked directly.
    case handlerInvoked
    /// Real drag delivery, hover or autoscroll was observed. No helper in this file can produce it; see XCUITest.
    case physicalRoutingObserved
}

enum DropOutcome: Equatable {
    case accepted
    case rejected(DropRejection)
    case cancelled
}

struct DropReport: Equatable {
    let coverage: DropCoverage
    let outcome: DropOutcome
}

enum FakeServiceMode: Sendable { case succeed, fail, hang }

@MainActor
final class FakeMealService {
    var mode = FakeServiceMode.succeed
    private(set) var commits = 0
    private(set) var started = 0
    private(set) var observedCancellations = 0

    func commit() async throws {
        started += 1
        switch mode {
        case .succeed: commits += 1
        case .fail: throw DropRejection.serviceFailed
        case .hang:
            do {
                while true { try await Task.sleep(nanoseconds: 5_000_000) }
            } catch {
                observedCancellations += 1
                throw error
            }
        }
    }
}

@MainActor
final class MealPlanModel: ObservableObject {
    static let daysPerWeek = 7
    @Published private(set) var plan: [MealSlot: [MealPayload]]
    @Published var visibleWeek = 0
    let service = FakeMealService()
    private(set) var mutations = 0

    init(plan: [MealSlot: [MealPayload]]) { self.plan = plan }

    func meals(in slot: MealSlot) -> [MealPayload] { plan[slot] ?? [] }

    /// Pure validation: no mutation, no service call.
    func validate(_ payload: MealPayload, from source: MealSlot, to destination: MealSlot) -> DropRejection? {
        guard payload.kind == "meal" else { return .unsupportedPayload(kind: payload.kind) }
        guard (0..<Self.daysPerWeek).contains(destination.day), destination.week >= 0 else { return .invalidDestination(destination) }
        guard meals(in: source).contains(where: { $0.id == payload.id }) else { return .sourceMissing(source) }
        guard !meals(in: destination).contains(where: { $0.id == payload.id }) else { return .duplicate(id: payload.id, destination) }
        return nil
    }

    /// The application-owned drop handler: validate, await the service, then mutate only if not cancelled.
    func drop(_ payload: MealPayload, from source: MealSlot, to destination: MealSlot) async -> DropOutcome {
        if let rejection = validate(payload, from: source, to: destination) { return .rejected(rejection) }
        do { try await service.commit() } catch is CancellationError { return .cancelled } catch { return .rejected(.serviceFailed) }
        guard !Task.isCancelled else { return .cancelled }
        var next = plan
        next[source] = meals(in: source).filter { $0.id != payload.id }
        next[destination] = meals(in: destination) + [payload]
        plan = next
        mutations += 1
        return .accepted
    }
}

// MARK: UIKit week screen

final class MealWeekController: UIViewController {
    static let marker = "fleet.meal-week"
    private let model: MealPlanModel
    private let stack = UIStackView()
    private var subscriptions: Set<AnyCancellable> = []
    private(set) var dayLabels: [UILabel] = []

    init(model: MealPlanModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        restorationIdentifier = Self.marker
    }
    required init?(coder: NSCoder) { fatalError("unused") }

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.axis = .vertical
        stack.frame = view.bounds
        stack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stack)
        for day in 0..<MealPlanModel.daysPerWeek {
            let label = UILabel()
            label.accessibilityIdentifier = "day-\(day)"
            dayLabels.append(label)
            stack.addArrangedSubview(label)
        }
        render()
        model.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
            // objectWillChange fires before the value is stored; render on the next main-queue turn.
            DispatchQueue.main.async { self?.render() }
        }.store(in: &subscriptions)
    }

    func render() {
        for (day, label) in dayLabels.enumerated() {
            let titles = model.meals(in: MealSlot(week: model.visibleWeek, day: day)).map(\.title)
            label.text = "\(day): " + titles.joined(separator: ",")
        }
    }
}

struct MealWeekView: UIViewControllerRepresentable {
    let model: MealPlanModel
    func makeUIViewController(context: Context) -> MealWeekController { MealWeekController(model: model) }
    func updateUIViewController(_ controller: MealWeekController, context: Context) {}
}

// MARK: Drivers that say what they covered

@MainActor
enum MealDropDriver {
    /// Evaluates only the application's rules. Never calls the drop handler.
    static func validateIntent(_ model: MealPlanModel, _ payload: MealPayload, from: MealSlot, to: MealSlot) -> DropReport {
        DropReport(coverage: .intentValidated, outcome: model.validate(payload, from: from, to: to).map { .rejected($0) } ?? .accepted)
    }

    /// Calls the application's handler directly. This is NOT drag delivery, hover or autoscroll.
    static func invokeHandler(_ model: MealPlanModel, _ payload: MealPayload, from: MealSlot, to: MealSlot) async -> DropReport {
        DropReport(coverage: .handlerInvoked, outcome: await model.drop(payload, from: from, to: to))
    }
}

// MARK: Tests

@MainActor
final class MealDropFixtureTests: XCTestCase {
    private let pasta = MealPayload(id: "m1", title: "Pasta")
    private let soup = MealPayload(id: "m2", title: "Soup")
    private func slot(_ day: Int, week: Int = 0) -> MealSlot { MealSlot(week: week, day: day) }

    private func makeModel() -> MealPlanModel {
        MealPlanModel(plan: [slot(0): [pasta], slot(1): [soup], slot(2, week: 1): []])
    }

    private func withScreen(_ model: MealPlanModel, _ body: @MainActor (FleetHostedView, MealWeekController) async throws -> Void) async throws {
        let window = try XCTUnwrap(UIApplication.shared.keyWindow)
        try await Fleet.withHostedView(MealWeekView(model: model), window: window) { host in
            var found: MealWeekController?
            func visit(_ controller: UIViewController) {
                if let typed = controller as? MealWeekController { found = typed }
                controller.children.forEach(visit)
            }
            try await host.waitForUpdate("week controller present") { visit(host.hostingController); return found != nil }
            let controller = try XCTUnwrap(found)
            try await host.waitForUpdate("week rendered") { controller.dayLabels.first?.text == "0: Pasta" }
            try await body(host, controller)
        }
    }

    func test_validTransfer_updatesHostedSourceAndDestination() async throws {
        let model = makeModel()
        try await withScreen(model) { host, screen in
            let report = await MealDropDriver.invokeHandler(model, pasta, from: slot(0), to: slot(3))
            XCTAssertEqual(report, DropReport(coverage: .handlerInvoked, outcome: .accepted))
            XCTAssertNotEqual(report.coverage, .physicalRoutingObserved)
            try await host.waitForUpdate("moved meal rendered") { screen.dayLabels[3].text == "3: Pasta" && screen.dayLabels[0].text == "0: " }
            XCTAssertEqual(model.mutations, 1)
        }
    }

    func test_adjacentWeekTransition_movesMealOnlyAfterWeekChange() async throws {
        let model = makeModel()
        try await withScreen(model) { host, screen in
            let report = await MealDropDriver.invokeHandler(model, pasta, from: slot(0), to: slot(2, week: 1))
            XCTAssertEqual(report.outcome, .accepted)
            try await host.waitForUpdate("source emptied on current week") { screen.dayLabels[0].text == "0: " }
            XCTAssertEqual(screen.dayLabels[2].text, "2: ")
            model.visibleWeek = 1
            try await host.waitForUpdate("next week shows moved meal") { screen.dayLabels[2].text == "2: Pasta" }
        }
    }

    func test_rejectedTransfers_leaveStateUnchanged() async throws {
        let model = makeModel()
        let cases: [(MealPayload, MealSlot, MealSlot, DropRejection)] = [
            (pasta, slot(0), slot(9), .invalidDestination(slot(9))),
            (pasta, slot(0), slot(-1), .invalidDestination(slot(-1))),
            (MealPayload(id: "x", title: "Photo", kind: "image"), slot(0), slot(3), .unsupportedPayload(kind: "image")),
            (soup, slot(0), slot(3), .sourceMissing(slot(0))),
        ]
        try await withScreen(model) { host, screen in
            let before = model.plan
            for (payload, from, to, expected) in cases {
                let intent = MealDropDriver.validateIntent(model, payload, from: from, to: to)
                XCTAssertEqual(intent, DropReport(coverage: .intentValidated, outcome: .rejected(expected)))
                let report = await MealDropDriver.invokeHandler(model, payload, from: from, to: to)
                XCTAssertEqual(report, DropReport(coverage: .handlerInvoked, outcome: .rejected(expected)))
            }
            XCTAssertEqual(model.plan, before)
            XCTAssertEqual(model.mutations, 0)
            XCTAssertEqual(model.service.started, 0, "rejection must happen before the service is called")
            XCTAssertEqual(screen.dayLabels[0].text, "0: Pasta")
        }
    }

    func test_duplicatePayload_isRejectedWithoutMutation() async throws {
        let model = MealPlanModel(plan: [slot(0): [pasta], slot(3): [pasta]])
        let report = await MealDropDriver.invokeHandler(model, pasta, from: slot(0), to: slot(3))
        XCTAssertEqual(report.outcome, .rejected(.duplicate(id: "m1", slot(3))))
        XCTAssertEqual(model.mutations, 0)
        XCTAssertEqual(model.meals(in: slot(0)), [pasta])
    }

    func test_failedAsyncAcceptance_doesNotMutate() async throws {
        let model = makeModel()
        model.service.mode = .fail
        try await withScreen(model) { _, screen in
            let report = await MealDropDriver.invokeHandler(model, pasta, from: slot(0), to: slot(3))
            XCTAssertEqual(report.outcome, .rejected(.serviceFailed))
            XCTAssertEqual(model.mutations, 0)
            XCTAssertEqual(model.meals(in: slot(0)), [pasta])
            XCTAssertEqual(screen.dayLabels[3].text, "3: ")
        }
    }

    func test_cancellationDuringAcceptance_cleansUpLateWorkWithoutMutation() async throws {
        let model = makeModel()
        model.service.mode = .hang
        try await withScreen(model) { host, screen in
            let task = Task { @MainActor in await MealDropDriver.invokeHandler(model, pasta, from: slot(0), to: slot(3)) }
            try await host.waitForUpdate("service call started") { model.service.started == 1 }
            task.cancel()
            let report = await task.value
            XCTAssertEqual(report, DropReport(coverage: .handlerInvoked, outcome: .cancelled))
            XCTAssertEqual(model.service.observedCancellations, 1, "in-flight service work must observe cancellation")
            XCTAssertEqual(model.mutations, 0)
            XCTAssertEqual(screen.dayLabels[0].text, "0: Pasta")
        }
    }
}

#endif
