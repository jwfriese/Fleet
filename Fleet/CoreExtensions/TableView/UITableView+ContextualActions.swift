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
        guard let (delegate, action) = resolveAction(withTitle: title, edge: edge, at: indexPath) else { return false }
        return invoke(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    /**
     Asynchronous form of `performContextualAction(withTitle:edge:at:completionTimeout:)`.

     Instead of running the run loop synchronously, this suspends the calling task while waiting, so handlers
     that complete from a `Task { @MainActor in ... }` can run even when the caller is itself on the main actor.
     Prefer this form from `async` tests.
     */
    @discardableResult
    public func performContextualAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async -> Bool {
        guard let (delegate, action) = resolveAction(withTitle: title, edge: edge, at: indexPath) else { return false }
        return await invokeAsync(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
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
        guard let (delegate, action) = resolveAction(atIndex: actionIndex, edge: edge, at: indexPath) else { return false }
        return invoke(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    /// Asynchronous form of `performContextualAction(atIndex:edge:at:completionTimeout:)`. It suspends the
    /// calling task while waiting; see `performContextualAction(withTitle:edge:at:completionTimeout:)` async.
    @discardableResult
    public func performContextualAction(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) async -> Bool {
        guard let (delegate, action) = resolveAction(atIndex: actionIndex, edge: edge, at: indexPath) else { return false }
        return await invokeAsync(action, delegate: delegate, edge: edge, at: indexPath, timeout: completionTimeout)
    }

    private func resolveAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath) -> (UITableViewDelegate, UIContextualAction)? {
        guard let delegate = validatedDelegate(edge: edge, at: indexPath) else { return nil }
        let actions = contextualActions(from: delegate, edge: edge, at: indexPath)
        if actions.isEmpty {
            FleetError(Fleet.TableViewError.noContextualActions(at: indexPath, edge: edge.rawValue)).raise()
            return nil
        }

        let matches = actions.filter { $0.title == title }
        if matches.isEmpty {
            FleetError(Fleet.TableViewError.contextualActionDoesNotExist(at: indexPath, edge: edge.rawValue, title: title)).raise()
            return nil
        }
        if matches.count > 1 {
            FleetError(Fleet.TableViewError.ambiguousContextualAction(at: indexPath, edge: edge.rawValue, title: title, matchCount: matches.count)).raise()
            return nil
        }
        return (delegate, matches[0])
    }

    private func resolveAction(atIndex actionIndex: Int, edge: SwipeActionEdge, at indexPath: IndexPath) -> (UITableViewDelegate, UIContextualAction)? {
        guard let delegate = validatedDelegate(edge: edge, at: indexPath) else { return nil }
        let actions = contextualActions(from: delegate, edge: edge, at: indexPath)
        if actionIndex < 0 || actionIndex >= actions.count {
            FleetError(Fleet.TableViewError.contextualActionIndexOutOfRange(at: indexPath, edge: edge.rawValue, index: actionIndex, count: actions.count)).raise()
            return nil
        }
        return (delegate, actions[actionIndex])
    }

    private func validatedDelegate(edge: SwipeActionEdge, at indexPath: IndexPath) -> UITableViewDelegate? {
        let userAction = "perform contextual action"
        guard let dataSource = dataSource else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: userAction)).raise()
            return nil
        }

        guard let delegate = delegate else {
            FleetError(Fleet.TableViewError.delegateRequired(userAction: userAction)).raise()
            return nil
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
            FleetError(Fleet.TableViewError.incompleteDelegate(required: selectorName, userAction: userAction)).raise()
            return nil
        }

        if indexPath.section < 0 || indexPath.section >= numberOfSections {
            FleetError(Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return nil
        }

        if indexPath.row < 0 || indexPath.row >= numberOfRows(inSection: indexPath.section) {
            FleetError(Fleet.TableViewError.rowDoesNotExist(at: indexPath)).raise()
            return nil
        }

        // UIKit treats rows as editable unless the data source says otherwise.
        if dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:canEditRowAt:))),
           !dataSource.tableView!(self, canEditRowAt: indexPath) {
            FleetError(Fleet.TableViewError.rejectedAction(at: indexPath, reason: "Table view data source does not allow editing of that row.")).raise()
            return nil
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

    private func begin(_ action: UIContextualAction, delegate: UITableViewDelegate, at indexPath: IndexPath) -> ContextualActionCompletion {
        let sourceView: UIView = cellForRow(at: indexPath) ?? fetchCell(at: indexPath)
        let completion = ContextualActionCompletion()

        delegate.tableView?(self, willBeginEditingRowAt: indexPath)
        action.handler(action, sourceView) { completion.complete($0) }
        return completion
    }

    private func finish(_ completion: ContextualActionCompletion, _ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) -> Bool {
        guard let result = completion.result else {
            FleetError(Fleet.TableViewError.contextualActionDidNotComplete(at: indexPath, edge: edge.rawValue, title: action.title, timeout: timeout)).raise()
            return false
        }

        delegate.tableView?(self, didEndEditingRowAt: indexPath)
        return result
    }

    private func invoke(_ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) -> Bool {
        let completion = begin(action, delegate: delegate, at: indexPath)
        let deadline = Date(timeIntervalSinceNow: timeout)
        while completion.result == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        return finish(completion, action, delegate: delegate, edge: edge, at: indexPath, timeout: timeout)
    }

    private func invokeAsync(_ action: UIContextualAction, delegate: UITableViewDelegate, edge: SwipeActionEdge, at indexPath: IndexPath, timeout: TimeInterval) async -> Bool {
        let completion = begin(action, delegate: delegate, at: indexPath)
        let deadline = Date(timeIntervalSinceNow: timeout)
        while completion.result == nil && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return finish(completion, action, delegate: delegate, edge: edge, at: indexPath, timeout: timeout)
    }
}

#endif
