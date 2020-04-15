extension Fleet {
    enum ToolbarError: FleetErrorDefinition {
        case noToolbarItems
        case titleNotFound(_ title: String)

        var errorMessage: String {
            get {
                switch self {
                case .noToolbarItems:
                    return "No toolbar items found in the view controller."
                case .titleNotFound(let title):
                    return "No item with title '\(title)' found in toolbar."
                }
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.ToolbarError") } }
    }
}

extension UIToolbar {
    public func tapItem(withTitle title: String) {
        guard let toolbarItems = items else {
            FleetError(Fleet.ToolbarError.noToolbarItems).raise()
            return
        }

        let matchingToolbarItemOpt = toolbarItems.first() { item in
            return item.title == title
        }

        guard let matchingToolbarItem = matchingToolbarItemOpt else {
            FleetError(Fleet.ToolbarError.titleNotFound(title)).raise()
            return
        }

        matchingToolbarItem.tap()
    }
}
