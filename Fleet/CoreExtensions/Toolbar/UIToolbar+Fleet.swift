#if os(iOS)
import UIKit

extension Fleet {
    enum ToolbarError: FleetErrorDefinition, Error {
        case noToolbarItems
        case titleNotFound(_ title: String)
        case ambiguousTitle(_ title: String, count: Int)

        var errorMessage: String {
            get {
                switch self {
                case .noToolbarItems:
                    return "No toolbar items found in the view controller."
                case .titleNotFound(let title):
                    return "No item with title '\(title)' found in toolbar."
                case .ambiguousTitle(let title, let count):
                    return "\(count) items with title '\(title)' found in toolbar; Fleet will not guess which to tap."
                }
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.ToolbarError") } }
    }
}

extension UIToolbar {
    /**
     Mimics a tap on the toolbar item with the given title,
     firing any associated behavior.

     - parameters:
        - title:  The title of the item to tap

     Title lookup is unambiguous: if more than one item has the title, nothing is tapped.

     - throws:
        A `FleetError` if a toolbar item with the given title cannot be found, if more than one
        item has the title, if there are no items in the toolbar, or if the item's action is not
        properly set up.
     */
    public func tapItem(withTitle title: String) {
        do {
            try matchingItem(withTitle: title).tap()
        } catch let error as Fleet.ToolbarError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `tapItem(withTitle:)`, but reports failures as a thrown `FleetFailure`
     (`.invalidSetup` without items, `.invalidInput` for a missing or ambiguous title, or the
     failure of the item's own `tapOrThrow()`).
     */
    public func tapItemOrThrow(withTitle title: String) throws {
        let item: UIBarButtonItem
        do {
            item = try matchingItem(withTitle: title)
        } catch let error as Fleet.ToolbarError {
            let kind: FleetFailure.Kind = { if case .noToolbarItems = error { return .invalidSetup } else { return .invalidInput } }()
            throw FleetFailure(error, kind: kind, action: "tap toolbar item", target: "UIToolbar item '\(title)'")
        }
        try item.tapOrThrow()
    }

    private func matchingItem(withTitle title: String) throws(Fleet.ToolbarError) -> UIBarButtonItem {
        guard let toolbarItems = items else {
            throw .noToolbarItems
        }

        let matches = toolbarItems.filter { $0.title == title }
        guard let match = matches.first else {
            throw .titleNotFound(title)
        }
        guard matches.count == 1 else {
            throw .ambiguousTitle(title, count: matches.count)
        }
        return match
    }
}

#endif
