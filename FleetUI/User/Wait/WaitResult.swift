import Foundation

enum WaitResult {
    case Incomplete
    case Fulfilled(Bool)
    case Timeout
    case StalledMainRunLoop
}
