extension Fleet {
    enum TableViewError: FleetErrorDefinition {
        case dataSourceRequired(userAction: String)
        case delegateRequired(userAction: String)
        case incompleteDelegate(required: String, userAction: String)
        case rejectedAction(at: IndexPath, reason: String)
        case rowDoesNotExist(at: IndexPath)
        case sectionDoesNotExist(sectionNumber: Int)
        case cellActionDoesNotExist(at: IndexPath, title: String)
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
            case .cellActionDoesNotExist(let indexPath, let title):
                return "Could not find edit action with title '\(title)' at row \(indexPath.row) in section \(indexPath.section)."
            case .mismatchedCellType(let indexPath, let foundType, let requestedType):
                return "Cell at row \(indexPath.row) in section \(indexPath.section) is of type `\(foundType)` (wanted `\(requestedType)`)."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.TableViewError") } }
    }
}
