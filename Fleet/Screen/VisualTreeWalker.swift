import UIKit

class VisualTreeWalker {
    func findAllSubviewsOfType<T: UIView>(subviewType: T.Type, inRootVisual rootVisual: UIView) -> [UIView] {
        var subviews = [UIView]()
        for subview in rootVisual.subviews {
            if let castedSubview = subview as? T {
                subviews.append(castedSubview)
            }

            subviews.appendContentsOf(findAllSubviewsOfType(subviewType, inRootVisual: subview))
        }

        return subviews
    }

    func findAllSubviewsOfType<T: UIView>(subviewType: T.Type, inRootVisual rootVisual: UIView, conformingToBlock predicateBlock: (T) -> Bool) -> [UIView] {
        var subviews = [UIView]()
        for subview in rootVisual.subviews {
            if let castedSubview = subview as? T {
                if predicateBlock(castedSubview) {
                    subviews.append(castedSubview)
                }
            }

            subviews.appendContentsOf(findAllSubviewsOfType(subviewType, inRootVisual: subview, conformingToBlock: predicateBlock))
        }

        return subviews
    }
}
