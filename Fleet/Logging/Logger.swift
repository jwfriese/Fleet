import Foundation

class Logger {
    static func log(_ message: String) {
        print("Fleet: \(message)")
    }

    static func logWarning(_ message: String) {
        log("** WARNING ** \(message)")
    }
}
