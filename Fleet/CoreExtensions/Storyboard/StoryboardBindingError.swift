import Foundation

extension FleetFailure {
    /// A recoverable storyboard failure. `message` describes what is wrong; `reason` says what to change.
    static func storyboard(_ kind: Kind, action: String, target: String, message: String, reason: String) -> FleetFailure {
        FleetFailure(kind: kind, action: action, target: target, state: message, reason: reason)
    }
}
