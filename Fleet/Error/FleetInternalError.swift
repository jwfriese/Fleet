extension Fleet {
    enum InternalError: FleetErrorDefinition {
        case unrecoverable(details: String)

        var errorMessage: String {
            switch self {
            case .unrecoverable(let details):
                return "Error: \(details). Fleet cannot recover from this error. If see this error consistently, please file an issue on Fleet's official GitHub page (https://github.com/jwfriese/Fleet/issues/new), and include as much information as you can."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.InternalError") } }
    }
}
