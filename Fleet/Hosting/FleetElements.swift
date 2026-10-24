import SwiftUI
import UIKit

/// Where a declared action is offered. This is the bounded matrix of contextual surfaces Fleet
/// can address; anything else (long-press previews, drag, custom gestures) is not representable.
///
/// Selecting a surface selects a declared handler only. It does not present or observe a menu,
/// reveal a swipe row, or deliver a gesture.
public enum FleetActionSurface: String, Sendable, Equatable, CaseIterable {
    /// A control in the row itself, such as a trailing "Delete" button.
    case control
    /// A `swipeActions` entry on the row.
    case swipeAction
    /// A `contextMenu` command on the row.
    case contextMenu
}

/// A named action a mounted element offers, for example a row's "Delete".
///
/// `perform` should be the very closure the element's own control runs, so a request through
/// ``FleetHostedView/perform(_:onElement:fileID:line:)`` operates the screen's code rather than a
/// parallel path. `isEnabled` mirrors whether the control is currently enabled.
public struct FleetElementAction: Sendable {
    public let name: String
    public let isEnabled: Bool
    /// The surface the screen offers this action on. Defaults to `.control`.
    public let surface: FleetActionSurface
    /// Whether the screen declares the action as destructive (for example `role: .destructive`).
    public let isDestructive: Bool
    let perform: @MainActor @Sendable () -> Void

    public init(
        _ name: String, surface: FleetActionSurface = .control, isDestructive: Bool = false, isEnabled: Bool = true,
        perform: @escaping @MainActor @Sendable () -> Void
    ) {
        self.name = name
        self.surface = surface
        self.isDestructive = isDestructive
        self.isEnabled = isEnabled
        self.perform = perform
    }
}

/// One declared action as observed on a mounted element.
public struct FleetActionObservation: Sendable, Equatable {
    public let name: String
    public let surface: FleetActionSurface
    public let isEnabled: Bool
    public let isDestructive: Bool
}

/// What Fleet observed for one mounted, identified element of the hosted screen.
public struct FleetElementObservation: Sendable, Equatable {
    public let id: String
    /// The text the screen declared for the element, if any.
    public let text: String?
    /// The element's frame in the window's coordinate space, from the laid-out SwiftUI hierarchy.
    public let frame: CGRect
    /// Offered action names mapped to whether each is enabled.
    public let actions: [String: Bool]
    /// Every declared action with its surface, availability and destructive flag, in declaration order.
    public let declaredActions: [FleetActionObservation]
}

struct FleetElementRecord: Sendable {
    let token: UUID
    let id: String
    let text: String?
    let frame: CGRect
    let actions: [FleetElementAction]

    var observation: FleetElementObservation {
        FleetElementObservation(id: id, text: text, frame: frame, actions: Dictionary(actions.map { ($0.name, $0.isEnabled) }, uniquingKeysWith: { first, _ in first }),
            declaredActions: actions.map { FleetActionObservation(name: $0.name, surface: $0.surface, isEnabled: $0.isEnabled, isDestructive: $0.isDestructive) })
    }
}

/// Equality is deliberately never true: action closures cannot be compared, and a stale closure
/// must never be kept, so every preference pass delivers the freshest records.
struct FleetElementSnapshot: Sendable, Equatable {
    var records: [FleetElementRecord] = []
    static func == (lhs: FleetElementSnapshot, rhs: FleetElementSnapshot) -> Bool { false }
}

private struct FleetElementKey: PreferenceKey {
    static let defaultValue = FleetElementSnapshot()
    static func reduce(value: inout FleetElementSnapshot, nextValue: () -> FleetElementSnapshot) {
        value.records += nextValue().records
    }
}

/// The elements currently mounted in one hosted screen, as last reported by SwiftUI layout.
@MainActor
final class FleetElementRegistry {
    private(set) var records: [FleetElementRecord] = []
    private var isClosed = false

    func update(_ snapshot: FleetElementSnapshot) {
        guard !isClosed else { return }
        records = snapshot.records
    }

    /// Drops every record (and the action closures they hold); later reports are ignored.
    func close() {
        isClosed = true
        records = []
    }

    /// Records in visual order: top to bottom, then leading to trailing.
    var ordered: [FleetElementRecord] {
        records.sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }
}

private struct FleetElementRegistryKey: EnvironmentKey {
    static let defaultValue: FleetElementRegistry? = nil
}

extension EnvironmentValues {
    var fleetElementRegistry: FleetElementRegistry? {
        get { self[FleetElementRegistryKey.self] }
        set { self[FleetElementRegistryKey.self] = newValue }
    }
}

private struct FleetElementModifier: ViewModifier {
    @State private var token = UUID()
    let id: String
    let text: String?
    let actions: [FleetElementAction]

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: FleetElementKey.self,
                    value: FleetElementSnapshot(records: [
                        FleetElementRecord(token: token, id: id, text: text, frame: proxy.frame(in: .global), actions: actions)
                    ])
                )
            }
        )
    }
}

extension View {
    /// Declares this view as a stable-identity element Fleet can observe and operate while it is
    /// mounted in a hosted screen. Outside a Fleet host it only adds an inert background reader.
    /// Identities must be stable and unique among mounted elements (use the model's identifier,
    /// not a position); duplicates are reported as ambiguous rather than resolved arbitrarily.
    public func fleetElement(_ id: String, text: String? = nil, actions: [FleetElementAction] = []) -> some View {
        modifier(FleetElementModifier(id: id, text: text, actions: actions))
    }
}

/// Applies the registry to the hosted root.
struct FleetElementReporting: ViewModifier {
    let registry: FleetElementRegistry

    func body(content: Content) -> some View {
        content
            .environment(\.fleetElementRegistry, registry)
            .onPreferenceChange(FleetElementKey.self) { snapshot in
                // SwiftUI delivers preference changes on the main thread.
                MainActor.assumeIsolated { registry.update(snapshot) }
            }
    }
}

extension FleetHostedView {
    /// Identities of the mounted elements in visual order (top to bottom), as last laid out.
    public var mountedElementIDs: [String] { elements.ordered.map(\.id) }

    /// The single mounted element with `id`. Throws `.invalidInput` if none or several are mounted.
    public func element(_ id: String, action: String = "observe element", fileID: String = #fileID, line: UInt = #line) throws -> FleetElementObservation {
        do {
            try requireActive(action)
            return try resolve(id, action: action).observation
        } catch let failure as FleetFailure {
            throw failure.attributed(to: FleetSourceLocation(fileID: fileID, line: line))
        }
    }

    /// Invokes the named action of the single mounted element `id`.
    ///
    /// With `surface` omitted the name must be offered on exactly one surface of that element; pass
    /// `surface` to choose between, say, a row's "Delete" control and its "Delete" swipe action.
    ///
    /// Throws `FleetFailure` (recoverable, naming the element identity, action and surface):
    /// `.invalidInput` when the element is not mounted, is ambiguous, or does not offer exactly one
    /// matching action; `.unavailableInteraction` when the action is currently disabled. The action
    /// runs the declared closure exactly once. That is handler dispatch only: it does not present or
    /// observe a menu, reveal a swipe row, or prove hit testing, accessibility or gesture delivery.
    public func perform(
        _ actionName: String, onElement id: String, via surface: FleetActionSurface? = nil,
        fileID: String = #fileID, line: UInt = #line
    ) throws {
        let action = "perform '\(actionName)'" + (surface.map { " via \($0.rawValue)" } ?? "")
        do {
            try requireActive(action)
            let record = try resolve(id, action: action)
            let matches = record.actions.filter { $0.name == actionName && (surface == nil || $0.surface == surface) }
            guard let found = matches.first else {
                throw FleetFailure(
                    kind: .invalidInput,
                    action: action,
                    target: "element '\(id)'",
                    state: "it offers actions \(record.actions.map { "\($0.name) (\($0.surface.rawValue))" }) but no match",
                    reason: "Request an action (and surface) the element declares with fleetElement(_:text:actions:)."
                )
            }
            guard matches.count == 1 else {
                throw FleetFailure(
                    kind: .invalidInput,
                    action: action,
                    target: "element '\(id)'",
                    state: "\(matches.count) declared actions match, on surfaces \(matches.map(\.surface.rawValue))",
                    reason: "Pass via: to choose one surface, and declare each name once per surface."
                )
            }
            guard found.isEnabled else {
                throw FleetFailure(
                    kind: .unavailableInteraction,
                    action: action,
                    target: "element '\(id)'",
                    state: "the \(found.surface.rawValue) action is disabled",
                    reason: "Wait for the screen to enable the action, or assert it stays disabled."
                )
            }
            found.perform()
        } catch let failure as FleetFailure {
            throw failure.attributed(to: FleetSourceLocation(fileID: fileID, line: line))
        }
    }

    /// Waits (bounded) until exactly the element `id` is mounted.
    public func waitForElement(_ id: String, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for element")
            try await context.waitUntil("element '\(id)' to be mounted (mounted: \(self.mountedElementIDs))", timeout: timeout) {
                self.elements.records.filter { $0.id == id }.count == 1
            }
        }
    }

    /// Waits (bounded) until no element `id` is mounted.
    public func waitForElementRemoval(_ id: String, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for element removal")
            try await context.waitUntil("element '\(id)' to be removed (mounted: \(self.mountedElementIDs))", timeout: timeout) {
                !self.elements.records.contains { $0.id == id }
            }
        }
    }

    private func resolve(_ id: String, action: String) throws -> FleetElementRecord {
        let matches = elements.records.filter { $0.id == id }
        switch matches.count {
        case 1:
            return matches[0]
        case 0:
            throw FleetFailure(
                kind: .invalidInput,
                action: action,
                target: "element '\(id)'",
                state: "no mounted element has that identity; mounted: \(mountedElementIDs)",
                reason: "Wait for the element to mount, or check the identity passed to fleetElement."
            )
        default:
            throw FleetFailure(
                kind: .invalidInput,
                action: action,
                target: "element '\(id)'",
                state: "\(matches.count) mounted elements share that identity",
                reason: "Give every mounted element a unique stable identity."
            )
        }
    }
}
