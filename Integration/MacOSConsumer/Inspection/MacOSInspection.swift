import Combine
import FleetMacOS
import SwiftUI
import ViewInspector

// A test-side adapter for driving mounted macOS SwiftUI Button, TextField, SecureField and
// multiline TextEditor controls, and for moving a mounted Slider's numeric binding.
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

/// A mounted multiline `TextEditor` located by accessibility identifier. Reads and writes go through
/// the editor's actual `String` binding; newlines are preserved exactly. Neither is physical typing.
@MainActor
struct TextEditorHandle {
    fileprivate let view: InspectableView<ViewType.TextEditor>
    fileprivate let session: InspectionSession
    let target: String
    let scope: String

    var isEnabled: Bool { !view.isDisabled() }

    /// The value currently held by the mounted instance's binding. Requery after a state change.
    func text() throws -> String {
        try session.requireValid(target)
        return try unsupportedIfUnreadable { try view.input() }
    }

    /// Replaces the whole bound string (use `""` to clear). Throws `.disabled` before writing.
    @discardableResult
    func setText(_ value: String) throws -> MacOSActionKind {
        try session.requireValid(target)
        if view.isDisabled() { throw MacOSQueryFailure.disabled(target: target, scope: scope) }
        session.record("write binding of \(target) (value withheld)")
        try unsupportedIfUnreadable { try view.setInput(value) }
        return .writesBinding
    }

    private func unsupportedIfUnreadable<T>(_ body: () throws -> T) throws -> T {
        do { return try body() } catch {
            throw MacOSQueryFailure.unsupported(
                control: target, reason: "the editor's binding could not be read or written as a plain String",
                recommendation: "write the model the editor binds to, or use an XCUITest")
        }
    }
}

/// A mounted `Slider` located by accessibility identifier. ViewInspector exposes the slider's binding
/// normalized to 0...1 and does not report the declared `in:` range, so the caller states that range
/// and the adapter converts both ways. The application's setter then runs with the chosen value in
/// its own units. Neither read nor write is a drag.
@MainActor
struct SliderHandle {
    fileprivate let view: InspectableView<ViewType.Slider>
    fileprivate let session: InspectionSession
    let target: String
    let scope: String
    let range: ClosedRange<Double>

    var isEnabled: Bool { !view.isDisabled() }

    /// The value the mounted instance's binding currently reports, in the declared range's units.
    /// Requery after a state change.
    func value() throws -> Double {
        try session.requireValid(target)
        let fraction = try unsupported("the slider's binding could not be read as a Double") { try view.value() }
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }

    /// Calls the slider's binding setter with `value`. Throws `.disabled` before writing, and
    /// `.unsupported` for a value outside the declared range (SwiftUI would clamp it silently).
    @discardableResult
    func setValue(_ value: Double) throws -> MacOSActionKind {
        try session.requireValid(target)
        if view.isDisabled() { throw MacOSQueryFailure.disabled(target: target, scope: scope) }
        let width = range.upperBound - range.lowerBound
        guard range.contains(value), width > 0 else {
            throw MacOSQueryFailure.unsupported(
                control: target, reason: "\(value) is outside the declared range \(range)",
                recommendation: "choose a value inside the range the slider declares")
        }
        session.record("write binding of \(target) to \(value)")
        try unsupported("the slider's binding could not be written as a Double") {
            try view.setValue((value - range.lowerBound) / width)
        }
        return .writesBinding
    }

    private func unsupported<T>(_ reason: String, _ body: () throws -> T) throws -> T {
        do { return try body() } catch {
            throw MacOSQueryFailure.unsupported(
                control: target, reason: reason, recommendation: "write the model the slider binds to, or use an XCUITest")
        }
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

    /// Finds exactly one `TextEditor` in scope whose accessibility identifier is `identifier`.
    func textEditor(identifier: String) throws -> TextEditorHandle {
        let target = "text editor '\(identifier)'"
        try session.requireValid(target)
        let view = try exactlyOne(ViewType.TextEditor.self, target) { try $0.accessibilityIdentifier() == identifier }
        return TextEditorHandle(view: view, session: session, target: target, scope: scope)
    }

    /// Finds exactly one `Slider` in scope whose accessibility identifier is `identifier`. `range`
    /// must be the `in:` range the slider declares.
    func slider(identifier: String, in range: ClosedRange<Double>) throws -> SliderHandle {
        let target = "slider '\(identifier)'"
        try session.requireValid(target)
        let view = try exactlyOne(ViewType.Slider.self, target) { try $0.accessibilityIdentifier() == identifier }
        return SliderHandle(view: view, session: session, target: target, scope: scope, range: range)
    }

    /// Controls outside the tested matrix fail explicitly instead of being simulated.
    static func unsupported(_ control: String) -> MacOSQueryFailure {
        switch control {
        case "toggle", "picker", "menu", "gesture", "swipeAction":
            .unsupported(control: control, reason: "it is outside the macOS control matrix (Button, TextField, SecureField, TextEditor, Slider)",
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

    /// A synchronous, non-throwing look for use inside a wait condition. `nil` if the scope has ended, nothing answered or the body threw.
    func probe<V: View, T>(_ seam: InspectionSeam<V>, _ body: @escaping @MainActor (MacOSInspector) throws -> T) -> T? {
        guard isScopeActive else { return nil }
        var value: T?
        _ = seam.run { view in
            let session = InspectionSession()
            defer { session.end() }
            value = try? body(MacOSInspector(try view.inspect(), session: session))
        }
        return value
    }
}
