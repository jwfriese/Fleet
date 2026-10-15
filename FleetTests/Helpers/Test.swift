import XCTest

class Test {}

/// A weak reference probe. Tests keep only this outside an ownership boundary, so that the probe
/// itself never contributes to the lifetime being measured.
struct WeakProbe<T: AnyObject>: @unchecked Sendable {  // holds no strong reference
    weak var value: T?
    init(_ value: T) { self.value = value }
}

/// Runs synchronous work in its own autorelease pool, so temporaries from Objective-C returns,
/// casts, and assertion evaluation are released when the scope ends rather than when the
/// enclosing test method returns. Do not hold a pool across a suspension point; scope async work
/// in synchronous helpers instead.
func lifetimeScope<T>(_ body: () throws -> T) rethrows -> T {
    return try autoreleasepool(invoking: body)
}

/// Asserts that the probed object is released once every ownership boundary that could hold it has
/// ended. The check drains autorelease pools and spins the run loop until the deadline, because
/// UIKit may release objects on a later run loop turn; an object that is genuinely retained still
/// fails at the deadline. Call it outside any scope that touched the object.
@MainActor
func assertReleased<T: AnyObject>(
    _ probe: WeakProbe<T>,
    _ description: String = "object",
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
        lifetimeScope { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
        if probe.value == nil { return }
        if Date() >= deadline { break }
    }
    XCTFail("The \(description) was still alive \(timeout)s after its owners were released", file: file, line: line)
}
