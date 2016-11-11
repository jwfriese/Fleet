import Foundation

public struct FleetError {
    fileprivate var message: String

    public init(message: String) {
        self.message = message
    }
}

extension FleetError: Error {}

extension FleetError: CustomStringConvertible {
    public var description: String {
        return "Fleet error: \(self.message)"
    }
}

extension FleetError: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "Fleet error: \(self.message)"
    }
}
