import Foundation

extension Fleet {
    enum CollectionViewError: FleetErrorDefinition {
        case dataSourceRequired(userAction: String)
        case rejectedAction(at: IndexPath, reason: String)
        case itemDoesNotExist(at: IndexPath)
        case sectionDoesNotExist(sectionNumber: Int)
        case cellUnavailable(at: IndexPath)
        case mismatchedCellType(at: IndexPath, foundType: AnyClass, requestedType: AnyClass)

        var errorMessage: String {
            switch self {
            case .dataSourceRequired(let userAction):
                return "Data source required to \(userAction)."
            case .rejectedAction(let indexPath, let reason):
                return "Interaction with item \(indexPath.item) in section \(indexPath.section) rejected: \(reason)"
            case .itemDoesNotExist(let indexPath):
                return "Collection view has no item \(indexPath.item) in section \(indexPath.section)."
            case .sectionDoesNotExist(let sectionNumber):
                return "Collection view has no section \(sectionNumber)."
            case .cellUnavailable(let indexPath):
                return "Collection view could not display a cell at item \(indexPath.item) in section \(indexPath.section)."
            case .mismatchedCellType(let indexPath, let foundType, let requestedType):
                return "Cell at item \(indexPath.item) in section \(indexPath.section) is of type `\(foundType)` (wanted `\(requestedType)`)."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.CollectionViewError") } }
    }
}
