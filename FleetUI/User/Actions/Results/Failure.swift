class Failure: UserActionResult {
    var message: String!

    init(_ message: String) {
        self.message = message
    }

    var succeeded: Bool {
        get {
            return false
        }
    }

    var resultDescription: String {
        get {
            return message
        }
    }
}
