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

        var errorMessage: String {
            switch self {
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
        case cellNotDisplayed(at: IndexPath)
            case .mismatchedCellType(let indexPath, let foundType, let requestedType):
                return "Cell at row \(indexPath.row) in section \(indexPath.section) is of type `\(foundType)` (wanted `\(requestedType)`)."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.TableViewError") } }
    }
}

extension UITableView {
    /// Raises a `FleetError` and returns false if the index path is not a row of this table view.
    func fleet_validateExistingRow(at indexPath: IndexPath) -> Bool {
        if indexPath.section < 0 || indexPath.section >= numberOfSections {
            FleetError(Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return false
        }
        if indexPath.row < 0 || indexPath.row >= numberOfRows(inSection: indexPath.section) {
            FleetError(Fleet.TableViewError.rowDoesNotExist(at: indexPath)).raise()
            return false
        }
        return true
    }
}
