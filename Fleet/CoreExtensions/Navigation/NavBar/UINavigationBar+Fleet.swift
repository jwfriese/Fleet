import UIKit

extension Fleet {
    enum NavBarError: FleetErrorDefinition, Error {
        case noNavBarItems
        case titleNotFound(_ title: String)
        case ambiguousTitle(_ title: String, count: Int)

        var errorMessage: String {
            get {
                switch self {
                case .noNavBarItems:
                    return "No nav bar items found in the view controller."
                case .titleNotFound(let title):
                    return "No item with title '\(title)' found in nav bar."
                case .ambiguousTitle(let title, let count):
                    return "\(count) items with title '\(title)' found in nav bar; Fleet will not guess which to tap."
                }
            }
        }

        var name: NSExceptionName {
            get {
                NSExceptionName(rawValue: "Fleet.NavBarError")
            }
        }
    }
}

extension UINavigationBar {
    /**
     Mimics a tap on an item with the given title from the navigation bar's top item,
     firing any associated behavior.

     - parameters:
        - title:  The title of the item to tap

     Title lookup is unambiguous across the left and right items: if more than one
     item has the title, nothing is tapped.

     - throws:
        A `FleetError` if a navigation bar item with the given title cannot be found, if more
        than one item has the title, if there are no items in the navigation bar, or if the
        item's action is not properly set up.
     */
    public func tapTopItem(withTitle title: String) {
        do {
            try matchingItem(withTitle: title).tap()
        } catch let error as Fleet.NavBarError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `tapTopItem(withTitle:)`, but reports failures as a thrown `FleetFailure`
     (`.invalidSetup` without a top item, `.invalidInput` for a missing or ambiguous title, or the
     failure of the item's own `tapOrThrow()`).
     */
    public func tapTopItemOrThrow(withTitle title: String) throws {
        let item: UIBarButtonItem
        do {
            item = try matchingItem(withTitle: title)
        } catch let error as Fleet.NavBarError {
            let kind: FleetFailure.Kind = { if case .noNavBarItems = error { return .invalidSetup } else { return .invalidInput } }()
            throw FleetFailure(error, kind: kind, action: "tap navigation bar item", target: "UINavigationBar item '\(title)'")
        }
        try item.tapOrThrow()
    }

    private func matchingItem(withTitle title: String) throws(Fleet.NavBarError) -> UIBarButtonItem {
        guard let navBarItem = topItem else {
            throw .noNavBarItems
        }

        var allButtonItems: [UIBarButtonItem] = []
        if let rightItems = navBarItem.rightBarButtonItems {
            allButtonItems.append(contentsOf: rightItems)
        }
        if let leftItems = navBarItem.leftBarButtonItems {
            allButtonItems.append(contentsOf: leftItems)
        }

        let matches = allButtonItems.filter { $0.title == title }
        guard let match = matches.first else {
            throw .titleNotFound(title)
        }
        guard matches.count == 1 else {
            throw .ambiguousTitle(title, count: matches.count)
        }
        return match
    }
}
