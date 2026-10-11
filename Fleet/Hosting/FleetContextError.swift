import Foundation

/// Typed failures reported by `Fleet.withContext` and the waits on `FleetTestContext`.
public enum FleetContextError: Error, CustomStringConvertible {
    /// The surrounding task was cancelled while acquiring the coordination lease or waiting.
    case cancelled(String)
    /// A bounded wait reached its deadline before the observed state held.
    case timedOut(description: String, timeout: TimeInterval, context: String)
    /// The context was used after its scope finished.
    case contextEnded

    public var description: String {
        switch self {
        case .cancelled(let detail):
            return "Fleet context cancelled: \(detail)"
        case .timedOut(let description, let timeout, let context):
            return "Timed out after \(timeout)s waiting for \(description). \(context)"
        case .contextEnded:
            return "The Fleet test context has ended; it cannot be used outside its `withContext` body."
        }
    }
}
