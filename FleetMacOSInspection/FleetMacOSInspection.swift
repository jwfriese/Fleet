import FleetMacOS
import SwiftUI
import ViewInspector

// FleetMacOSInspection: a test-only adapter for driving mounted macOS SwiftUI Button, TextField,
// SecureField and multiline TextEditor controls, and for moving a mounted Slider's numeric
// binding. ViewInspector is an implementation dependency of this product; FleetMacOS and application targets do not import it.

// MARK: - Failures

/// Distinct, recoverable outcomes. None is resolved by taking a first match, and no case carries
/// a typed or secure value, so a description is safe to print.
public enum MacOSQueryFailure: Error, Equatable, CustomStringConvertible {
    case absent(target: String, scope: String)
    case ambiguous(target: String, scope: String, count: Int)
    case disabled(target: String, scope: String)
    case unsupported(control: String, reason: String, recommendation: String)
    /// The handle belongs to an inspection that has ended; query again from a fresh inspection.
    case obsolete(target: String)
    /// No mounted instance answered the seam within the wait.
    case notMounted(screen: String)

    public var description: String {
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
public enum MacOSActionKind: String, Equatable {
    case invokesClosure = "invokes the button's action closure"
    case writesBinding = "writes the control's binding"
}

// MARK: - Session and trace

/// One inspection. Handles check it, so a handle kept past the end of the inspection cannot act on
/// the screen that replaced the one it was found in. The trace names actions and targets only:
/// a value written to a text or secure field is never recorded.
@MainActor
final class MacOSInspectionSession {
    private(set) var isValid = true
    private(set) var trace: [String] = []
    func record(_ entry: String) { trace.append(entry) }
    func end() { isValid = false }
}

// MARK: - Handles

@MainActor
public struct MacOSButtonHandle {
    fileprivate let view: InspectableView<ViewType.Button>
    fileprivate let session: MacOSInspectionSession
    public let target: String
    public let scope: String

    public var isEnabled: Bool { !view.isDisabled() }

    @discardableResult
    public func tap() throws -> MacOSActionKind {
        try session.requireValid(target)
        if view.isDisabled() { throw MacOSQueryFailure.disabled(target: target, scope: scope) }
        session.record("tap \(target)")
        try view.tap()
        return .invokesClosure
    }
}

@MainActor
public struct MacOSTextInputHandle {
    fileprivate let write: (String) throws -> Void
    fileprivate let isDisabled: Bool
    fileprivate let session: MacOSInspectionSession
    public let target: String
    public let scope: String
    public let isSecure: Bool

    public var isEnabled: Bool { !isDisabled }

    /// Writes the control's binding. The value is never recorded or reported.
    @discardableResult
    public func setInput(_ value: String) throws -> MacOSActionKind {
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
public struct MacOSTextEditorHandle {
    fileprivate let view: InspectableView<ViewType.TextEditor>
    fileprivate let session: MacOSInspectionSession
    public let target: String
    public let scope: String

    public var isEnabled: Bool { !view.isDisabled() }

    /// The value currently held by the mounted instance's binding. Requery after a state change.
    public func text() throws -> String {
        try session.requireValid(target)
        return try unsupportedIfUnreadable { try view.input() }
    }

    /// Replaces the whole bound string (use `""` to clear). Throws `.disabled` before writing.
    @discardableResult
    public func setText(_ value: String) throws -> MacOSActionKind {
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
    fileprivate let session: MacOSInspectionSession
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

extension MacOSInspectionSession {
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
public struct MacOSInspector {
    typealias Root = InspectableView<ViewType.ClassifiedView>
    let root: Root
    public let scope: String
    let session: MacOSInspectionSession

    init(_ root: Root, scope: String = "screen", session: MacOSInspectionSession = MacOSInspectionSession()) {
        self.root = root
        self.scope = scope
        self.session = session
    }

    public var trace: [String] { session.trace }

    public func container(_ identifier: String) throws -> MacOSInspector {
        let target = "container '\(identifier)'"
        try session.requireValid(target)
        let matches = root.findAll(where: { try $0.accessibilityIdentifier() == identifier })
        switch matches.count {
        case 1: return MacOSInspector(matches[0], scope: scope + " > '\(identifier)'", session: session)
        case 0: throw MacOSQueryFailure.absent(target: target, scope: scope)
        default: throw MacOSQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }

    public func button(_ label: String) throws -> MacOSButtonHandle {
        try button(target: "button '\(label)'") { try $0.labelView().text().string() == label }
    }

    public func button(identifier: String) throws -> MacOSButtonHandle {
        try button(target: "button identifier '\(identifier)'") { try $0.accessibilityIdentifier() == identifier }
    }

    private func button(
        target: String, matching: @escaping (InspectableView<ViewType.Button>) throws -> Bool
    ) throws -> MacOSButtonHandle {
        let view = try exactlyOne(ViewType.Button.self, target, where: matching)
        return MacOSButtonHandle(view: view, session: session, target: target, scope: scope)
    }

    public func textField(_ title: String) throws -> MacOSTextInputHandle {
        try textField(target: "text field '\(title)'") { try $0.labelView().text().string() == title }
    }

    public func textField(identifier: String) throws -> MacOSTextInputHandle {
        try textField(target: "text field identifier '\(identifier)'") { try $0.accessibilityIdentifier() == identifier }
    }

    private func textField(
        target: String, matching: @escaping (InspectableView<ViewType.TextField>) throws -> Bool
    ) throws -> MacOSTextInputHandle {
        let view = try exactlyOne(ViewType.TextField.self, target, where: matching)
        return MacOSTextInputHandle(write: { try view.setInput($0) }, isDisabled: view.isDisabled(),
                               session: session, target: target, scope: scope, isSecure: false)
    }

    public func secureField(_ title: String) throws -> MacOSTextInputHandle {
        try secureField(target: "secure field '\(title)'") { try $0.labelView().text().string() == title }
    }

    public func secureField(identifier: String) throws -> MacOSTextInputHandle {
        try secureField(target: "secure field identifier '\(identifier)'") { try $0.accessibilityIdentifier() == identifier }
    }

    private func secureField(
        target: String, matching: @escaping (InspectableView<ViewType.SecureField>) throws -> Bool
    ) throws -> MacOSTextInputHandle {
        let view = try exactlyOne(ViewType.SecureField.self, target, where: matching)
        return MacOSTextInputHandle(write: { try view.setInput($0) }, isDisabled: view.isDisabled(),
                               session: session, target: target, scope: scope, isSecure: true)
    }

    /// Finds exactly one `TextEditor` in scope whose accessibility identifier is `identifier`.
    public func textEditor(identifier: String) throws -> MacOSTextEditorHandle {
        let target = "text editor '\(identifier)'"
        let view = try exactlyOne(ViewType.TextEditor.self, target) { try $0.accessibilityIdentifier() == identifier }
        return MacOSTextEditorHandle(view: view, session: session, target: target, scope: scope)
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
    public static func unsupported(_ control: String) -> MacOSQueryFailure {
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
        try session.requireValid(target)
        let matches = root.findAll(type, where: match)
        switch matches.count {
        case 1: return matches[0]
        case 0: throw MacOSQueryFailure.absent(target: target, scope: scope)
        default: throw MacOSQueryFailure.ambiguous(target: target, scope: scope, count: matches.count)
        }
    }
}

// MARK: - Endpoint

/// The app-owned, framework-only rendezvous a mounted screen answers. The application declares a
/// small seam (for example a main-actor single-slot object plus a Combine subject the screen
/// observes) and the test target conforms it to this protocol. The application imports neither
/// Fleet nor ViewInspector.
@MainActor
public protocol MacOSInspectionEndpoint {
    associatedtype Screen: View
    /// Offers `visit` to the mounted `Screen` instance. Returns `true` if an instance ran it
    /// synchronously, `false` if nothing answered. Must not retain `visit` after returning.
    func deliver(_ visit: @escaping @MainActor (Screen) -> Void) -> Bool
}

/// A closure-based endpoint for seams that are not worth a conformance.
@MainActor
public struct MacOSInspectionBridge<Screen: View>: MacOSInspectionEndpoint {
    private let bridge: @MainActor (@escaping @MainActor (Screen) -> Void) -> Bool
    public init(_ deliver: @escaping @MainActor (@escaping @MainActor (Screen) -> Void) -> Bool) { bridge = deliver }
    public func deliver(_ visit: @escaping @MainActor (Screen) -> Void) -> Bool { bridge(visit) }
}

// MARK: - Entry points on the hosted scope

extension FleetMacOSHost {
    /// Runs `body` against the mounted instance once it answers the endpoint, within `timeout`. The
    /// inspector's handles are invalid after `body` returns or throws. An error from `body`
    /// propagates unchanged. No answer throws `MacOSQueryFailure.notMounted`; an invalid timeout
    /// throws `FleetMacOSFailure(.invalidInput)`. Cancellation propagates unchanged.
    public func inspect<E: MacOSInspectionEndpoint, T>(
        _ endpoint: E, timeout: TimeInterval = 2,
        _ body: @escaping @MainActor (MacOSInspector) throws -> T
    ) async throws -> T {
        let screen = String(describing: E.Screen.self)
        var result: Result<T, Error>?
        do {
            try await waitUntil("mounted \(screen) to answer inspection", timeout: timeout) {
                _ = endpoint.deliver { view in
                    let session = MacOSInspectionSession()
                    defer { session.end() }
                    result = Result { try body(MacOSInspector(try view.inspect(), session: session)) }
                }
                return result != nil
            }
        } catch let failure as FleetMacOSFailure where failure.kind == .timedOut {
            throw MacOSQueryFailure.notMounted(screen: screen)
        }
        guard let result else { throw MacOSQueryFailure.notMounted(screen: screen) }
        return try result.get()
    }

    /// A synchronous, non-throwing look for use inside a wait condition. `nil` if the scope has ended, nothing answered or the body threw.
    public func probe<E: MacOSInspectionEndpoint, T>(_ endpoint: E, _ body: @escaping @MainActor (MacOSInspector) throws -> T) -> T? {
        guard isScopeActive else { return nil }
        var value: T?
        _ = endpoint.deliver { view in
            let session = MacOSInspectionSession()
            defer { session.end() }
            value = try? body(MacOSInspector(try view.inspect(), session: session))
        }
        return value
    }
}
