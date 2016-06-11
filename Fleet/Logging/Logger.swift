import Foundation

class Logger {
    static func log(message: String) {
        print("Fleet: \(message)")
    }
    
    static func logWarning(message: String) {
        log("** WARNING ** \(message)")
    }
}
