import SwiftUI
import Testing
import UIKit
import Fleet
import ViewInspector

// MARK: - Failures

/// Distinct, recoverable outcomes of a scoped query. Absent, ambiguous, disabled and unsupported
/// targets never collapse into one another, and none of them is resolved by taking a first match.
enum ScopedQueryFailure: Error, Equatable, CustomStringConvertible {
    case absent(target: String, scope: String)
    case ambiguous(target: String, scope: String, count: Int)
    case disabled(target: String, scope: String)
    case unsupported(control: String, reason: String, recommendation: String)

    var description: String {
        switch self {
        case let .absent(target, scope): "\(target) is absent in \(scope)"
        case let .ambiguous(target, scope, count): "\(count) matches for \(target) in \(scope); expected exactly one"
        case let .disabled(target, scope): "\(target) in \(scope) is disabled"
        case let .unsupported(control, reason, recommendation): "\(control) is unsupported: \(reason). Try: \(recommendation)"
        }
    }
}

/// What each operation does. None of them is a physical touch.
enum ScopedActionKind: String, Equatable {
    case invokesClosure = "invokes the button's action closure"
    case mutatesBinding = "writes the control's binding"
    case submitsEditing = "invokes the onSubmit closure"
}

// MARK: - Adapter (test-side; ViewInspector never enters Fleet's package)

/// Resolves controls inside a scope that is itself resolved by an exact-one stable identifier.
///
/// Evidence level: ViewInspector reports the **declaration content of the mounted instance**
/// (`body` evaluated for the live `self`). That is neither proof of layout nor of visibility:
/// a lazily declared or offscreen child is found if it is declared, and a branch that is not
/// currently declared is absent. Handles are valid only inside the inspection body that produced
/// them. A retained handle is not an immutable snapshot: binding-backed reads (such as a text
/// field's `input()`) go through the live binding and return the current value, while the handle's
/// position in the declaration tree is whatever it was when read. Re-query inside a fresh inspection.
@MainActor
struct ScopedInspector {
    typealias Root = InspectableView<ViewType.ClassifiedView>
    let root: Root
    let scope: String

    init(_ root: Root, scope: String = "screen") {
        self.root = root
        self.scope = scope
    }

    /// Descends into the single container with this accessibility identifier.
    func container(_ identifier: String) throws -> ScopedInspector {
        let target = "container '\(identifier)'"
        let matches = root.findAll(where: { try $0.accessibilityIdentifier() == identifier })
        switch matches.count {
        case 1: return ScopedInspector(matches[0], scope: scope + " > '\(identifier)'")
        case 0: throw ScopedQueryFailure.absent(target: target, scope: scope)
        default: throw ScopedQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }

    func button(_ label: String) throws -> InspectableView<ViewType.Button> {
        try exactlyOne(ViewType.Button.self, "button '\(label)'") { try $0.labelView().text().string() == label }
    }

    func toggle(_ label: String) throws -> InspectableView<ViewType.Toggle> {
        try exactlyOne(ViewType.Toggle.self, "toggle '\(label)'") { try $0.labelView().text().string() == label }
    }

    func textField(_ title: String) throws -> InspectableView<ViewType.TextField> {
        try exactlyOne(ViewType.TextField.self, "text field '\(title)'") { try $0.labelView().text().string() == title }
    }

    func picker(_ label: String) throws -> InspectableView<ViewType.Picker> {
        try exactlyOne(ViewType.Picker.self, "picker '\(label)'") { try $0.labelView().text().string() == label }
    }

    @discardableResult
    func tap(_ label: String) throws -> ScopedActionKind {
        let button = try button(label)
        try requireEnabled(button, "button '\(label)'")
        try button.tap()
        return .invokesClosure
    }

    @discardableResult
    func setText(_ title: String, to value: String) throws -> ScopedActionKind {
        let field = try textField(title)
        try requireEnabled(field, "text field '\(title)'")
        try field.setInput(value)
        return .mutatesBinding
    }

    @discardableResult
    func submit(_ title: String) throws -> ScopedActionKind {
        let field = try textField(title)
        try requireEnabled(field, "text field '\(title)'")
        try field.callOnSubmit()
        return .submitsEditing
    }

    @discardableResult
    func set(toggle label: String, to value: Bool) throws -> ScopedActionKind {
        let toggle = try toggle(label)
        try requireEnabled(toggle, "toggle '\(label)'")
        if try toggle.isOn() != value { try toggle.tap() }
        return .mutatesBinding
    }

    @discardableResult
    func select<Value: Hashable>(_ value: Value, in label: String) throws -> ScopedActionKind {
        let picker = try picker(label)
        try requireEnabled(picker, "picker '\(label)'")
        try picker.select(value: value)
        return .mutatesBinding
    }

    /// Controls outside the tested matrix fail explicitly instead of being simulated.
    static func unsupported(_ control: String) -> ScopedQueryFailure {
        switch control {
        case "swipeAction", "contextMenu", "gesture":
            .unsupported(control: control, reason: "it requires gesture or presentation machinery that inspection cannot drive",
                         recommendation: "expose an explicit action through fleetElement(_:text:actions:) or use an XCUITest")
        case "renderedText", "visibility":
            .unsupported(control: control, reason: "inspection reports declaration content of the mounted instance, not rendered output",
                         recommendation: "observe the Fleet-owned hosting view or a fleetElement frame, or use a snapshot/XCUITest")
        default:
            .unsupported(control: control, reason: "it is outside the tested control matrix",
                         recommendation: "use fleetElement(_:text:actions:) for an explicit action, or an XCUITest for physical interaction")
        }
    }

    private func exactlyOne<T: BaseViewType>(
        _ type: T.Type, _ target: String, where match: @escaping (InspectableView<T>) throws -> Bool
    ) throws -> InspectableView<T> {
        let matches = root.findAll(type, where: match)
        switch matches.count {
        case 1: return matches[0]
        case 0: throw ScopedQueryFailure.absent(target: target, scope: scope)
        default: throw ScopedQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }

    private func requireEnabled<V>(_ view: InspectableView<V>, _ target: String) throws {
        if view.isDisabled() { throw ScopedQueryFailure.disabled(target: target, scope: scope) }
    }
}

// MARK: - Fixture: a recipe-shaped screen with repeated labels

@MainActor
final class ScopedPantryModel: ObservableObject {
    struct Item: Identifiable, Equatable {
        let id: String
        var name: String
        var amount: String
        var optional: Bool
        var locked = false
    }
    @Published var items = [
        Item(id: "flour", name: "Flour", amount: "500 g", optional: false),
        Item(id: "salt", name: "Salt", amount: "1 tsp", optional: true),
        Item(id: "yeast", name: "Yeast", amount: "7 g", optional: false, locked: true),
    ]
    @Published var showsNotes = false
    @Published var submitted: [String] = []
    @Published var removed: [String] = []
    @Published var unit = "metric"
}

struct ScopedPantryScreen: View {
    @ObservedObject var model: ScopedPantryModel
    let seam: InspectionSeam<ScopedPantryScreen>

    var body: some View {
        VStack {
            ForEach($model.items) { $item in
                HStack {
                    Text(item.name)
                    TextField("Amount", text: $item.amount)
                        .onSubmit { model.submitted.append(item.id) }
                        .disabled(item.locked)
                    Toggle("Optional", isOn: $item.optional)
                    Button("Remove") { model.removed.append(item.id) }
                        .disabled(item.locked)
                }
                .accessibilityIdentifier("row-\(item.id)")
            }
            Picker("Units", selection: $model.unit) {
                Text("Metric").tag("metric")
                Text("Imperial").tag("imperial")
            }
            ScrollView {
                LazyVStack {
                    ForEach(0..<40, id: \.self) { index in
                        Text("Lazy \(index)").accessibilityIdentifier("lazy-\(index)")
                    }
                }
            }
            .frame(height: 44)
            if model.showsNotes {
                Button("Remove") { model.removed.append("notes") }
                    .accessibilityIdentifier("notes")
            }
        }
        .onReceive(seam.notice) { seam.visit(self) }
    }
}

@MainActor
private func inspectPantry<T>(
    _ seam: InspectionSeam<ScopedPantryScreen>, in context: FleetTestContext, timeout: TimeInterval = 2,
    _ body: @escaping @MainActor (ScopedInspector) throws -> T
) async throws -> T {
    var value: T?
    var failure: Error?
    try await context.waitUntil("mounted ScopedPantryScreen to answer inspection", timeout: timeout) {
        seam.run { view in
            do { value = try body(ScopedInspector(try view.inspect())) } catch { failure = error }
        }
    }
    if let failure { throw failure }
    return value!
}

@MainActor
private func expectFailure(_ expected: ScopedQueryFailure, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(expected)") } catch let failure as ScopedQueryFailure {
        #expect(failure == expected)
    } catch { Issue.record("unexpected error \(error)") }
}

// MARK: - Tests

@MainActor
@Suite("Row-scoped ViewInspector queries (Swift Testing)")
struct ScopedInspectionTests {
    private func host(_ model: ScopedPantryModel, _ seam: InspectionSeam<ScopedPantryScreen>,
                      _ body: @MainActor (FleetTestContext) async throws -> Void) async throws {
        let window = try #require(UIApplication.shared.keyWindow)
        try await Fleet.withContext(window: window) { context in
            try await context.setRoot(UIHostingController(rootView: ScopedPantryScreen(model: model, seam: seam)))
            try await body(context)
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func repeatedLabelsAreAmbiguousUnscopedAndUniqueWhenRowScoped() async throws {
        let model = ScopedPantryModel()
        let seam = InspectionSeam<ScopedPantryScreen>()
        try await host(model, seam) { context in
            try await inspectPantry(seam, in: context) { screen in
                expectFailure(.ambiguous(target: "button 'Remove'", scope: "screen", count: 3)) { try screen.button("Remove") }
                let kind = try screen.container("row-salt").tap("Remove")
                #expect(kind == .invokesClosure)
            }
            #expect(model.removed == ["salt"])
        }
    }

    @Test func absentAmbiguousDisabledAndUnsupportedStayDistinct() async throws {
        let model = ScopedPantryModel()
        let seam = InspectionSeam<ScopedPantryScreen>()
        try await host(model, seam) { context in
            try await inspectPantry(seam, in: context) { screen in
                expectFailure(.absent(target: "container 'row-sugar'", scope: "screen")) { _ = try screen.container("row-sugar") }
                let yeast = try screen.container("row-yeast")
                expectFailure(.disabled(target: "button 'Remove'", scope: "screen > 'row-yeast'")) { try yeast.tap("Remove") }
                expectFailure(.absent(target: "button 'Add'", scope: "screen > 'row-yeast'")) { _ = try yeast.button("Add") }
                let unsupported = ScopedInspector.unsupported("swipeAction")
                if case let .unsupported(_, _, recommendation) = unsupported { #expect(recommendation.contains("XCUITest")) }
            }
            #expect(model.removed.isEmpty)
        }
    }

    @Test func textToggleAndSelectionActionsReportWhatTheyDo() async throws {
        let model = ScopedPantryModel()
        let seam = InspectionSeam<ScopedPantryScreen>()
        try await host(model, seam) { context in
            try await inspectPantry(seam, in: context) { screen in
                let row = try screen.container("row-flour")
                #expect(try row.setText("Amount", to: "600 g") == .mutatesBinding)
                #expect(try row.submit("Amount") == .submitsEditing)
                #expect(try row.set(toggle: "Optional", to: true) == .mutatesBinding)
                #expect(try screen.select("imperial", in: "Units") == .mutatesBinding)
                expectFailure(.disabled(target: "text field 'Amount'", scope: "screen > 'row-yeast'")) {
                    try screen.container("row-yeast").setText("Amount", to: "1 g")
                }
            }
            #expect(model.submitted == ["flour"])
            try await context.waitUntil("bindings written to the model") {
                model.items[0].amount == "600 g" && model.items[0].optional && model.unit == "imperial"
            }
            // Only the targeted row changed.
            #expect(model.items[1].amount == "1 tsp")
        }
    }

    @Test func conditionalBranchesAndStaleHandlesFollowTheCurrentDeclaration() async throws {
        let model = ScopedPantryModel()
        let seam = InspectionSeam<ScopedPantryScreen>()
        try await host(model, seam) { context in
            // The branch is not declared yet, so it is absent rather than hidden.
            try await inspectPantry(seam, in: context) { screen in
                expectFailure(.absent(target: "container 'notes'", scope: "screen")) { _ = try screen.container("notes") }
            }
            // Retain the actual handle (not a copied value) before the state changes.
            var retained: InspectableView<ViewType.TextField>?
            try await inspectPantry(seam, in: context) { screen in
                retained = try screen.container("row-flour").textField("Amount")
                #expect(try retained?.input() == "500 g")
            }
            model.showsNotes = true
            model.items[0].amount = "750 g"
            try await context.waitUntil("conditional branch to be declared") {
                var declared = false
                _ = seam.run { view in declared = (try? ScopedInspector(view.inspect()).container("notes")) != nil }
                return declared
            }
            try await inspectPantry(seam, in: context) { screen in
                _ = try screen.container("notes")
                // Re-querying sees the live declaration.
                #expect(try screen.container("row-flour").textField("Amount").input() == "750 g")
            }
            // A retained handle is not an immutable snapshot: binding-backed reads return the live value.
            #expect(try retained?.input() == "750 g")
        }
    }

    @Test func lazyOffscreenContentIsFoundAsDeclarationAndRenderedClaimsAreUnsupported() async throws {
        let model = ScopedPantryModel()
        let seam = InspectionSeam<ScopedPantryScreen>()
        try await host(model, seam) { context in
            try await inspectPantry(seam, in: context) { screen in
                // The scroll view is 44 points tall, so "lazy-39" is far offscreen. Finding it only
                // shows it is declared in the mounted instance, not that it is realized or visible.
                _ = try screen.container("lazy-39")
                _ = try screen.container("lazy-0")
                expectFailure(.absent(target: "container 'lazy-40'", scope: "screen")) { _ = try screen.container("lazy-40") }
                let visibility = ScopedInspector.unsupported("visibility")
                guard case let .unsupported(_, reason, recommendation) = visibility else { Issue.record("expected unsupported"); return }
                #expect(reason.contains("not rendered"))
                #expect(recommendation.contains("snapshot"))
            }
        }
    }
}
