import Combine
import FleetMacOS
import SwiftUI
import ViewInspector

// A test-side adapter for driving mounted macOS SwiftUI Button, TextField and SecureField controls.
// ViewInspector is compiled into this consumer's test target only; neither FleetMacOS nor the
// application target imports it.

// MARK: - Application seam (Combine only; no testing import)

/// A main-actor, single-slot rendezvous. The screen subscribes with
/// `.onReceive(seam.notice) { seam.visit(self) }`; the test delivers one request to the mounted
/// instance. The request is cleared when `run` returns, whether or not an instance answered.
@MainActor
final class InspectionSeam<V: View> {
    let notice = PassthroughSubject<Void, Never>()
    private var pending: (@MainActor (V) -> Void)?
    var hasPendingRequest: Bool { pending != nil }

    func visit(_ view: V) {
        let request = pending
        pending = nil
        request?(view)
    }

    func run(_ request: @escaping @MainActor (V) -> Void) -> Bool {
        var answered = false
        pending = { view in answered = true; request(view) }
        notice.send()
        pending = nil
        return answered
    }
}

// MARK: - Failures

/// Distinct, recoverable outcomes. None is resolved by taking a first match, and no case carries
/// a typed or secure value, so a description is safe to print.
enum MacOSQueryFailure: Error, Equatable, CustomStringConvertible {
    case absent(target: String, scope: String)
    case ambiguous(target: String, scope: String, count: Int)
    case disabled(target: String, scope: String)
    case unsupported(control: String, reason: String, recommendation: String)
    /// The handle belongs to an inspection that has ended; query again from a fresh inspection.
    case obsolete(target: String)
    /// No mounted instance answered the seam within the wait.
    case notMounted(screen: String)

    var description: String {
        switch self {
        case let .absent(target, scope): "\(target) is absent in \(scope)"
        case let .ambiguous(target, scope, count): "\(count) matches for \(target) in \(scope); expected exactly one"
        case let .disabled(target, scope): "\(target) in \(scope) is disabled"
        case let .unsupported(control, reason, recommendation): "\(control) is unsupported: \(reason). Try: \(recommendation)"
        case let .obsolete(target): "\(target) belongs to an inspection that has ended; query it again"
        case let .notMounted(screen): "no mounted \(screen) answered the inspection seam"
        }
    }
}

/// What each operation does. None of them is physical input.
enum MacOSActionKind: String, Equatable {
    case invokesClosure = "invokes the button's action closure"
    case writesBinding = "writes the control's binding"
}

// MARK: - Session and trace

/// One inspection. Handles check it, so a handle kept past the end of the inspection cannot act on
/// the screen that replaced the one it was found in. The trace names actions and targets only:
/// a value written to a text or secure field is never recorded.
@MainActor
final class InspectionSession {
    private(set) var isValid = true
    private(set) var trace: [String] = []
    func record(_ entry: String) { trace.append(entry) }
    func end() { isValid = false }
}

// MARK: - Handles

@MainActor
struct ButtonHandle {
    fileprivate let view: InspectableView<ViewType.Button>
    fileprivate let session: InspectionSession
    let target: String
    let scope: String

    var isEnabled: Bool { !view.isDisabled() }

    @discardableResult
    func tap() throws -> MacOSActionKind {
        try session.requireValid(target)
        if view.isDisabled() { throw MacOSQueryFailure.disabled(target: target, scope: scope) }
        session.record("tap \(target)")
        try view.tap()
        return .invokesClosure
    }
}

@MainActor
struct TextInputHandle {
    fileprivate let write: (String) throws -> Void
    fileprivate let isDisabled: Bool
    fileprivate let session: InspectionSession
    let target: String
    let scope: String
    let isSecure: Bool

    /// Writes the control's binding. The value is never recorded or reported.
    @discardableResult
    func setInput(_ value: String) throws -> MacOSActionKind {
        try session.requireValid(target)
        if isDisabled { throw MacOSQueryFailure.disabled(target: target, scope: scope) }
        session.record("write binding of \(target) (value withheld)")
        try write(value)
        return .writesBinding
    }
}

extension InspectionSession {
    fileprivate func requireValid(_ target: String) throws {
        if !isValid { throw MacOSQueryFailure.obsolete(target: target) }
    }
}

// MARK: - Inspector

/// Resolves controls inside a scope that is itself resolved by an exact-one accessibility identifier.
///
/// Evidence level: ViewInspector reports the declaration content of the mounted instance. It is
/// neither proof of layout or visibility nor of physical input: `tap` calls the action closure and
/// `setInput` writes the binding, with no hit testing, key events, accessibility or OS authentication.
@MainActor
struct MacOSInspector {
    typealias Root = InspectableView<ViewType.ClassifiedView>
    let root: Root
    let scope: String
    let session: InspectionSession

    init(_ root: Root, scope: String = "screen", session: InspectionSession = InspectionSession()) {
        self.root = root
        self.scope = scope
        self.session = session
    }

    var trace: [String] { session.trace }

    func container(_ identifier: String) throws -> MacOSInspector {
        let target = "container '\(identifier)'"
        let matches = root.findAll(where: { try $0.accessibilityIdentifier() == identifier })
        switch matches.count {
        case 1: return MacOSInspector(matches[0], scope: scope + " > '\(identifier)'", session: session)
        case 0: throw MacOSQueryFailure.absent(target: target, scope: scope)
        default: throw MacOSQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }

    func button(_ label: String) throws -> ButtonHandle {
        let target = "button '\(label)'"
        try session.requireValid(target)
        let view = try exactlyOne(ViewType.Button.self, target) { try $0.labelView().text().string() == label }
        return ButtonHandle(view: view, session: session, target: target, scope: scope)
    }

    func textField(_ title: String) throws -> TextInputHandle {
        let target = "text field '\(title)'"
        try session.requireValid(target)
        let view = try exactlyOne(ViewType.TextField.self, target) { try $0.labelView().text().string() == title }
        return TextInputHandle(write: { try view.setInput($0) }, isDisabled: view.isDisabled(),
                               session: session, target: target, scope: scope, isSecure: false)
    }

    func secureField(_ title: String) throws -> TextInputHandle {
        let target = "secure field '\(title)'"
        try session.requireValid(target)
        let view = try exactlyOne(ViewType.SecureField.self, target) { try $0.labelView().text().string() == title }
        return TextInputHandle(write: { try view.setInput($0) }, isDisabled: view.isDisabled(),
                               session: session, target: target, scope: scope, isSecure: true)
    }

    /// Controls outside the tested matrix fail explicitly instead of being simulated.
    static func unsupported(_ control: String) -> MacOSQueryFailure {
        switch control {
        case "toggle", "picker", "menu", "gesture", "swipeAction":
            .unsupported(control: control, reason: "it is outside the macOS control matrix (Button, TextField, SecureField)",
                         recommendation: "write the model the control binds to, or use an XCUITest for physical interaction")
        case "renderedText", "visibility", "keyEvent":
            .unsupported(control: control, reason: "inspection reports declaration content of the mounted instance, not rendered or physical input",
                         recommendation: "observe the AppKit hierarchy under the hosting view, or use an XCUITest")
        default:
            .unsupported(control: control, reason: "it is outside the tested control matrix",
                         recommendation: "use an XCUITest for physical interaction")
        }
    }

    private func exactlyOne<T: BaseViewType>(
        _ type: T.Type, _ target: String, where match: @escaping (InspectableView<T>) throws -> Bool
    ) throws -> InspectableView<T> {
        let matches = root.findAll(type, where: match)
        switch matches.count {
        case 1: return matches[0]
        case 0: throw MacOSQueryFailure.absent(target: target, scope: scope)
        default: throw MacOSQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }
}

// MARK: - Entry points on the hosted scope

extension FleetMacOSHost {
    /// Runs `body` against the mounted instance once it answers the seam, within `timeout`. The
    /// inspector's handles are invalid after `body` returns or throws. An error from `body`
    /// propagates unchanged; no answer throws `FleetMacOSFailure(.timedOut)`; cancellation is unchanged.
    func inspect<V: View, T>(
        _ seam: InspectionSeam<V>, timeout: TimeInterval = 2,
        _ body: @escaping @MainActor (MacOSInspector) throws -> T
    ) async throws -> T {
        var value: T?
        var failure: Error?
        try await waitUntil("mounted \(V.self) to answer inspection", timeout: timeout) {
            seam.run { view in
                let session = InspectionSession()
                defer { session.end() }
                do { value = try body(MacOSInspector(try view.inspect(), session: session)) } catch { failure = error }
            }
        }
        if let failure { throw failure }
        return value!
    }

    /// A synchronous, non-throwing look for use inside a wait condition. `nil` if nothing answered or the body threw.
    func probe<V: View, T>(_ seam: InspectionSeam<V>, _ body: @escaping @MainActor (MacOSInspector) throws -> T) -> T? {
        var value: T?
        _ = seam.run { view in
            let session = InspectionSession()
            defer { session.end() }
            value = try? body(MacOSInspector(try view.inspect(), session: session))
        }
        return value
    }
}
