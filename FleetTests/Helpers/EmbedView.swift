import UIKit

extension Test {
    enum InternalError: Error {
        case unexpectedError(String)

        var description: String {
            get {
                var description = ""

                switch self {
                case .unexpectedError(let message):
                    description = message
                }

                return description
            }
        }
    }

    static func embedViewIntoMainApplicationWindow(_ view: UIView) throws {
        guard let keyWindow = UIApplication.shared.keyWindow else {
            throw Test.InternalError.unexpectedError("Testing environment does not have a key window")
        }

        guard let controller = keyWindow.rootViewController else {
            throw Test.InternalError.unexpectedError("Key window in test does not have a root view controller")
        }

        controller.view.addSubview(view)
    }
}
