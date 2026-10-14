import Foundation

/**
 A recoverable, typed Swift error describing why a Fleet helper could not perform an action.

 Throwing helpers report ordinary failures with this type instead of raising an `NSException`,
 so XCTest (`XCTAssertThrowsError`) and Swift Testing (`#expect(throws:)`) can assert them
 without terminating the test process.

 How each situation is reported:
 - Invalid setup, invalid input, and unavailable interactions throw a `FleetFailure` whose `kind`
   distinguishes them.
 - A bounded wait that expires throws a `FleetFailure` of kind `.timedOut`.
 - Cancellation is never wrapped: the surrounding task's `CancellationError` propagates unchanged.
 - A delegate that refuses an otherwise valid interaction is not an error. Throwing helpers
   return `FleetInteractionOutcome.refusedByDelegate`, which keeps a deliberate production veto
   distinct from a mistake in the test's setup.
 */
public struct FleetFailure: Error, Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        /// The object under test is not configured for the action (for example, no data source).
        case invalidSetup
        /// An argument does not identify something that exists (for example, an out-of-range index path).
        case invalidInput
        /// The target exists but cannot currently be interacted with (for example, selection is disabled).
        case unavailableInteraction
        /// A bounded wait expired before the awaited state was observed.
        case timedOut
    }

    public let kind: Kind
    /// The attempted action, such as "select item".
    public let action: String
    /// The control and index the action was aimed at, such as "UICollectionView item 5 in section 0".
    public let target: String
    /// The relevant state that made the action fail.
    public let state: String
    /// What to change so the action succeeds.
    public let reason: String

    public init(kind: Kind, action: String, target: String, state: String, reason: String) {
        self.kind = kind
        self.action = action
        self.target = target
        self.state = state
        self.reason = reason
    }
}

extension FleetFailure: CustomStringConvertible, LocalizedError {
    public var description: String {
        "Fleet could not \(action) on \(target) (\(kind.rawValue)): \(state). \(reason)"
    }

    public var errorDescription: String? { description }
}

/// The result of a throwing Fleet interaction that was valid but did not change anything.
public enum FleetInteractionOutcome: Sendable, Equatable {
    /// The interaction ran, including the delegate callbacks that apply to it.
    case performed
    /// The named delegate method returned `false`, so the production code deliberately vetoed the interaction.
    case refusedByDelegate(method: String)
}
