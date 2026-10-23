import SwiftUI
import Testing
import UIKit
import XCTest
import Fleet

// A recipe-shaped, application-owned fixture: an injected clock/calendar/time zone, a controllable
// household event stream and a fake service held at explicit checkpoints. Fleet supplies only the
// hosted screen, its lifecycle, bounded waits and observed-task cancellation; the clock, the stream,
// the service and the conflict policy below belong to the application. The conflict policy is a
// fixture choice, not a rule Fleet or the example recommends for every product. The fixture does not
// certify any downstream application.

/// Application-owned clock input. Nothing reads the process clock or the process time zone.
@MainActor
final class PlanClock: ObservableObject {
    @Published private(set) var now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }

    private func formatted(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    var todayText: String { "Today: " + formatted(now, "yyyy-MM-dd EEEE") }
    var weekText: String {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return "Week of " + formatted(start, "yyyy-MM-dd")
    }
}

struct HouseholdEvent: Sendable, Equatable {
    let day: String
    let meal: String
    let author: String
}

/// Application-owned controllable stream. The test decides when (and whether) events arrive.
final class HouseholdEventStream: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [Int: AsyncStream<HouseholdEvent>.Continuation] = [:]
    private var nextID = 0

    func subscribe() -> AsyncStream<HouseholdEvent> {
        AsyncStream { continuation in
            lock.lock()
            let id = nextID
            nextID += 1
            continuations[id] = continuation
            lock.unlock()
            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }

    var activeSubscriptions: Int {
        lock.lock()
        defer { lock.unlock() }
        return continuations.count
    }

    /// Returns how many live subscribers received the event.
    @discardableResult
    func send(_ event: HouseholdEvent) -> Int {
        lock.lock()
        let targets = Array(continuations.values)
        lock.unlock()
        targets.forEach { $0.yield(event) }
        return targets.count
    }
}

/// Fake service: a save stays pending until the test releases it; cancellation and `shutdown()` release it.
@MainActor
final class FakeMealService {
    struct ServiceError: Error {}
    private(set) var started: [String] = []
    private var pending: [String: CheckedContinuation<Void, Error>] = [:]

    func save(_ day: String, _ meal: String) async throws {
        started.append(day)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending[day] = $0 }
        } onCancel: {
            Task { @MainActor in self.release(day, with: CancellationError()) }
        }
    }

    var pendingCount: Int { pending.count }
    func isPending(_ day: String) -> Bool { pending[day] != nil }
    func releaseSuccess(_ day: String) { pending.removeValue(forKey: day)?.resume() }
    func releaseFailure(_ day: String) { release(day, with: ServiceError()) }
    func shutdown() { for day in Array(pending.keys) { release(day, with: CancellationError()) } }
    private func release(_ day: String, with error: Error) { pending.removeValue(forKey: day)?.resume(throwing: error) }
}

/// What a failed save does when the household changed in the meantime. A fixture choice.
enum HouseholdConflictPolicy {
    /// Restore only the entry this save changed, and only if nobody else changed it since.
    case keepNewerHouseholdChange
    /// Simplistic rollback to the whole snapshot taken when the save started (loses later changes).
    case restoreSnapshot
}

@MainActor
final class HouseholdPlanModel: ObservableObject {
    static let dayNames = ["mon": "Monday", "tue": "Tuesday"]
    @Published var meals = ["mon": "Soup", "tue": "Pasta"]
    @Published var notice: String?
    let clock: PlanClock
    let events: HouseholdEventStream
    let service: FakeMealService
    let policy: HouseholdConflictPolicy
    private var remoteRevisions: [String: Int] = [:]
    private var tasks: [Task<Void, Never>] = []
    private var isActive = true

    init(clock: PlanClock, events: HouseholdEventStream, service: FakeMealService, policy: HouseholdConflictPolicy = .keepNewerHouseholdChange) {
        self.clock = clock
        self.events = events
        self.service = service
        self.policy = policy
    }

    /// Optimistic: the screen shows the new meal immediately; the save is still pending.
    func set(_ day: String, to meal: String) {
        guard isActive, let previous = meals[day] else { return }
        let snapshot = meals
        let baseRevision = remoteRevisions[day, default: 0]
        notice = nil
        meals[day] = meal
        tasks.append(Task { [weak self] in
            guard let self else { return }
            do {
                try await service.save(day, meal)
                guard isActive else { return }
                notice = "Saved \(Self.dayNames[day] ?? day)"
            } catch {
                guard isActive, !Task.isCancelled else { return }
                let name = Self.dayNames[day] ?? day
                switch policy {
                case .restoreSnapshot:
                    meals = snapshot
                    notice = "Could not save \(name); restored earlier plan"
                case .keepNewerHouseholdChange:
                    if remoteRevisions[day, default: 0] == baseRevision {
                        meals[day] = previous
                        notice = "Could not save \(name); restored \(previous)"
                    } else {
                        notice = "Could not save \(name); kept the newer household change"
                    }
                }
            }
        })
    }

    func apply(_ event: HouseholdEvent) {
        guard isActive, meals[event.day] != nil else { return }
        meals[event.day] = event.meal
        remoteRevisions[event.day, default: 0] += 1
    }

    func listen() async {
        for await event in events.subscribe() { apply(event) }
    }

    /// Ends this screen's work: later events and responses are ignored and pending fake requests are released.
    func shutdown() {
        isActive = false
        tasks.forEach { $0.cancel() }
        tasks = []
        service.shutdown()
    }
}

struct HouseholdPlanScreen: View {
    @ObservedObject var model: HouseholdPlanModel
    @ObservedObject var clock: PlanClock

    init(model: HouseholdPlanModel) {
        self.model = model
        self.clock = model.clock
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(clock.todayText).fleetElement("today", text: clock.todayText)
            Text(clock.weekText).fleetElement("week", text: clock.weekText)
            if let notice = model.notice {
                Text(notice).fleetElement("notice", text: notice)
            }
            ForEach(["mon", "tue"], id: \.self) { day in
                let text = "\(HouseholdPlanModel.dayNames[day] ?? day): \(model.meals[day] ?? "")"
                Text(text).frame(height: 44).fleetElement("meal.\(day)", text: text)
            }
            Spacer()
        }
        .fleetObservedTask("household-events") { await model.listen() }
        .onDisappear { model.shutdown() }
    }
}

enum HouseholdFixture {
    /// The fixed instant 2026-10-25 23:30 America/Los_Angeles (06:30 UTC on Monday the 26th), rendered
    /// with a calendar in the given zone; weeks start on Monday.
    @MainActor
    static func makeClock(zone: String = "America/Los_Angeles") -> PlanClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        var instantCalendar = Calendar(identifier: .gregorian)
        instantCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = instantCalendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 30))!
        return PlanClock(now: now, calendar: calendar)
    }

    /// Bounded wait for the mounted element's rendered text.
    @MainActor
    static func waitForText(_ host: FleetHostedView, _ id: String, _ text: String) async throws {
        try await host.waitForUpdate("element '\(id)' to show '\(text)'") { (try? host.element(id).text) == text }
    }
}

// household-plan-xctest:begin
@MainActor
final class HouseholdPlanXCTestStarter: XCTestCase {
    private var window: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        window = try XCTUnwrap(UIApplication.shared.keyWindow)
    }

    override func tearDown() async throws {
        window = nil
        try await super.tearDown()
    }

    func test_injectedClock_showsDayAndWeekAcrossBoundary_withoutChangingProcessTimeZone() async throws {
        let processZone = TimeZone.current
        let defaultZone = NSTimeZone.default
        let clock = HouseholdFixture.makeClock()
        let model = HouseholdPlanModel(clock: clock, events: HouseholdEventStream(), service: FakeMealService())
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await HouseholdFixture.waitForText(host, "today", "Today: 2026-10-25 Sunday")
            XCTAssertEqual(try host.element("week").text, "Week of 2026-10-19")
            clock.advance(by: 30 * 60)  // crosses local midnight into the next week
            try await HouseholdFixture.waitForText(host, "today", "Today: 2026-10-26 Monday")
            XCTAssertEqual(try host.element("week").text, "Week of 2026-10-26")
        }
        // The same instant under another injected zone is already Monday, with no global zone change.
        let utcModel = HouseholdPlanModel(clock: HouseholdFixture.makeClock(zone: "UTC"), events: HouseholdEventStream(), service: FakeMealService())
        try await Fleet.withHostedView(HouseholdPlanScreen(model: utcModel), window: window) { host in
            try host.context.addCleanup { utcModel.shutdown() }
            try await HouseholdFixture.waitForText(host, "today", "Today: 2026-10-26 Monday")
            XCTAssertEqual(try host.element("week").text, "Week of 2026-10-26")
        }
        XCTAssertEqual(TimeZone.current, processZone)
        XCTAssertEqual(NSTimeZone.default, defaultZone)
    }

    func test_remoteUpdateToSameDay_survivesFailedOriginalSave() async throws {
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForTaskStart("household-events")
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }

            model.set("mon", to: "Curry")  // local operation; its save stays pending
            try await HouseholdFixture.waitForText(host, "meal.mon", "Monday: Curry")
            XCTAssertTrue(service.isPending("mon"))

            events.send(HouseholdEvent(day: "mon", meal: "Tacos", author: "Sam"))
            try await HouseholdFixture.waitForText(host, "meal.mon", "Monday: Tacos")

            service.releaseFailure("mon")
            try await host.waitForElement("notice")
            XCTAssertEqual(try host.element("notice").text, "Could not save Monday; kept the newer household change")
            XCTAssertEqual(try host.element("meal.mon").text, "Monday: Tacos")
            XCTAssertEqual(try host.element("meal.tue").text, "Tuesday: Pasta")
        }
    }

    func test_failedSave_restoresOnlyItsOwnEntry_whenAnotherDayChanged() async throws {
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }
            model.set("mon", to: "Curry")
            events.send(HouseholdEvent(day: "tue", meal: "Pizza", author: "Sam"))
            try await HouseholdFixture.waitForText(host, "meal.tue", "Tuesday: Pizza")
            service.releaseFailure("mon")
            try await HouseholdFixture.waitForText(host, "meal.mon", "Monday: Soup")
            XCTAssertEqual(try host.element("meal.tue").text, "Tuesday: Pizza")
            XCTAssertEqual(try host.element("notice").text, "Could not save Monday; restored Soup")
        }
    }

    func test_mutation_snapshotRollback_overwritesLaterHouseholdChange() async throws {
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service, policy: .restoreSnapshot)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }
            model.set("mon", to: "Curry")
            events.send(HouseholdEvent(day: "tue", meal: "Pizza", author: "Sam"))
            try await HouseholdFixture.waitForText(host, "meal.tue", "Tuesday: Pizza")
            service.releaseFailure("mon")
            try await HouseholdFixture.waitForText(host, "meal.mon", "Monday: Soup")
            // The simplistic policy loses the later change; the screen assertion exposes it.
            XCTAssertEqual(try host.element("meal.tue").text, "Tuesday: Pasta")
        }
    }

    func test_departure_cancelsSubscription_andLateEventsAndResponsesCannotMutateAnyScreen() async throws {
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }
            model.set("mon", to: "Curry")
            try await host.waitForUpdate("save started") { service.isPending("mon") }

            try await host.remove()
            try await host.waitForTaskCancellation("household-events")
            try await host.waitForUpdate("subscription released") { events.activeSubscriptions == 0 }
            XCTAssertEqual(service.pendingCount, 0, "departure released the pending fake continuation")
        }
        // Late arrivals after departure: no subscriber, no pending request, discarded state untouched.
        XCTAssertEqual(events.send(HouseholdEvent(day: "mon", meal: "Late", author: "Sam")), 0)
        service.releaseFailure("mon")
        XCTAssertEqual(model.meals["mon"], "Curry")
        XCTAssertNil(model.notice)

        // A successor screen on its own stream and service is unaffected by the old ones.
        let successorEvents = HouseholdEventStream()
        let successor = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: successorEvents, service: FakeMealService())
        try await Fleet.withHostedView(HouseholdPlanScreen(model: successor), window: window) { host in
            try host.context.addCleanup { successor.shutdown() }
            try await host.waitForUpdate("one subscription") { successorEvents.activeSubscriptions == 1 }
            XCTAssertEqual(events.send(HouseholdEvent(day: "mon", meal: "Stale", author: "Sam")), 0)
            XCTAssertEqual(events.activeSubscriptions, 0)
            XCTAssertEqual(try host.element("meal.mon").text, "Monday: Soup")
            XCTAssertNil(successor.notice)
        }
    }
}
// household-plan-xctest:end

// household-plan-swift-testing:begin
@MainActor
@Suite("Household plan starter")
struct HouseholdPlanSwiftTestingStarter {
    @Test func remoteUpdateSurvivesFailedOriginalSave() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }
            model.set("mon", to: "Curry")
            events.send(HouseholdEvent(day: "mon", meal: "Tacos", author: "Sam"))
            try await HouseholdFixture.waitForText(host, "meal.mon", "Monday: Tacos")
            service.releaseFailure("mon")
            try await host.waitForElement("notice")
            #expect(try host.element("meal.mon").text == "Monday: Tacos")
            #expect(try host.element("notice").text == "Could not save Monday; kept the newer household change")
        }
    }

    @Test func departureCancelsSubscriptionAndReleasesPendingSave() async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        let service = FakeMealService()
        let events = HouseholdEventStream()
        let model = HouseholdPlanModel(clock: HouseholdFixture.makeClock(), events: events, service: service)
        try await Fleet.withHostedView(HouseholdPlanScreen(model: model), window: window) { host in
            try host.context.addCleanup { model.shutdown() }
            try await host.waitForUpdate("one subscription") { events.activeSubscriptions == 1 }
            model.set("tue", to: "Pizza")
            try await host.waitForUpdate("save started") { service.isPending("tue") }
            try await host.remove()
            try await host.waitForTaskCancellation("household-events")
            try await host.waitForUpdate("subscription released") { events.activeSubscriptions == 0 }
            #expect(service.pendingCount == 0)
        }
        #expect(events.send(HouseholdEvent(day: "tue", meal: "Late", author: "Sam")) == 0)
        #expect(model.meals["tue"] == "Pizza")
    }
}
// household-plan-swift-testing:end
