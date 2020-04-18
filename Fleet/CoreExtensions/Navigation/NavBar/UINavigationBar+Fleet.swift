extension Fleet {
    enum NavBarError: FleetErrorDefinition {
        case noNavBarItems
        case titleNotFound(_ title: String)

        var errorMessage: String {
            get {
                switch self {
                case .noNavBarItems:
                    return "No nav bar items found in the view controller."
                case .titleNotFound(let title):
                    return "No item with title '\(title)' found in nav bar."
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

     - throws:
        A `FleetError` if a navigation bar item with the given title cannot be found, if there
        in the are no items in the navigation bar, or if the item's action is not properly set up.
     */
    public func tapTopItem(withTitle title: String) {
        guard let navBarItem = topItem else {
            FleetError(Fleet.NavBarError.noNavBarItems).raise()
            return
        }

        var allButtonItems: [UIBarButtonItem] = []
        if let rightItems = navBarItem.rightBarButtonItems {
            allButtonItems.append(contentsOf: rightItems)
        }
        if let leftItems = navBarItem.leftBarButtonItems {
            allButtonItems.append(contentsOf: leftItems)
        }

        let matchingNavBarItemOpt = allButtonItems.first() { item in
            item.title == title
        }

        guard let matchingNavBarItem = matchingNavBarItemOpt else {
            FleetError(Fleet.NavBarError.titleNotFound(title)).raise()
            return
        }

        matchingNavBarItem.tap()
    }
}
