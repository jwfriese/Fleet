import UIKit

extension Fleet {
    enum TableViewError: FleetErrorDefinition {
        case dataSourceRequired(userAction: String)
        case delegateRequired(userAction: String)
        case incompleteDelegate(required: String, userAction: String)
        case rejectedAction(at: IndexPath, reason: String)
        case rowDoesNotExist(at: IndexPath)
        case sectionDoesNotExist(sectionNumber: Int)
        case noContextualActions(at: IndexPath, edge: String)
        case contextualActionDoesNotExist(at: IndexPath, edge: String, title: String)
        case ambiguousContextualAction(at: IndexPath, edge: String, title: String, matchCount: Int)
        case contextualActionIndexOutOfRange(at: IndexPath, edge: String, index: Int, count: Int)
        case contextualActionDidNotComplete(at: IndexPath, edge: String, title: String?, timeout: TimeInterval)
        case cellNotDisplayed(at: IndexPath)
        case mismatchedCellType(at: IndexPath, foundType: AnyClass, requestedType: AnyClass)
        case legacy(FleetFailure)

        var errorMessage: String {
            switch self {
            case .legacy(let failure):
                return failure.reason
            case .dataSourceRequired(let userAction):
                return "Data source required to \(userAction)."
            case .delegateRequired(let userAction):
                return "Delegate required to \(userAction)."
            case .incompleteDelegate(let required, let userAction):
                return "Delegate must implement \(required) to \(userAction)."
            case .rejectedAction(let indexPath, let reason):
                return "Interaction with row \(indexPath.row) in section \(indexPath.section) rejected: \(reason)"
            case .rowDoesNotExist(let indexPath):
                return "Table view has no row \(indexPath.row) in section \(indexPath.section)."
            case .sectionDoesNotExist(let sectionNumber):
                return "Table view has no section \(sectionNumber)."
            case .noContextualActions(let indexPath, let edge):
                return "Row \(indexPath.row) in section \(indexPath.section) has no \(edge) contextual actions."
            case .contextualActionDoesNotExist(let indexPath, let edge, let title):
                return "Could not find \(edge) contextual action with title '\(title)' at row \(indexPath.row) in section \(indexPath.section)."
            case .ambiguousContextualAction(let indexPath, let edge, let title, let matchCount):
                return "Found \(matchCount) \(edge) contextual actions with title '\(title)' at row \(indexPath.row) in section \(indexPath.section); select one by index instead."
            case .contextualActionIndexOutOfRange(let indexPath, let edge, let index, let count):
                return "Row \(indexPath.row) in section \(indexPath.section) has \(count) \(edge) contextual actions; no action at index \(index)."
            case .contextualActionDidNotComplete(let indexPath, let edge, let title, let timeout):
                return "The \(edge) contextual action '\(title ?? "(untitled)")' at row \(indexPath.row) in section \(indexPath.section) did not call its completion handler within \(timeout) seconds."
            case .cellNotDisplayed(let indexPath):
                return "Cell at row \(indexPath.row) in section \(indexPath.section) is not currently displayed by the table view."
            case .mismatchedCellType(let indexPath, let foundType, let requestedType):
                return "Cell at row \(indexPath.row) in section \(indexPath.section) is of type `\(foundType)` (wanted `\(requestedType)`)."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.TableViewError") } }
    }
}

extension UITableView {
    /// Throws an `.invalidInput` failure if the index path is not a row of this table view.
    /// The `reason` keeps the wording the raising helpers have always used.
    func fleet_requireExistingRow(at indexPath: IndexPath, action: String) throws {
        // UIKit's `section`/`row` accessors trap when the path has fewer than two components.
        guard indexPath.count >= 2 else {
            throw FleetFailure(kind: .invalidInput, action: action,
                               target: "UITableView index path \(Array(indexPath))",
                               state: "the index path has \(indexPath.count) component(s)",
                               reason: "A table view index path needs a section and a row.")
        }
        let target = "UITableView row \(indexPath.row) in section \(indexPath.section)"
        if indexPath.section < 0 || indexPath.section >= numberOfSections {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the table view has \(numberOfSections) section(s)",
                               reason: "Table view has no section \(indexPath.section).")
        }
        if indexPath.row < 0 || indexPath.row >= numberOfRows(inSection: indexPath.section) {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "section \(indexPath.section) has \(numberOfRows(inSection: indexPath.section)) row(s)",
                               reason: "Table view has no row \(indexPath.row) in section \(indexPath.section).")
        }
    }

    /// Throws `.invalidSetup` when the table view has no data source.
    func fleet_requireDataSource(action: String, userAction: String, target: String) throws {
        guard dataSource != nil else {
            throw FleetFailure(kind: .invalidSetup, action: action, target: target,
                               state: "the table view has no data source",
                               reason: "Data source required to \(userAction).")
        }
    }
}

/// Runs a throwing table helper, converting a `FleetFailure` into the raised `FleetError` that the
/// non-throwing helpers have always produced.
@MainActor
func fleet_raisingLegacy<T>(_ fallback: @autoclosure () -> T, _ body: () throws -> T) -> T {
    do {
        return try body()
    } catch let failure as FleetFailure {
        FleetError(Fleet.TableViewError.legacy(failure)).raise()
    } catch {
        FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
    }
    return fallback()
}
