import Foundation

public enum FLTStoryboardBindingError: Error {
    case invalidViewControllerIdentifier(String)
    case invalidExternalStoryboardReference(String)
    case internalInconsistency(String)

    var description: String {
        get {
            var description = ""

            switch self {
            case .invalidViewControllerIdentifier(let message):
                description = message
            case .invalidExternalStoryboardReference(let message):
                description = message
            case .internalInconsistency(let message):
                description = message
            }

            return description
        }
    }
}
