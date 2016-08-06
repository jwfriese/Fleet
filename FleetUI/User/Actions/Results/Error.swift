class Error: UserActionResult {
    var errorMessage: String!

    init(_ error: String) {
        self.errorMessage = error
    }

    var succeeded: Bool {
        get {
            return false
        }
    }

    var resultDescription: String {
        get {
            return "Errored: \(errorMessage)"
        }
    }
}
