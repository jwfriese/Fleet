import Foundation

func wait(timeout: Double, forCondition condition: () -> Bool) -> Bool {
    let wait = Wait(withPredicate: condition).timeout(timeout).wait()
    return wait
}

struct WaitDefaults {
    static var timeout: Double {
        get {
            return 3
        }
    }

    static var mainLoopStallTimeout: UInt64 {
        get {
            return 5
        }
    }
}

private class Wait {
    var predicate: () -> Bool
    var timeout: Double = WaitDefaults.timeout
    var promise: WaitPromise
    var predicateSource: dispatch_source_t?
    var timeoutSource: dispatch_source_t?

    init(withPredicate predicate: () -> Bool) {
        self.predicate = predicate
        self.promise = WaitPromise()
    }

    func timeout(timeout: Double) -> Wait {
        self.timeout = timeout
        return self
    }

    func wait() -> Bool {
        let predicateSource = constructPredicateSource(predicate)
        let timeoutSource = constructTimeoutSource(timeout)

        self.predicateSource = predicateSource
        self.timeoutSource = timeoutSource

        dispatch_resume(predicateSource)
        dispatch_resume(timeoutSource)

        while promise.isIncomplete() {
            // This "advances" the run loop, blocking on processing of other sources on this run
            // loop (including our timeout and predicate sources above). If this were not here,
            // the loop would spin countless times in this loop before giving up control.
            NSRunLoop.currentRunLoop().runMode(NSDefaultRunLoopMode, beforeDate: NSDate.distantFuture())
        }

        dispatch_suspend(timeoutSource)
        dispatch_suspend(predicateSource)

        dispatch_source_cancel(timeoutSource)
        dispatch_source_cancel(predicateSource)

        switch promise.result {
        case .Fulfilled(let value):
            return value
        case .StalledMainRunLoop:
            print("Fleet: Timeout occurred on user action and run loop stalled")
            return false
        default:
            return false
        }
    }

    func constructTimeoutSource(timeout: Double) -> dispatch_source_t {
        let timeoutSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                   0,
                                                   DISPATCH_TIMER_STRICT,
                                                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        )

        dispatch_source_set_timer(timeoutSource,
                                  dispatch_time(DISPATCH_TIME_NOW, Int64(timeout * Double(NSEC_PER_SEC))),
                                  DISPATCH_TIME_FOREVER,
                                  NSEC_PER_SEC / 4
        )

        dispatch_source_set_event_handler(timeoutSource) {
            guard self.promise.isIncomplete() else { return }

            let timeoutSemaphore = dispatch_semaphore_create(1)

            let mainRunLoop = CFRunLoopGetMain()
            CFRunLoopPerformBlock(mainRunLoop, kCFRunLoopDefaultMode) {
                dispatch_semaphore_signal(timeoutSemaphore)

                if self.promise.set(.Timeout) {
                    CFRunLoopStop(mainRunLoop)
                }
            }

            // Stop the run loop to pause the main thread and cycle through to the timeout processing
            // block added above.
            CFRunLoopStop(mainRunLoop)

            // It's possible that the stopped run loop could stall and never run the timeout
            // code. The following semaphores, which wait on the timeout code to run, are set
            // up to timeout themselves in case that happens.
            let stallTimeout = dispatch_time(DISPATCH_TIME_NOW,
                                             Int64(WaitDefaults.mainLoopStallTimeout * NSEC_PER_SEC)
            )

            let timeoutProcessed = dispatch_semaphore_wait(timeoutSemaphore, stallTimeout) != 0
            if !timeoutProcessed {
                if self.promise.set(.StalledMainRunLoop) {
                    CFRunLoopStop(mainRunLoop)
                }
            }

        }

        return timeoutSource
    }

    func constructPredicateSource(predicate: () -> Bool) -> dispatch_source_t {
        let predicateSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                                 0,
                                                 DISPATCH_TIMER_STRICT,
                                                 dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)
        )

        dispatch_source_set_timer(predicateSource,
                                  DISPATCH_TIME_NOW,
                                  NSEC_PER_SEC,
                                  NSEC_PER_SEC / 4
        )

        dispatch_source_set_event_handler(predicateSource) {
            dispatch_async(dispatch_get_main_queue()) {
                print("Running predicate evaluation")
                if predicate() {
                    if self.promise.set(.Fulfilled(true)) {
                        CFRunLoopStop(CFRunLoopGetCurrent())
                    }
                }
            }
        }

        return predicateSource
    }
}
