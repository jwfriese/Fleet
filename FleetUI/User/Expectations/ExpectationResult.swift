public enum ExpectationResult {
    case Satisfied
    case Rejected(String)

    var description: String {
        get {
            switch self {
            case .Satisfied:
                return "Satisfied"
            case .Rejected(let rejectionMessage):
                return rejectionMessage
            }
        }
    }
}
