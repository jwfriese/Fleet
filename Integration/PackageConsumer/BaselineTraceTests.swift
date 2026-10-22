import XCTest

/// Fleet-free baseline: this test bundle does not link Fleet, so UIKit runs without any Fleet runtime hook.
@MainActor
final class BaselineTraceTests: XCTestCase {
    func testRecordUnhookedUIKitTrace() async throws {
        let events = await HostingTraceScenario.run()
        XCTAssertTrue(events.contains("dismiss.completion"), "\(events)")
        try HostingTraceScenario.record(events, as: "baseline")
    }
}
