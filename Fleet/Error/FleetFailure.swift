import Foundation

/// A caller's file and line, captured at a public Fleet entry point.
public struct FleetSourceLocation: Sendable, Equatable {
    public let fileID: String
    public let line: UInt

    public init(fileID: String, line: UInt) {
        self.fileID = fileID
        self.line = line
    }
}

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
        /// A query matched nothing in the scoped hierarchy.
        case notFound
        /// A query matched more than one element, so the target is not uniquely identified.
        case ambiguous
        /// The matched element does not support the requested action (for example, tapping a label).
        case unsupported
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
    /// The test call site that invoked the failing Fleet entry point, when the entry point captures it.
    public let source: FleetSourceLocation?
    /// Bounded context collected when the failure happened (hosted screens only), or `nil`.
    public let diagnostics: FleetDiagnostics?

    public init(kind: Kind, action: String, target: String, state: String, reason: String, source: FleetSourceLocation? = nil, diagnostics: FleetDiagnostics? = nil) {
        self.diagnostics = diagnostics
        self.source = source
        self.kind = kind
        self.action = action
        self.target = target
        self.state = state
        self.reason = reason
    }
}

extension FleetFailure: CustomStringConvertible, LocalizedError {
    public var description: String {
        let base = "Fleet could not \(action) on \(target) (\(kind.rawValue)): \(state). \(reason)"
        guard let source else { return base }
        return "\(base) [called at \(source.fileID):\(source.line)]"
    }

    /// A copy of this failure attributed to `source` unless it already has one.
    func attributed(to source: FleetSourceLocation) -> FleetFailure {
        guard self.source == nil else { return self }
        return FleetFailure(kind: kind, action: action, target: target, state: state, reason: reason, source: source, diagnostics: diagnostics)
    }

    /// A copy carrying `diagnostics` unless it already has some.
    func with(diagnostics: FleetDiagnostics) -> FleetFailure {
        guard self.diagnostics == nil else { return self }
        return FleetFailure(kind: kind, action: action, target: target, state: state, reason: reason, source: source, diagnostics: diagnostics)
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

/// Screenshot evidence: either real pixels from the current hosted interface or an explicit reason
/// none exists. Fleet never fabricates or remounts a copy to produce one.
public enum FleetScreenshotEvidence: Sendable, Equatable {
    case captured(png: Data)
    case unavailable(reason: String)
}

/// A named blob a test framework adapter can retain as a local/CI attachment.
public struct FleetAttachment: Sendable, Equatable {
    public let name: String
    /// A uniform type identifier such as `public.plain-text` or `public.png`.
    public let uniformTypeIdentifier: String
    public let data: Data
}

/// Bounded, framework-independent context about what a hosted test attempted and could observe.
/// Collected only on failure; it contains no assertion-framework types.
public struct FleetDiagnostics: Sendable, Equatable {
    /// The most recent action attempted through the hosted view, such as `tap "Delete"`.
    public var lastAction: String?
    /// The scoped query of the failing request, when the failure came from one.
    public var query: String?
    public var matchCount: Int?
    /// Descriptions of (at most `FleetDiagnostics.maxCandidates`) elements the query considered.
    public var candidates: [String] = []
    /// Controller and accessibility hierarchy, bounded by depth and node count.
    public var hierarchy: String = ""
    /// Resolved window environment (size, style, content size, size classes) and window state.
    public var environment: String = ""
    /// Lifecycle and presentation state of the hosted screen.
    public var lifecycle: String = ""
    /// The opt-in action/transition trace (oldest first); empty unless tracing was enabled.
    public var trace: [String] = []
    public var traceDroppedCount = 0
    public var screenshot: FleetScreenshotEvidence = .unavailable(reason: "not collected")

    public static let maxCandidates = 10
    public static let maxHierarchyDepth = 8
    public static let maxHierarchyNodes = 150

    /// A plain-text report suitable for a failure message or attachment.
    public var report: String {
        var lines: [String] = []
        lines.append("Last action: \(lastAction ?? "none recorded")")
        if let query {
            lines.append("Query: \(query) (matches: \(matchCount.map(String.init) ?? "unknown"))")
            for candidate in candidates { lines.append("  candidate: \(candidate)") }
        }
        lines.append("Environment: \(environment)")
        lines.append("Lifecycle: \(lifecycle)")
        switch screenshot {
        case .captured(let png): lines.append("Screenshot: captured (\(png.count) bytes)")
        case .unavailable(let reason): lines.append("Screenshot: unavailable (\(reason))")
        }
        if !trace.isEmpty {
            lines.append("Trace (\(trace.count) entries\(traceDroppedCount > 0 ? ", \(traceDroppedCount) older dropped" : "")):")
            for entry in trace { lines.append("  \(entry)") }
        }
        lines.append("Hierarchy:")
        lines.append(hierarchy)
        return lines.joined(separator: "\n")
    }

    /// Attachments for a framework adapter: the text report and, when captured, the screenshot.
    public var attachments: [FleetAttachment] {
        var result = [FleetAttachment(name: "Fleet diagnostics", uniformTypeIdentifier: "public.plain-text", data: Data(report.utf8))]
        if case .captured(let png) = screenshot {
            result.append(FleetAttachment(name: "Fleet hosted screenshot", uniformTypeIdentifier: "public.png", data: png))
        }
        return result
    }
}

extension FleetFailure {
    /// The failure message followed by its diagnostics report, for adapters to report as one issue.
    public var detailedDescription: String {
        guard let diagnostics else { return description }
        return description + "\n" + diagnostics.report
    }
}
