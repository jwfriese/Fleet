enum FLTUserActionResult {
    case Success
    case Failure(String)
    case Error(ErrorType)

    func resultDescription() -> String {
        var description = ""

        switch self {
        case .Success:
            description = "Succeeded"
        case .Failure(let message):
            description = message
        case .Error(let error):
            description = "Errored: \(error)"
        }

        return description
    }
}
