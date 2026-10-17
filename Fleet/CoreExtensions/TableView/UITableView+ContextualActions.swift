#if os(iOS)
import UIKit

/// The edge of a table view row from which a swipe reveals contextual actions.
public enum SwipeActionEdge: String {
    /// Actions returned by `tableView(_:leadingSwipeActionsConfigurationForRowAt:)`.
    case leading
    /// Actions returned by `tableView(_:trailingSwipeActionsConfigurationForRowAt:)`.
    case trailing
}

@MainActor
private final class ContextualActionCompletion {
    var result: Bool?
    var callCount = 0

    func complete(_ actionPerformed: Bool) {
        callCount += 1
        if result == nil {
            result = actionPerformed
        }
    }
}

extension UITableView {
    /**
     Mimic a user invoking the contextual (swipe) action with the given title on the row at
     the given index path.

     Fleet asks the table view's delegate for the swipe actions configuration on the given edge, and
     calls the public `handler` of the one matching `UIContextualAction` exactly once. The handler receives
     the row's cell (or a cell from the data source, if the row is not displayed) as its source view and a
     completion closure. This does not prove that the action is reachable by a physical swipe, hit testing,
     or accessibility; it establishes that the delegate vends the action for that row and that
     its handler runs and completes.

     Before the handler runs Fleet calls `tableView(_:willBeginEditingRowAt:)` on the delegate, and after
     completion it calls `tableView(_:didEndEditingRowAt:)`.

     - parameters:
        - title: The title of the action to invoke. It must match exactly one action on that edge.
        - edge: The edge whose actions to search.
        - indexPath: The index path of the row.
        - completionTimeout: The longest time, in seconds, to run the run loop waiting for the handler to
          call its completion closure. Handlers may complete asynchronously.

     - returns:
     The value the handler passed to its completion closure: whether the action reports that it was performed.

     - throws:
     A `FleetError` if there is no data source or delegate, if the delegate does not implement the swipe
     configuration method for the edge, if the row does not exist or cannot be edited, if no action or more than one
     action has that title, or if the handler does not complete within the timeout.
     */
    @discardableResult
    public func performContextualAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) -> Bool {
        fleet_raisingLegacy(false, { try performContextualActionOrThrow(withTitle: title, edge: edge, at: indexPath, completionTimeout: completionTimeout) })
    }

    /**
     Like `performContextualAction(withTitle:edge:at:completionTimeout:)`, but reports failures as Swift errors
     instead of raising an `NSException`.

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, delegate, or swipe configuration method,
     `.invalidInput` when the row, action, or title match is missing or ambiguous, `.unavailableInteraction` when
     the data source does not allow editing the row, or `.timedOut` when the handler does not complete in time.
     */
    @discardableResult
    public func performContextualActionOrThrow(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) throws -> Bool {
        let (delegate, action) = try resolveAction(withTitle: title, edge: edge, at: indexPath)
        return try invoke(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    /**
     Asynchronous form of `performContextualAction(withTitle:edge:at:completionTimeout:)`.

     Instead of running the run loop synchronously, this suspends the calling task while waiting, so handlers
     that complete from a `Task { @MainActor in ... }` can run even when the caller is itself on the main actor.
     Prefer this form from `async` tests.
     */
    @discardableResult
    public func performContextualAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async -> Bool {
        do {
            return try await performContextualActionOrThrow(withTitle: title, edge: edge, at: indexPath, completionTimeout: completionTimeout)
        } catch let failure as FleetFailure {
            FleetError(Fleet.TableViewError.legacy(failure)).raise()
        } catch is CancellationError {
            // The non-throwing form cannot propagate cancellation; use the `OrThrow` form to observe it.
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
        return false
    }

    /// Asynchronous form of `performContextualActionOrThrow(withTitle:edge:at:completionTimeout:)`; it suspends
    /// the calling task while waiting. A cancelled task propagates `CancellationError` unchanged.
    @discardableResult
    public func performContextualActionOrThrow(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async throws -> Bool {
        let (delegate, action) = try resolveAction(withTitle: title, edge: edge, at: indexPath)
        return try await invokeAsync(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    /**
     Mimic a user invoking the contextual (swipe) action at the given position on the row at the given index
     path. Use this when titles are missing or duplicated. Index `0` is the first action in the configuration
     returned by the delegate.

     See `performContextualAction(withTitle:edge:at:completionTimeout:)` for exactly what this establishes.

     - parameters:
        - actionIndex: The zero-based position of the action in the configuration's `actions`.
        - edge: The edge whose actions to use.
        - indexPath: The index path of the row.
        - completionTimeout: The longest time, in seconds, to wait for the handler to call its completion closure.

     - returns:
     The value the handler passed to its completion closure.

     - throws:
     A `FleetError` for the same reasons as the title-based variant, or if the index is out of range.
     */
    @discardableResult
    public func performContextualAction(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) -> Bool {
        fleet_raisingLegacy(false, { try performContextualActionOrThrow(atIndex: actionIndex, edge: edge, at: indexPath, completionTimeout: completionTimeout) })
    }

    /// Like `performContextualAction(atIndex:edge:at:completionTimeout:)`, but throws a `FleetFailure`
    /// (see `performContextualActionOrThrow(withTitle:edge:at:completionTimeout:)`) instead of raising an `NSException`.
    @discardableResult
    public func performContextualActionOrThrow(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) throws -> Bool {
        let (delegate, action) = try resolveAction(atIndex: actionIndex, edge: edge, at: indexPath)
        return try invoke(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    /// Asynchronous form of `performContextualAction(atIndex:edge:at:completionTimeout:)`. It suspends the
    /// calling task while waiting; see `performContextualAction(withTitle:edge:at:completionTimeout:)` async.
    @discardableResult
    public func performContextualAction(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async -> Bool {
        do {
            return try await performContextualActionOrThrow(atIndex: actionIndex, edge: edge, at: indexPath, completionTimeout: completionTimeout)
        } catch let failure as FleetFailure {
            FleetError(Fleet.TableViewError.legacy(failure)).raise()
        } catch is CancellationError {
            // The non-throwing form cannot propagate cancellation; use the `OrThrow` form to observe it.
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
        return false
    }

    /// Asynchronous form of `performContextualActionOrThrow(atIndex:edge:at:completionTimeout:)`.
    @discardableResult
    public func performContextualActionOrThrow(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async throws -> Bool {
        let (delegate, action) = try resolveAction(atIndex: actionIndex, edge: edge, at: indexPath)
        return try await invokeAsync(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    private func contextualFailure(_ kind: FleetFailure.Kind, _ error: Fleet.TableViewError, at indexPath: IndexPath, state: String) -> FleetFailure {
        FleetFailure(kind: kind, action: "perform contextual action",
                     target: "UITableView row \(indexPath.row) in section \(indexPath.section)",
                     state: state, reason: error.errorMessage)
    }

    private func resolveAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath) throws -> (UITableViewDelegate, UIContextualAction) {
        let delegate = try validatedDelegate(edge: edge, at: indexPath)
        let actions = contextualActions(from: delegate, edge: edge, at: indexPath)
        if actions.isEmpty {
            throw contextualFailure(.invalidInput, .noContextualActions(at: indexPath, edge: edge.rawValue), at: indexPath,
                                    state: "the row has no \(edge.rawValue) contextual actions")
        }

        let matches = actions.filter { $0.title == title }
        if matches.isEmpty {
            throw contextualFailure(.invalidInput, .contextualActionDoesNotExist(at: indexPath, edge: edge.rawValue, title: title), at: indexPath,
                                    state: "no \(edge.rawValue) action is titled '\(title)'")
        }
        if matches.count > 1 {
            throw contextualFailure(.invalidInput, .ambiguousContextualAction(at: indexPath, edge: edge.rawValue, title: title, matchCount: matches.count), at: indexPath,
                                    state: "\(matches.count) \(edge.rawValue) actions are titled '\(title)'")
        }
        return (delegate, matches[0])
    }

    private func resolveAction(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath) throws -> (UITableViewDelegate, UIContextualAction) {
        let delegate = try validatedDelegate(edge: edge, at: indexPath)
        let actions = contextualActions(from: delegate, edge: edge, at: indexPath)
        if actionIndex < 0 || actionIndex >= actions.count {
            throw contextualFailure(.invalidInput, .contextualActionIndexOutOfRange(at: indexPath, edge: edge.rawValue, index: actionIndex, count: actions.count), at: indexPath,
                                    state: "the row has \(actions.count) \(edge.rawValue) action(s)")
        }
        return (delegate, actions[actionIndex])
    }

    private func validatedDelegate(edge: SwipeActionEdge, at indexPath: IndexPath) throws -> UITableViewDelegate {
        let userAction = "perform contextual action"
        // UIKit's `section`/`row` accessors trap when the path has fewer than two components.
        guard indexPath.count >= 2 else {
            throw FleetFailure(kind: .invalidInput, action: userAction,
                               target: "UITableView index path \(Array(indexPath))",
                               state: "the index path has \(indexPath.count) component(s)",
                               reason: "A table view index path needs a section and a row.")
        }
        guard let dataSource = dataSource else {
            throw contextualFailure(.invalidSetup, .dataSourceRequired(userAction: userAction), at: indexPath,
                                    state: "the table view has no data source")
        }

        guard let delegate = delegate else {
            throw contextualFailure(.invalidSetup, .delegateRequired(userAction: userAction), at: indexPath,
                                    state: "the table view has no delegate")
        }

        let selector: Selector
        let selectorName: String
        switch edge {
        case .leading:
            selector = #selector(UITableViewDelegate.tableView(_:leadingSwipeActionsConfigurationForRowAt:))
            selectorName = "UITableViewDelegate.tableView(_:leadingSwipeActionsConfigurationForRowAt:)"
        case .trailing:
            selector = #selector(UITableViewDelegate.tableView(_:trailingSwipeActionsConfigurationForRowAt:))
            selectorName = "UITableViewDelegate.tableView(_:trailingSwipeActionsConfigurationForRowAt:)"
        }
        if !delegate.responds(to: selector) {
            throw contextualFailure(.invalidSetup, .incompleteDelegate(required: selectorName, userAction: userAction), at: indexPath,
                                    state: "the delegate does not implement the \(edge.rawValue) swipe configuration method")
        }

        if indexPath.section < 0 || indexPath.section >= numberOfSections {
            throw contextualFailure(.invalidInput, .sectionDoesNotExist(sectionNumber: indexPath.section), at: indexPath,
                                    state: "the table view has \(numberOfSections) section(s)")
        }

        if indexPath.row < 0 || indexPath.row >= numberOfRows(inSection: indexPath.section) {
            throw contextualFailure(.invalidInput, .rowDoesNotExist(at: indexPath), at: indexPath,
                                    state: "section \(indexPath.section) has \(numberOfRows(inSection: indexPath.section)) row(s)")
        }

        // UIKit treats rows as editable unless the data source says otherwise.
        if dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:canEditRowAt:))),
           !dataSource.tableView!(self, canEditRowAt: indexPath) {
            throw contextualFailure(.unavailableInteraction, .rejectedAction(at: indexPath, reason: "Table view data source does not allow editing of that row."), at: indexPath,
                                    state: "the data source reports the row as not editable")
        }

        return delegate
    }

    private func contextualActions(from delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath) -> [UIContextualAction] {
        let configuration: UISwipeActionsConfiguration?
        switch edge {
        case .leading:
            configuration = delegate.tableView?(self, leadingSwipeActionsConfigurationForRowAt: indexPath)
        case .trailing:
            configuration = delegate.tableView?(self, trailingSwipeActionsConfigurationForRowAt: indexPath)
        }
        return configuration?.actions ?? []
    }

    private func begin(_ action: UIContextualAction, delegate: UITableViewDelegate, at indexPath: IndexPath) throws -> ContextualActionCompletion {
        let sourceView: UIView = try cellForRow(at: indexPath) ?? fetchCellOrThrow(at: indexPath)
        let completion = ContextualActionCompletion()

        delegate.tableView?(self, willBeginEditingRowAt: indexPath)
        action.handler(action, sourceView) { completion.complete($0) }
        return completion
    }

    private func finish(_ completion: ContextualActionCompletion, _ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) throws -> Bool {
        guard let result = completion.result else {
            throw contextualFailure(.timedOut, .contextualActionDidNotComplete(at: indexPath, edge: edge.rawValue, title: action.title, timeout: timeout), at: indexPath,
                                    state: "the handler did not call its completion closure within \(timeout) seconds")
        }

        delegate.tableView?(self, didEndEditingRowAt: indexPath)
        return result
    }

    private func invoke(_ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) throws -> Bool {
        let completion = try begin(action, delegate: delegate, at: indexPath)
        let deadline = Date(timeIntervalSinceNow: timeout)
        while completion.result == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return try finish(completion, action, delegate: delegate, edge: edge, at: indexPath, timeout: timeout)
    }

    private func invokeAsync(_ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) async throws -> Bool {
        let completion = try begin(action, delegate: delegate, at: indexPath)
        let deadline = Date(timeIntervalSinceNow: timeout)
        while completion.result == nil && Date() < deadline {
            await Task.yield()
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return try finish(completion, action, delegate: delegate, edge: edge, at: indexPath, timeout: timeout)
    }
}

#endif
