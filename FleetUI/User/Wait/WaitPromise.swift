class WaitPromise {
    private(set) var result: WaitResult = .Incomplete
    private var setSemaphore: dispatch_semaphore_t

    init() {
        setSemaphore = dispatch_semaphore_create(1)
    }

    func set(result: WaitResult) -> Bool {
        var didSet = false
        dispatch_semaphore_wait(setSemaphore, 0)
        if isIncomplete() {
            self.result = result
            didSet = true
        }
        dispatch_semaphore_signal(setSemaphore)

        return didSet
    }

    func isIncomplete() -> Bool {
        switch result {
        case .Incomplete:
            return true
        default:
            return false
        }
    }
}
