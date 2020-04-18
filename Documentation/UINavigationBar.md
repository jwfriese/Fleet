# UINavigationBar

## Methods
`public func tapTopItem(withTitle title: String)`

Searches the `topItem` of a navigation bar for an item with a
title equal to the parameter `title`. If found, it fires the action
associated with that item.

Raises a `FleetError` if a navigation bar item with the given title
cannot be found, if there in the are no items in the navigation bar,
or if the item's action is not properly set up.
