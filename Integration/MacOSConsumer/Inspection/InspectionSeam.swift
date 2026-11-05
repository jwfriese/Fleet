import Combine
import FleetMacOSInspection
import SwiftUI

// The consumer's only local inspection support: a small framework-only seam (Combine, no testing
// import) and its conformance to the published `MacOSInspectionEndpoint`. In an application the seam
// class lives in the app target; the conformance below lives in the test target.

/// A main-actor, single-slot rendezvous. The screen subscribes with
/// `.onReceive(seam.notice) { seam.visit(self) }`; the test delivers one request to the mounted
/// instance. The request is cleared when `run` returns, whether or not an instance answered.
@MainActor
final class InspectionSeam<V: View> {
    let notice = PassthroughSubject<Void, Never>()
    private var pending: (@MainActor (V) -> Void)?
    var hasPendingRequest: Bool { pending != nil }

    func visit(_ view: V) {
        let request = pending
        pending = nil
        request?(view)
    }

    func run(_ request: @escaping @MainActor (V) -> Void) -> Bool {
        var answered = false
        pending = { view in answered = true; request(view) }
        notice.send()
        pending = nil
        return answered
    }
}

extension InspectionSeam: MacOSInspectionEndpoint {
    typealias Screen = V
    func deliver(_ visit: @escaping @MainActor (V) -> Void) -> Bool { run(visit) }
}
