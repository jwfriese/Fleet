class Success: ActionResult {
    var succeeded: Bool {
        get {
            return true
        }
    }

    var resultDescription: String {
        get {
            return "Succeeded"
        }
    }
}
