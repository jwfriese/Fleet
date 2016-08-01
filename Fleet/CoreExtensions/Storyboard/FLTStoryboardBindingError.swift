import Foundation

public enum FLTStoryboardBindingError: ErrorType {
    case InvalidViewControllerIdentifier(String)
    case InvalidExternalStoryboardReference(String)
    case InternalInconsistency(String)
    
    var description: String {
        get {
            var description = ""
            
            switch self {
            case .InvalidViewControllerIdentifier(let message):
                description = message
            case .InvalidExternalStoryboardReference(let message):
                description = message
            case .InternalInconsistency(let message):
                description = message
            }
            
            return description
        }
    }
}
