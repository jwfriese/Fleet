import Foundation

/// Process-local FIFO lease. At most one `Fleet.withContext` scope holds it, from before
/// setup until after cleanup. Everything is main-actor isolated.
@MainActor
final class FleetContextCoordinator {
    static let shared = FleetContextCoordinator()

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var held = false
    private var waiters: [Waiter] = []
    private var nextID: UInt64 = 0

    var isHeld: Bool { held }
    var waiterCount: Int { waiters.count }

    /// Suspends until the lease is granted. Throws `CancellationError` if the task is
    /// cancelled before the lease is granted; a cancelled waiter never holds or leaks the lease.
    func acquire() async throws {
        if Task.isCancelled { throw CancellationError() }
        if !held {
            held = true
            return
        }
        nextID += 1
        let id = nextID
        try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        waiters.append(Waiter(id: id, continuation: continuation))
                    }
                }
        } onCancel: {
            Task { @MainActor in self.cancelWaiter(id) }
        }
        // The lease may have been handed to this waiter before its cancellation was processed.
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    private func cancelWaiter(_ id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    /// Hands the lease to the next waiter, or frees it.
    func release() {
        precondition(held, "Fleet context lease released without being held")
        if waiters.isEmpty {
            held = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }
}
