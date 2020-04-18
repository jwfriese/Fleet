import UIKit
import ObjectiveC

extension UITabBarController {
    /**
     Changes the active tab of the tab view controller. If no tab
     has the given text, then this method does nothing.

     - parameters:
        - labelText: The label text of the tab option to change to.
     */
    public func selectTab(withLabel labelText: String) {
        guard let items = tabBar.items else {
            return
        }
        for (index, item) in items.enumerated() {
            if item.title == labelText {
                selectTab(atIndex: index)
            }
        }
    }

    /**
     Changes the active tab of the tab view controller. If no tab
     exists at the given index, then this method does nothing.

     - parameters:
        - index: The index of the tab to change to.
     */
    public func selectTab(atIndex index: Int) {
        guard let viewControllers = viewControllers else {
            return
        }
        if index >= viewControllers.count {
            return
        }
        let vcToSelect = viewControllers[index]
        if let delegate = delegate {
            let shouldSelectOpt = delegate.tabBarController?(self, shouldSelect: vcToSelect)
            if shouldSelectOpt != nil && !shouldSelectOpt! {
                return
            }
        }

        selectedIndex = index

        if let delegate = delegate {
            delegate.tabBarController?(self, didSelect: vcToSelect)
        }
    }
}
